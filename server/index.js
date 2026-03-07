import express from 'express';
import crypto from 'crypto';
import { sendTransactionalEmail } from './email.js';

const app = express();
const port = process.env.PORT || 8080;

// Raw body parser to verify signatures
app.use('/webhook/paystack', express.raw({ type: '*/*' }));
app.use('/webhook/stream', express.raw({ type: '*/*' }));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

// Paystack webhook verification (HMAC SHA512)
app.post('/webhook/paystack', (req, res) => {
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
    // TODO: handle event.type (charge.success, subscription.create, etc.)
    res.status(200).json({ received: true });
  } catch (e) {
    res.status(500).json({ error: 'Webhook error' });
  }
});

// Stream Chat webhook verification (HMAC SHA256 of raw body)
app.post('/webhook/stream', (req, res) => {
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
    // TODO: handle event.type (message.new, user.updated, etc.)
    res.status(200).json({ received: true });
  } catch (e) {
    res.status(500).json({ error: 'Webhook error' });
  }
});

app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`Server listening on :${port}`);
});

// Minimal transactional email endpoint
app.post('/email/send', async (req, res) => {
  try {
    const { to, subject, html } = req.body || {};
    if (!to || !subject || !html) {
      return res.status(400).json({ error: 'Missing to/subject/html' });
    }
    await sendTransactionalEmail({ to, subject, html });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: 'Email send failed' });
  }
});
