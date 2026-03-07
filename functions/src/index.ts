import * as functions from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import fetch from 'node-fetch';
import crypto from 'node:crypto';
import sgMail from '@sendgrid/mail';

admin.initializeApp();
const db = admin.firestore();
const PAYSTACK_SECRET_KEY = defineSecret('PAYSTACK_SECRET_KEY');
const SENDGRID_API_KEY = defineSecret('SENDGRID_API_KEY');
const STREAM_CHAT_SECRET = defineSecret('STREAM_CHAT_SECRET');

export const initPaystackTransaction = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY] })
  .https.onCall(async (data, context) => {
  const { amount, email, reference, callback_url, channels, metadata, currency } = data || {};
  const enforceAppCheck = process.env.ENFORCE_APPCHECK === 'true';
  if (enforceAppCheck && !context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check token is required');
  }
  if (!amount || typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
  }
  if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email');
  }
  if (!reference || typeof reference !== 'string' || reference.length < 8 || reference.length > 80) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid reference');
  }
  const secret = PAYSTACK_SECRET_KEY.value();
  if (!secret) {
    throw new functions.https.HttpsError('failed-precondition', 'Missing PAYSTACK_SECRET_KEY');
  }
  const body: Record<string, unknown> = {
    amount,
    email,
    reference,
    callback_url,
    channels,
    currency: currency || 'NGN',
    metadata,
  };
  const resp = await fetch('https://api.paystack.co/transaction/initialize', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${secret}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const json: any = await resp.json();
  if (!json?.status) {
    throw new functions.https.HttpsError('unknown', json?.message || 'Paystack init failed', json);
  }
  return json?.data;
});

function verifySignature(req: functions.https.Request) {
  const secret = PAYSTACK_SECRET_KEY.value();
  const computed = crypto.createHmac('sha512', secret!).update(JSON.stringify(req.body)).digest('hex');
  return computed === req.header('x-paystack-signature');
}

export const paystackWebhook = functions
  .runWith({ secrets: [PAYSTACK_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  if (!verifySignature(req)) {
    res.status(401).send('Invalid signature');
    return;
  }
  const event = req.body;
  const type = event?.event;
  const data = event?.data;
  const reference: string | undefined = data?.reference;
  if (!reference) {
    res.status(400).send('Missing reference');
    return;
  }
  const docRef = db.collection('donation_records').doc(reference);
  const meta = {
    processor: 'paystack',
    channel: data?.channel,
    fees: data?.fees,
    gateway_response: data?.gateway_response,
    paid_at: data?.paid_at,
  };
  if (type === 'charge.success') {
    await docRef.set(
      {
        status: 'completed',
        transaction_id: data?.id?.toString(),
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        metadata: meta,
      },
      { merge: true },
    );
  } else if (type === 'charge.failed' || type === 'charge.abandoned') {
    await docRef.set(
      {
        status: 'failed',
        updated_at: new Date().toISOString(),
        metadata: meta,
      },
      { merge: true },
    );
  } else {
    await docRef.set(
      {
        updated_at: new Date().toISOString(),
        metadata: meta,
      },
      { merge: true },
    );
  }
  res.status(200).send('OK');
});

export const sendReceiptOnCompletion = functions
  .runWith({ secrets: [SENDGRID_API_KEY] })
  .firestore
  .document('donation_records/{reference}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before) return;
    if (before.status === 'completed' || after.status !== 'completed') return;
    const email = after.user_email as string | undefined;
    if (!email) return;
    const reference = context.params.reference as string;
    const amount = after.amount as number | undefined;
    const currency = after.currency as string | undefined;
    const title = after.material_title as string | undefined;
    await sendReceiptEmail({
      to: email,
      reference,
      amount,
      currency,
      title,
    });
  });

