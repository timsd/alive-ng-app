import crypto from 'node:crypto';
import { Client, Databases, ID } from 'node-appwrite';

// Branding assets used across all outbound emails.
// SVG renders in most clients; the text heading below acts as a fallback
// for clients (e.g. some Gmail clients) that strip SVG images.
const ALIVE_LOGO_URL =
  process.env.ALIVE_LOGO_URL ||
  'https://app.alivenigeria.org/assets/assets/images/alive_logo.svg';
const ALIVE_APP_URL = process.env.ALIVE_APP_URL || 'https://app.alivenigeria.org';

// Display names for the client's `DonationType` enum values, used as the
// receipt fallback when a donor gives without picking a project.
// Keep in sync with `DonationType.typeDisplayName` in
// lib/models/donation_models.dart and DONATION_TYPE_LABELS in
// paystackPayments/src/main.js.
//
// 'ministrySupport' is intentionally absent (retired; see the other map).
const DONATION_TYPE_LABELS = {
  tractProduction: 'Tract Production',
  generalSupport: 'General Support',
  appMaintenance: 'App Maintenance',
};

/**
 * Escapes text destined for an HTML email body. The purpose string can come
 * from donor/admin supplied metadata, so it must never be interpolated raw.
 */
function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Resolves the donation's purpose (what the gift was designated toward).
 *
 * Shared by the receipt email and the stored donation record so the two can
 * never disagree. Mirrors the precedence in `paystackPayments` and in
 * `appwrite_admin_export_service.dart` (`_resolvePurpose`).
 */
function resolvePurposeFromMetadata(meta) {
  const m = meta || {};
  const text = (v) => (typeof v === 'string' ? v.trim() : '');

  const split = Array.isArray(m.fund_designations)
    ? m.fund_designations.map(text).filter(Boolean)
    : [];
  if (split.length > 1) return 'Split donation: ' + split.join(', ');
  if (split.length === 1) return split[0];

  const designation = text(m.fund_designation);
  if (designation && !/^split:/i.test(designation)) return designation;

  const projectTitle = text(m.project_title);
  if (projectTitle) return projectTitle;

  const typeLabel = DONATION_TYPE_LABELS[text(m.donation_type)];
  if (typeLabel) return typeLabel;

  const projectId = text(m.project_id);
  // Last resort: prettify the slug so it is still meaningful.
  return projectId
    ? projectId.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
    : 'General Support';
}

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

  // Resolve the donation's purpose the same way `paystack_payments` does, so
  // both receipts agree. Previously this just prettified the raw project_id
  // slug (e.g. "impact_hub_center" -> "Impact Hub Center") and fell back to
  // "General Mission Fund", which ignored the donor's actual designation.
  const meta = paymentData.metadata || {};
  const splitDesignations = Array.isArray(meta.fund_designations)
    ? meta.fund_designations.map(d => String(d || '').trim()).filter(Boolean)
    : [];
  const designation = String(meta.fund_designation || '').trim();
  const projectTitle = String(meta.project_title || '').trim();
  const projectId = String(meta.project_id || '').trim();
  const typeLabel = DONATION_TYPE_LABELS[String(meta.donation_type || '').trim()];

  let projectName;
  if (splitDesignations.length > 1) {
    projectName = 'Split donation: ' + splitDesignations.join(', ');
  } else if (splitDesignations.length === 1) {
    projectName = splitDesignations[0];
  } else if (designation && !/^split:/i.test(designation)) {
    projectName = designation;
  } else if (projectTitle) {
    projectName = projectTitle;
  } else if (typeLabel) {
    projectName = typeLabel;
  } else {
    // Last resort: prettify the slug so it is still meaningful on the receipt.
    projectName = projectId
      ? projectId.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
      : 'General Support';
  }

  // This value can originate in donor/admin supplied metadata.
  const safeProjectName = escapeHtml(projectName);
  const safeDonorName = escapeHtml(donorName);
  const safeCurrency = escapeHtml(currency);
  const safeAmount = escapeHtml(amount);
  const safeReference = escapeHtml(reference);
  const safeDate = escapeHtml(date);
  const safePaymentMethod = escapeHtml(paymentMethod);

  const receiptHtml = '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Donation Receipt - ALIVE Nigeria</title></head><body style="font-family: Georgia, serif; max-width: 600px; margin: 0 auto; padding: 20px; color: #1a202c;"><div style="text-align: center; border-bottom: 3px solid #1a365d; padding-bottom: 20px; margin-bottom: 20px;"><img src="' + ALIVE_LOGO_URL + '" alt="ALIVE Nigeria" width="88" height="88" style="display:block;margin:0 auto 12px;border:0;outline:none;" /><h1 style="color: #1a365d; margin: 0;">ALIVE Nigeria</h1><p style="color: #666; margin: 4px 0;">Official Donation Receipt</p><p style="color: #999; font-size: 12px; margin: 4px 0;">Valid for tax filing purposes</p></div><div style="padding: 10px 0;"><p>Dear ' + safeDonorName + ',</p><p>Thank you for your generous donation to ALIVE Nigeria. Your contribution is making a difference. Your gift of <strong>' + safeCurrency + ' ' + safeAmount + '</strong> was designated to <strong>' + safeProjectName + '</strong>. Below are the details of your donation:</p><table style="width: 100%; border-collapse: collapse; margin: 20px 0;"><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Donor Name</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeDonorName + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Purpose</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeProjectName + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Amount</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeCurrency + ' ' + safeAmount + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Reference</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeReference + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Date</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeDate + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Payment Method</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safePaymentMethod + '</td></tr><tr><td style="padding: 10px; border: 1px solid #e2e8f0; background: #f7fafc;"><strong>Project</strong></td><td style="padding: 10px; border: 1px solid #e2e8f0;">' + safeProjectName + '</td></tr></table><p style="color: #4a5568; font-size: 14px;">This receipt confirms your donation to ALIVE Nigeria. Please retain this for your tax records. If you have any questions, contact us at <a href="mailto:app@alivenigeria.org">app@alivenigeria.org</a>.</p></div><div style="text-align: center; border-top: 1px solid #e2e8f0; padding-top: 20px; color: #999; font-size: 12px;"><p>ALIVE Nigeria &mdash; Thank you for your generosity.</p></div></body></html>';
  
  try {
    if (process.env.RESEND_API_KEY) {
      const sender = process.env.RECEIPT_SENDER_EMAIL || process.env.SENDER_EMAIL || 'ALIVE Nigeria App <receipts@app.alivenigeria.org>';
      const replyTo = process.env.REPLY_TO_EMAIL || 'app@alivenigeria.org';
      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ' + process.env.RESEND_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          from: sender,
          to: [email],
          cc: [replyTo],
          reply_to: replyTo,
          subject: 'Your ALIVE Nigeria Donation Receipt - ' + reference,
          html: receiptHtml
        })
      });
      const resText = await emailRes.text();
      console.log('Resend receipt status:', emailRes.status, 'Response:', resText);
      if (!emailRes.ok) {
        console.error('Resend receipt FAILED for', email, '->', emailRes.status, resText);
      }
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
      // Store the same purpose string the receipt shows, so the donation
      // record, the receipt and the admin export all agree.
      const purpose = resolvePurposeFromMetadata(metadata);
      await updateDonation(databases, reference, {
        status: 'completed',
        transaction_id: data.id?.toString(),
        purpose,
        project_title: purpose,
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
