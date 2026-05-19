const defaultSender = 'ALIVE Nigeria <onboarding@resend.dev>';

export default async ({ req, res, log, error }) => {
  if (req.method !== 'POST') {
    return res.json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  try {
    const userId = req.headers['x-appwrite-user-id'];
    if (!userId) {
      return res.json({ error: 'Authentication required.' }, 401);
    }

    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      error('Missing RESEND_API_KEY.');
      return res.json({ error: 'Email service is not configured.' }, 500);
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const to = validateEmail(body.to);
    const subject = validateSubject(body.subject);
    const html = validateHtml(body.html);
    const from = process.env.RECEIPT_SENDER_EMAIL || process.env.SENDER_EMAIL || defaultSender;

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        html,
      }),
    });

    const responseBody = await response.text();
    if (!response.ok) {
      error(`Resend email failed (${response.status}): ${responseBody}`);
      return res.json({ error: 'Email send failed.' }, 502);
    }

    log(`Email sent to ${to} by user ${userId}.`);
    return res.json({ ok: true });
  } catch (err) {
    error(`Email send failed: ${err.message}`);
    return res.json({ error: err.message || 'Internal Server Error' }, 500);
  }
};

function validateEmail(value) {
  if (typeof value !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new Error('Invalid recipient email.');
  }
  return value;
}

function validateSubject(value) {
  if (typeof value !== 'string' || value.trim().length < 3 || value.length > 255) {
    throw new Error('Invalid email subject.');
  }
  return value.trim();
}

function validateHtml(value) {
  if (typeof value !== 'string' || value.trim().length < 1 || value.length > 100000) {
    throw new Error('Invalid email body.');
  }
  return value;
}
