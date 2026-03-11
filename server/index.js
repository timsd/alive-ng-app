import express from 'express';
import crypto from 'crypto';
import admin from 'firebase-admin';
import { sendTransactionalEmail } from './email.js';

// Initialize Firebase Admin for Firestore access
const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (serviceAccount) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
} else {
  admin.initializeApp();
}
const db = admin.firestore();

const app = express();
const port = process.env.PORT || 8080;

// Raw body parser to verify signatures
app.use('/webhook/paystack', express.raw({ type: '*/*' }));
app.use('/webhook/stream', express.raw({ type: '*/*' }));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

// ── Paystack Webhook ────────────────────────────────────────────────────────
app.post('/webhook/paystack', async (req, res) => {
  try {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      return res.status(500).json({ error: 'Missing PAYSTACK_SECRET_KEY' });
    }
    const signature = req.headers['x-paystack-signature'];
    if (!signature) {
      return res.status(400).json({ error: 'Missing signature' });
    }
    const body = req.body; // Buffer
    const expected = crypto
      .createHmac('sha512', secret)
      .update(body)
      .digest('hex');
    if (expected !== signature) {
      return res.status(400).json({ error: 'Invalid signature' });
    }
    const event = JSON.parse(body.toString('utf8'));
    const type = event?.event;
    const data = event?.data;
    const reference = data?.reference;

    if (!reference) {
      return res.status(400).json({ error: 'Missing reference' });
    }

    const docRef = db.collection('donation_records').doc(reference);
    const meta = {
      processor: 'paystack',
      channel: data?.channel ?? null,
      fees: data?.fees ?? null,
      gateway_response: data?.gateway_response ?? null,
      paid_at: data?.paid_at ?? null,
      source: 'server_webhook',
    };

    switch (type) {
      case 'charge.success':
        await docRef.set(
          {
            status: 'completed',
            transaction_id: String(data?.id ?? ''),
            completed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            metadata: meta,
          },
          { merge: true },
        );
        break;

      case 'charge.failed':
      case 'charge.abandoned':
        await docRef.set(
          {
            status: 'failed',
            updated_at: new Date().toISOString(),
            metadata: meta,
          },
          { merge: true },
        );
        break;

      case 'subscription.create':
        await docRef.set(
          {
            status: 'subscription_active',
            subscription_code: data?.subscription_code ?? null,
            plan_code: data?.plan?.plan_code ?? null,
            updated_at: new Date().toISOString(),
            metadata: meta,
          },
          { merge: true },
        );
        break;

      case 'subscription.disable':
      case 'subscription.not_renew':
        await docRef.set(
          {
            status: 'subscription_cancelled',
            updated_at: new Date().toISOString(),
            metadata: meta,
          },
          { merge: true },
        );
        break;

      default:
        // Log unknown events for debugging
        await docRef.set(
          {
            updated_at: new Date().toISOString(),
            metadata: { ...meta, raw_event_type: type },
          },
          { merge: true },
        );
        break;
    }

    res.status(200).json({ received: true, event: type });
  } catch (e) {
    console.error('Paystack webhook error:', e);
    res.status(500).json({ error: 'Webhook error' });
  }
});

// ── Stream Chat Webhook ─────────────────────────────────────────────────────
app.post('/webhook/stream', async (req, res) => {
  try {
    const secret = process.env.STREAM_CHAT_SECRET;
    if (!secret) {
      return res.status(500).json({ error: 'Missing STREAM_CHAT_SECRET' });
    }
    const signature = req.headers['x-stream-signature'];
    if (!signature) {
      return res.status(400).json({ error: 'Missing signature' });
    }
    const body = req.body;
    const expected = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');
    if (expected !== signature) {
      return res.status(400).json({ error: 'Invalid signature' });
    }
    const event = JSON.parse(body.toString('utf8'));
    const type = event?.type;

    // Log chat events to Firestore for analytics / audit
    switch (type) {
      case 'message.new': {
        const msg = event?.message;
        await db.collection('chat_events').add({
          event_type: 'message.new',
          channel_id: event?.channel_id ?? null,
          channel_type: event?.channel_type ?? null,
          user_id: msg?.user?.id ?? null,
          message_id: msg?.id ?? null,
          text_length: msg?.text?.length ?? 0,
          created_at: new Date().toISOString(),
        });
        break;
      }

      case 'user.updated': {
        const user = event?.user;
        await db.collection('chat_events').add({
          event_type: 'user.updated',
          user_id: user?.id ?? null,
          user_name: user?.name ?? null,
          created_at: new Date().toISOString(),
        });
        break;
      }

      case 'notification.message_new': {
        const msg = event?.message;
        await db.collection('chat_events').add({
          event_type: 'notification.message_new',
          channel_id: event?.channel_id ?? null,
          user_id: msg?.user?.id ?? null,
          message_id: msg?.id ?? null,
          created_at: new Date().toISOString(),
        });
        break;
      }

      default:
        // Log unhandled event types for future expansion
        await db.collection('chat_events').add({
          event_type: type ?? 'unknown',
          raw_keys: Object.keys(event || {}),
          created_at: new Date().toISOString(),
        });
        break;
    }

    res.status(200).json({ received: true, event: type });
  } catch (e) {
    console.error('Stream Chat webhook error:', e);
    res.status(500).json({ error: 'Webhook error' });
  }
});

// ── Email Endpoint ──────────────────────────────────────────────────────────
app.post('/email/send', async (req, res) => {
  try {
    const { to, subject, html } = req.body || {};
    if (!to || !subject || !html) {
      return res.status(400).json({ error: 'Missing to/subject/html' });
    }
    await sendTransactionalEmail(to, subject, html);
    res.json({ ok: true });
  } catch (e) {
    console.error('Email send error:', e);
    res.status(500).json({ error: 'Email send failed' });
  }
});

app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on :${port}`);
});
