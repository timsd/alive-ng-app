import crypto from 'node:crypto';
import { Client, Databases, ID } from 'node-appwrite';

// Branding assets used across all outbound emails.
// SVG renders in most clients; the text heading below acts as a fallback
// for clients (e.g. some Gmail clients) that strip SVG images.
const ALIVE_LOGO_URL =
  process.env.ALIVE_LOGO_URL ||
  'https://app.alivenigeria.org/assets/assets/images/alive_logo.svg';
const ALIVE_APP_URL = process.env.ALIVE_APP_URL || 'https://app.alivenigeria.org';

async function sendDonationReceipt(paymentData) {
  const email = paymentData.customer && paymentData.customer.email;
  if (!email) return;
  
  const amount = (paymentData.amount / 100).toLocaleString();
  const currency = paymentData.currency || 'NGN';
  const reference = paymentData.reference;
  const date = new Date().toLocaleDateString('en-NG', { year: 'numeric', month: 'long', day: 'numeric' });
  
  const donorName = (paymentData.metadata && paymentData.metadata.donor_name)
    ? paymentData.metadata.donor_name
    : (paymentData.customer && paymentData.customer.first_name
        ? paymentData.customer.first_name
        : 'Donor');
  const paymentMethod = paymentData.channel || 'card';
  const projectName = (paymentData.metadata && paymentData.metadata.project_id)
    ? paymentData.metadata.project_id.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
    : 'General Mission Fund';

  const receiptHtml = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Donation Receipt - ALIVE Nigeria</title></head><body style="font-family: Georgia, serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #1a202c;"><div style="text-align: center; border-bottom: 3px solid #1a365d; padding-bottom: 20px; margin-bottom: 20px;"><img src="' + ALIVE_LOGO_URL + '" alt="ALIVE Nigeria" width="88" height="88" style="display:block;margin:0 auto 12px;border:0;outline:none;" /><h1 style="color: #1a365d; margin: 0;">ALIVE Nigeria</h1><p style="color: #666; margin: 4px 0;">Official Donation Receipt</p><p style="color: #999; font-size: 12px; margin: 4px 0;">Valid for tax filing purposes</p></div><div style="padding: 10px 0;"><p>Dear ' + donorName + ',</p><p>Thank you for your generous donation to ALIVE Nigeria. Your contribution is making a difference. Below are the details of your donation:</p><table style="width: 100%; border-collapse: collapse; margin: 20px 0;"><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Donor Name</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + donorName + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Amount</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + currency + ' ' + amount + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Reference</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + reference + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Date</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + date + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Payment Method</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + paymentMethod + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Project</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + projectName + '</td></tr></table><p style="color: #4a5568; font-size: 14px;">This receipt confirms your donation to ALIVE Nigeria. Please retain this for your tax records. If you have any questions, contact us at <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a>.</p></div><div style="text-align: center; border-top: 1px solid #e2e8f0; padding-top: 20px; color: #999; font-size: 12px;"><p>ALIVE Nigeria &mdash; Thank you for your generosity.</p></div></body></html>';
  
  try {
    if (process.env.RESEND_API_KEY) {
      const sender = process.env.RECEIPT_SENDER_EMAIL || process.env.SENDER_EMAIL || 'ALIVE Nigeria <app@alivenigeria.org>';
      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + process.env.RESEND_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: sender,
          to: [email],
          subject: 'Your ALIVE-NG Donation Receipt - ' + reference,
          html: receiptHtml
        })
      });
      const resText = await emailRes.text();
      console.log('Resend receipt status:', emailRes.status, 'Response:', resText);
    } else {
      console.log('Receipt generated (no email service configured):', email, reference);
    }
  } catch (err) {
    console.error('Failed to send receipt:', err);
  }
}
// imports moved to top of file