export const consumeApprovalToken = functions.https.onCall(async (data, context) => {
  const userId = (data?.userId as string | undefined) || '';
  const token = (data?.token as string | undefined) || '';

  if (!userId || !token) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing userId or token');
  }
  if (token.length < 24 || token.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid token format');
  }

  const tokenRef = db.collection('approval_tokens').doc(token);
  const userRef = db.collection('users').doc(userId);

  const approved = await db.runTransaction(async (tx) => {
    const snap = await tx.get(tokenRef);
    if (!snap.exists) return false;
    const tokenData = snap.data() as {
      userId?: string;
      used?: boolean;
      expiresAt?: string;
    };
    if (tokenData.used === true) return false;
    if (tokenData.userId !== userId) return false;
    const expiresAt = tokenData.expiresAt ? new Date(tokenData.expiresAt) : null;
    if (!expiresAt || Number.isNaN(expiresAt.getTime()) || Date.now() > expiresAt.getTime()) {
      return false;
    }

    tx.update(tokenRef, {
      used: true,
      usedAt: new Date().toISOString(),
    });
    tx.set(
      userRef,
      {
        isApproved: true,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: 'approval_link_token',
      },
      { merge: true },
    );
    return true;
  });

  return { ok: approved };
});

function _base64UrlEncode(value: string): string {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function _createHs256Jwt(payload: Record<string, unknown>, secret: string): string {
  const header = { alg: 'HS256', typ: 'JWT' };
  const headerPart = _base64UrlEncode(JSON.stringify(header));
  const payloadPart = _base64UrlEncode(JSON.stringify(payload));
  const unsigned = `${headerPart}.${payloadPart}`;
  const signature = crypto
    .createHmac('sha256', secret)
    .update(unsigned)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
  return `${unsigned}.${signature}`;
}

export const generateStreamChatToken = functions
  .runWith({ secrets: [STREAM_CHAT_SECRET] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    const requestedUserId = (data?.userId as string | undefined) || context.auth.uid;
    const isAdmin = (context.auth.token && (context.auth.token as any).admin) === true;
    if (requestedUserId !== context.auth.uid && !isAdmin) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot mint token for another user');
    }

    const secret = STREAM_CHAT_SECRET.value();
    if (!secret) {
      throw new functions.https.HttpsError('failed-precondition', 'Missing STREAM_CHAT_SECRET');
    }

    // Stream user token payload: user_id + issued-at timestamp.
    const token = _createHs256Jwt(
      {
        user_id: requestedUserId,
        iat: Math.floor(Date.now() / 1000),
      },
      secret,
    );

    return { token };
  });

async function sendReceiptEmail(params: {
  to: string;
  reference: string;
  amount?: number;
  currency?: string;
  title?: string;
}) {
  const apiKey = SENDGRID_API_KEY.value();
  const sender = process.env.RECEIPT_SENDER_EMAIL || 'no-reply@alivenigeria.org';
  const logoUrl = process.env.ALIVE_LOGO_URL || 'https://alive.ng/logo.png';
  if (!apiKey) return;
  sgMail.setApiKey(apiKey);
  const fmtAmount = params.amount != null ? Number(params.amount).toLocaleString() : '';
  const html = `
    <div style="font-family: Arial, sans-serif; color:#111;">
      <div style="text-align:center; padding:16px;">
        <img src="${logoUrl}" alt="ALIVE-NG" height="48" />
      </div>
      <h2 style="text-align:center;">Donation Receipt</h2>
      <p>Dear donor,</p>
      <p>Thank you for your generous support. Below are the details of your donation.</p>
      <table style="width:100%; border-collapse:collapse;">
        <tr><td style="padding:8px;">Reference</td><td style="padding:8px;"><strong>${params.reference}</strong></td></tr>
        <tr><td style="padding:8px;">Amount</td><td style="padding:8px;"><strong>${fmtAmount} ${params.currency || ''}</strong></td></tr>
        <tr><td style="padding:8px;">Item</td><td style="padding:8px;"><strong>${params.title || 'Donation'}</strong></td></tr>
      </table>
      <hr />
      <p style="font-size:12px; color:#555;">ALIVE-NG Finance Department • ALIVE-NG Ministries</p>
    </div>
  `;
  const msg = {
    to: params.to,
    from: sender,
    subject: 'ALIVE-NG Donation Receipt',
    html,
  };
  try {
    await sgMail.send(msg);
  } catch (e) {
    console.error('Failed to send receipt email', e);
  }
}
