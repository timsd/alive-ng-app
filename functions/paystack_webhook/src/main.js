import { Client, Databases } from 'node-appwrite';
import crypto from 'node:crypto';

/**
 * Paystack webhook receiver for ALIVE Nigeria donations.
 *
 * Appwrite injects these env vars automatically at runtime:
 *   APPWRITE_FUNCTION_API_ENDPOINT, APPWRITE_FUNCTION_PROJECT_ID, APPWRITE_FUNCTION_API_KEY
 *
 * Configure these in the Appwrite console (Function → Settings → Variables):
 *   PAYSTACK_SECRET_KEY   = sk_live_...  (used to verify the HMAC signature)
 *   APPWRITE_DATABASE_ID  = 6a089307002e54291a32
 *   DONATION_COLLECTION_ID = donation_records
 *
 * Expected events:
 *   charge.success → status = completed (+ transaction_id, paid_at)
 *   charge.failed  → status = failed
 *
 * Response is always 200 after verification so Paystack does not retry
 * forever; unknown references are logged but acknowledged.
 */
export default async ({ req, res, log, error }) => {
  try {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      error('PAYSTACK_SECRET_KEY not configured on the function');
      return res.json({ ok: false, message: 'webhook not configured' }, 500);
    }

    // 1. Verify the Paystack HMAC-SHA512 signature.
    const signature = req.headers['x-paystack-signature'] ?? '';
    const rawBody = typeof req.bodyRaw === 'string'
        ? req.bodyRaw
        : JSON.stringify(req.body ?? {});
    const expected = crypto
        .createHmac('sha512', secret)
        .update(rawBody)
        .digest('hex');

    if (signature !== expected) {
      log('Signature mismatch — rejecting event');
      return res.json({ ok: false, message: 'invalid signature' }, 401);
    }

    const event = typeof req.body === 'string'
        ? JSON.parse(req.body)
        : req.body;
    const eventName = event?.event ?? '';
    const data = event?.data ?? {};
    const reference = data.reference ?? '';
    log(`Received ${eventName} for reference ${reference}`);

    if (!reference) {
      return res.json({ ok: true, message: 'no reference, ignored' });
    }

    // 2. Connect to Appwrite using the injected function credentials.
    const client = new Client()
        .setEndpoint(process.env.APPWRITE_FUNCTION_API_ENDPOINT)
        .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
        .setKey(process.env.APPWRITE_FUNCTION_API_KEY);
    const databases = new Databases(client);
    const databaseId = process.env.APPWRITE_DATABASE_ID;
    const collectionId = process.env.DONATION_COLLECTION_ID;

    const nowIso = new Date().toISOString();

    if (eventName === 'charge.success') {
      const amountKobo = data.amount ?? 0;
      await databases.updateDocument(
          databaseId,
          collectionId,
          reference,
          {
            status: 'completed',
            transaction_id: data.id?.toString() ?? '',
            channel: data.channel ?? '',
            paid_at: data.paid_at
                ? new Date(data.paid_at).toISOString()
                : nowIso,
            amount_kobo: amountKobo,
            updated_at: nowIso,
          },
      );
      log(`Donation ${reference} marked completed`);
      return res.json({ ok: true, status: 'completed', reference });
    }

    if (eventName === 'charge.failed') {
      await databases.updateDocument(
          databaseId,
          collectionId,
          reference,
          {
            status: 'failed',
            failure_reason: data.gateway_response ?? '',
            updated_at: nowIso,
          },
      );
      log(`Donation ${reference} marked failed`);
      return res.json({ ok: true, status: 'failed', reference });
    }

    // Any other event — acknowledge so Paystack stops retrying.
    log(`Unhandled event ${eventName} — acknowledged`);
    return res.json({ ok: true, message: `ignored ${eventName}` });
  } catch (e) {
    error(`Webhook processing error: ${e?.message ?? e}`);
    return res.json({ ok: false, message: 'processing error' }, 500);
  }
};