const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const donationsCollectionId = process.env.APPWRITE_DONATION_RECORDS_COLLECTION_ID || 'donation_records';
const projectsCollectionId = process.env.APPWRITE_PROJECTS_COLLECTION_ID || 'projects';
const paymentLogsCollectionId = process.env.APPWRITE_PAYMENT_LOGS_COLLECTION_ID || 'payment_logs';

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.text('Method Not Allowed', 405);
  }

  try {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      error('Missing PAYSTACK_SECRET_KEY.');
      return res.text('Paystack is not configured.', 500);
    }

    const rawBody = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
    const signature = req.headers['x-paystack-signature'];
    const computed = crypto.createHmac('sha512', secret).update(rawBody).digest('hex');
    if (!isValidSignature(signature, computed)) {
      return res.text('Invalid signature', 401);
    }

    const event = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const type = event?.event;
    const data = event?.data || {};
    const reference = data.reference;
    if (!reference) {
      return res.text('Missing reference', 400);
    }

    const databases = appwriteDatabases();
    await writePaymentLog(databases, type, reference, 'received', event);

    const metadata = {
      ...(data.metadata || {}),
      processor: 'paystack',
      channel: data.channel,
      fees: data.fees,
      gateway_response: data.gateway_response,
      paid_at: data.paid_at,
    };

    if (type === 'charge.success') {
      await updateDonation(databases, reference, {
        status: 'completed',
        transaction_id: data.id?.toString(),
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        metadata: JSON.stringify(metadata),
      }, data);
      await incrementProjectRaised(databases, metadata, log);
      await sendDonationReceipt(data);
    } else if (type === 'charge.failed' || type === 'charge.abandoned') {
      await updateDonation(databases, reference, {
        status: 'failed',
        updated_at: new Date().toISOString(),
        metadata: JSON.stringify(metadata),
      }, data);
    } else {
      await updateDonation(databases, reference, {
        updated_at: new Date().toISOString(),
        metadata: JSON.stringify(metadata),
      }, data);
    }

    return res.text('OK');
  } catch (err) {
    error(`Paystack webhook failed: ${err.message}`);
    return res.text('Internal Server Error', 500);
  }
};

function isValidSignature(received, expected) {
  if (typeof received !== 'string' || !received) return false;

  const receivedBuffer = Buffer.from(received, 'hex');
  const expectedBuffer = Buffer.from(expected, 'hex');
  if (receivedBuffer.length !== expectedBuffer.length) return false;

  return crypto.timingSafeEqual(receivedBuffer, expectedBuffer);
}

function appwriteDatabases() {
  const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
  const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
  if (!apiKey || !endpoint || !projectId) {
    throw new Error('Missing Appwrite function API credentials.');
  }
  const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
  return new Databases(client);
}

async function updateDonation(databases, reference, data, paystackData) {
  try {
    await databases.updateDocument(databaseId, donationsCollectionId, reference, data);
  } catch (err) {
    const amountKobo = Number(paystackData?.amount || 0);
    const customerEmail = paystackData?.customer?.email || paystackData?.metadata?.email || '';
    await databases.createDocument(databaseId, donationsCollectionId, reference, {
      reference,
      ...data,
      processor: 'paystack',
      amount_kobo: Number.isFinite(amountKobo) && amountKobo > 0 ? Math.round(amountKobo) : 1,
      amount: Number.isFinite(amountKobo) && amountKobo > 0 ? amountKobo / 100 : 0,
      currency: paystackData?.currency || 'NGN',
      user_id: paystackData?.metadata?.user_id || paystackData?.metadata?.appwrite_user_id || 'paystack-webhook',
      user_email: customerEmail,
      email: customerEmail,
      type: paystackData?.metadata?.donation_type || 'generalSupport',
      payment_method: 'paystack',
      created_at: new Date().toISOString(),
    });
  }
}

async function incrementProjectRaised(databases, metadata, log) {
  const projectId = String(metadata.project_id || '').trim();
  const amount = Number(metadata.amount_ngn || metadata.amount || 0);
  if (!projectId || !Number.isFinite(amount) || amount <= 0) return;

  try {
    const project = await databases.getDocument(databaseId, projectsCollectionId, projectId);
    const raised = Number(project.raised || project.amount_raised || 0) + amount;
    await databases.updateDocument(databaseId, projectsCollectionId, projectId, {
      raised,
      amount_raised: raised,
      updated_at: new Date().toISOString(),
    });
  } catch (err) {
    log(`Skipping project raised update: ${err.message}`);
  }
}

async function writePaymentLog(databases, event, reference, status, payload) {
  await databases.createDocument(
    databaseId,
    paymentLogsCollectionId,
    ID.unique(),
    {
      provider: 'paystack',
      reference,
      event,
      status,
      payload: JSON.stringify(payload),
      created_at: new Date().toISOString(),
    },
  );
}
