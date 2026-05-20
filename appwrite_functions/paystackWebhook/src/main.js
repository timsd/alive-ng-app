import crypto from 'node:crypto';
import { Client, Databases } from 'node-appwrite';

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
    `${reference}_${Date.now()}`,
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
