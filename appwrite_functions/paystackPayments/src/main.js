import { Client, Databases } from 'node-appwrite';

const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const paymentLogsCollectionId = process.env.APPWRITE_PAYMENT_LOGS_COLLECTION_ID || 'payment_logs';

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const userId = req.headers['x-appwrite-user-id'];
    if (!userId) {
      return res.json({ error: 'Authentication required.' }, 401);
    }

    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      error('Missing PAYSTACK_SECRET_KEY.');
      return res.json({ error: 'Paystack is not configured.' }, 500);
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const action = body.action || 'initialize_transaction';
    const reference = validateReference(body.reference);
    const email = validateEmail(body.email);
    const callbackUrl = body.callback_url;
    const channels = Array.isArray(body.channels) ? body.channels : undefined;
    const currency = typeof body.currency === 'string' && body.currency.trim() ? body.currency : 'NGN';
    const metadata = {
      ...(body.metadata || {}),
      appwrite_user_id: userId,
      reference,
    };

    const payload = {
      email,
      reference,
      callback_url: callbackUrl,
      channels,
      currency,
      metadata,
    };

    if (action === 'initialize_subscription') {
      const planCode = typeof body.planCode === 'string' ? body.planCode.trim() : '';
      if (!planCode) {
        return res.json({ error: 'Missing Paystack monthly plan code.' }, 400);
      }
      payload.plan = planCode;
      payload.metadata = {
        ...payload.metadata,
        recurring: true,
        plan_code: planCode,
      };
    } else {
      const amount = Number(body.amount);
      if (!Number.isFinite(amount) || amount <= 0) {
        return res.json({ error: 'Invalid amount.' }, 400);
      }
      payload.amount = Math.round(amount);
    }

    const paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    const json = await paystackResponse.json();

    await writePaymentLog({
      event: action,
      reference,
      status: json?.status ? 'initialized' : 'failed',
      payload: json,
      log,
    });

    if (!json?.status) {
      return res.json({
        error: json?.message || 'Paystack initialization failed.',
        data: json,
      }, 502);
    }

    return res.json(json.data);
  } catch (err) {
    error(`Paystack initialization failed: ${err.message}`);
    return res.json({ error: err.message || 'Internal Server Error' }, 500);
  }
};

function validateEmail(value) {
  if (typeof value !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new Error('Invalid email.');
  }
  return value;
}

function validateReference(value) {
  if (typeof value !== 'string' || value.length < 8 || value.length > 128) {
    throw new Error('Invalid reference.');
  }
  return value;
}

async function writePaymentLog({ event, reference, status, payload, log }) {
  try {
    const apiKey = process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
    const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT || process.env.APPWRITE_ENDPOINT;
    const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID || process.env.APPWRITE_PROJECT_ID;
    if (!apiKey || !endpoint || !projectId) return;

    const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
    const databases = new Databases(client);
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
  } catch (err) {
    log(`Skipping payment log write: ${err.message}`);
  }
}
