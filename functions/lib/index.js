"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateStreamChatToken = exports.consumeApprovalToken = exports.sendReceiptOnCompletion = exports.paystackWebhook = exports.initPaystackTransaction = void 0;
const functions = __importStar(require("firebase-functions"));
const params_1 = require("firebase-functions/params");
const admin = __importStar(require("firebase-admin"));
const node_fetch_1 = __importDefault(require("node-fetch"));
const node_crypto_1 = __importDefault(require("node:crypto"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
admin.initializeApp();
const db = admin.firestore();
const PAYSTACK_SECRET_KEY = (0, params_1.defineSecret)('PAYSTACK_SECRET_KEY');
const SENDGRID_API_KEY = (0, params_1.defineSecret)('SENDGRID_API_KEY');
const STREAM_CHAT_SECRET = (0, params_1.defineSecret)('STREAM_CHAT_SECRET');
exports.initPaystackTransaction = functions
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
    const body = {
        amount,
        email,
        reference,
        callback_url,
        channels,
        currency: currency || 'NGN',
        metadata,
    };
    const resp = await (0, node_fetch_1.default)('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${secret}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    });
    const json = await resp.json();
    if (!json?.status) {
        throw new functions.https.HttpsError('unknown', json?.message || 'Paystack init failed', json);
    }
    return json?.data;
});
function verifySignature(req) {
    const secret = PAYSTACK_SECRET_KEY.value();
    const computed = node_crypto_1.default.createHmac('sha512', secret).update(JSON.stringify(req.body)).digest('hex');
    return computed === req.header('x-paystack-signature');
}
exports.paystackWebhook = functions
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
    const reference = data?.reference;
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
        await docRef.set({
            status: 'completed',
            transaction_id: data?.id?.toString(),
            completed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    else if (type === 'charge.failed' || type === 'charge.abandoned') {
        await docRef.set({
            status: 'failed',
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    else {
        await docRef.set({
            updated_at: new Date().toISOString(),
            metadata: meta,
        }, { merge: true });
    }
    res.status(200).send('OK');
});
exports.sendReceiptOnCompletion = functions
    .runWith({ secrets: [SENDGRID_API_KEY] })
    .firestore
    .document('donation_records/{reference}')
    .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after || !before)
        return;
    if (before.status === 'completed' || after.status !== 'completed')
        return;
    const email = after.user_email;
    if (!email)
        return;
    const reference = context.params.reference;
    const amount = after.amount;
    const currency = after.currency;
    const title = after.material_title;
    await sendReceiptEmail({
        to: email,
        reference,
        amount,
        currency,
        title,
    });
});
exports.consumeApprovalToken = functions.https.onCall(async (data, context) => {
    const userId = data?.userId || '';
    const token = data?.token || '';
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
        if (!snap.exists)
            return false;
        const tokenData = snap.data();
        if (tokenData.used === true)
            return false;
        if (tokenData.userId !== userId)
            return false;
        const expiresAt = tokenData.expiresAt ? new Date(tokenData.expiresAt) : null;
        if (!expiresAt || Number.isNaN(expiresAt.getTime()) || Date.now() > expiresAt.getTime()) {
            return false;
        }
        tx.update(tokenRef, {
            used: true,
            usedAt: new Date().toISOString(),
        });
        tx.set(userRef, {
            isApproved: true,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: 'approval_link_token',
        }, { merge: true });
        return true;
    });
    return { ok: approved };
});
function _base64UrlEncode(value) {
    return Buffer.from(value)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/g, '');
}
function _createHs256Jwt(payload, secret) {
    const header = { alg: 'HS256', typ: 'JWT' };
    const headerPart = _base64UrlEncode(JSON.stringify(header));
    const payloadPart = _base64UrlEncode(JSON.stringify(payload));
    const unsigned = `${headerPart}.${payloadPart}`;
    const signature = node_crypto_1.default
        .createHmac('sha256', secret)
        .update(unsigned)
        .digest('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/g, '');
    return `${unsigned}.${signature}`;
}
exports.generateStreamChatToken = functions
    .runWith({ secrets: [STREAM_CHAT_SECRET] })
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const requestedUserId = data?.userId || context.auth.uid;
    const isAdmin = (context.auth.token && context.auth.token.admin) === true;
    if (requestedUserId !== context.auth.uid && !isAdmin) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot mint token for another user');
    }
    const secret = STREAM_CHAT_SECRET.value();
    if (!secret) {
        throw new functions.https.HttpsError('failed-precondition', 'Missing STREAM_CHAT_SECRET');
    }
    // Stream user token payload: user_id + issued-at timestamp.
    const token = _createHs256Jwt({
        user_id: requestedUserId,
        iat: Math.floor(Date.now() / 1000),
    }, secret);
    return { token };
});
async function sendReceiptEmail(params) {
    const apiKey = SENDGRID_API_KEY.value();
    const sender = process.env.RECEIPT_SENDER_EMAIL || 'no-reply@alivenigeria.org';
    const logoUrl = process.env.ALIVE_LOGO_URL || 'https://alive.ng/logo.png';
    if (!apiKey)
        return;
    mail_1.default.setApiKey(apiKey);
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
        await mail_1.default.send(msg);
    }
    catch (e) {
        console.error('Failed to send receipt email', e);
    }
}
