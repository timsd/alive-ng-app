// IMPORTANT: the Resend account only has `app.alivenigeria.org` verified for
// sending. Addresses on the bare `alivenigeria.org` domain (e.g.
// `app@alivenigeria.org`) are rejected with 403 "domain is not verified".
// So the From address MUST live under `app.alivenigeria.org`, while
// `app@alivenigeria.org` is used as the Reply-To so replies reach the
// monitored mailbox.
const defaultSender = 'ALIVE Nigeria App <msg@app.alivenigeria.org>';
const defaultReplyTo = 'app@alivenigeria.org';

// Branding assets used across all outbound emails.
// SVG renders in most clients; the text heading below acts as a fallback
// for clients (e.g. some Gmail clients) that strip SVG images.
const ALIVE_LOGO_URL =
  process.env.ALIVE_LOGO_URL ||
  'https://app.alivenigeria.org/assets/assets/images/alive_logo.svg';
const ALIVE_APP_URL = process.env.ALIVE_APP_URL || 'https://app.alivenigeria.org';

export default async ({ req, res, log, error }) => {
  try {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      error('Missing RESEND_API_KEY.');
      return res.json({ error: 'Email service is not configured.' }, 500);
    }

    const event = req.headers['x-appwrite-event'] || '';

    // Robust body parsing: Appwrite runtimes may deliver req.body as a
    // pre-parsed object, a JSON string, or (via bodyRaw) a raw string.
    let body;
    const raw = typeof req.bodyRaw === 'string' ? req.bodyRaw : null;
    if (req.body !== null && typeof req.body === 'object') {
      body = req.body;
    } else {
      const src = raw || (typeof req.body === 'string' ? req.body : '{}');
      log(`[debug] body type=${typeof req.body}, raw type=${typeof req.bodyRaw}, src=${src.substring(0, 120)}`);
      body = JSON.parse(src || '{}');
    }
    const from = process.env.RECEIPT_SENDER_EMAIL || process.env.SENDER_EMAIL || defaultSender;
    // Every outbound email replies to the monitored support mailbox unless the
    // caller explicitly overrides it in the execution body.
    const replyTo =
      (typeof body.reply_to === 'string' && body.reply_to.trim()) ||
      (typeof body.replyTo === 'string' && body.replyTo.trim()) ||
      process.env.REPLY_TO_EMAIL ||
      defaultReplyTo;
    // Every outbound email is also CC'd to the support mailbox unless the
    // caller overrides it, so there is a complete copy of all correspondence.
    const ccAddress =
      (typeof body.cc === 'string' && body.cc.trim()) ||
      replyTo;

    // 1. Handle automatic Welcome Email on user registration / creation event
    const isUserCreateEvent = event.startsWith('users.') && event.endsWith('.create');
    const isExplicitWelcome = body.action === 'send_welcome' && body.email;

    if (isUserCreateEvent || isExplicitWelcome) {
      const recipientEmail = body.email;
      if (!recipientEmail || !validateEmail(recipientEmail)) {
        log(`No valid email found in user creation event. Skipping welcome email.`);
        return res.json({ ok: false, message: 'No valid recipient email in event' });
      }

      const recipientName = (body.name && body.name.trim()) ? body.name.trim() : 'Dear Friend';
      const welcomeSubject = 'Welcome to ALIVE Nigeria - Connecting Faith, Fellowship & Mission';
      const welcomeHtml = getWelcomeEmailHtml(recipientName);

      log(`Sending welcome email to ${recipientEmail} (${recipientName})...`);

      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [recipientEmail],
          cc: [ccAddress],
          reply_to: replyTo,
          subject: welcomeSubject,
          html: welcomeHtml,
        }),
      });

      const responseBody = await response.text();
      if (!response.ok) {
        error(`Resend welcome email failed (${response.status}): ${responseBody}`);
        return res.json({ error: 'Welcome email delivery failed.' }, 502);
      }

      log(`Welcome email successfully sent to ${recipientEmail}.`);
      return res.json({ ok: true, type: 'welcome_email_sent' });
    }

    // 2. Handle standard direct email sending (receipts, notifications)
    if (req.method !== 'POST') {
      return res.json({ error: 'Method not allowed. Use POST.' }, 405);
    }

    const userId = req.headers['x-appwrite-user-id'];
    // Allow if authenticated user or internal execution
    const isInternal = Boolean(req.headers['x-appwrite-key']);
    if (!userId && !isInternal) {
      return res.json({ error: 'Authentication required.' }, 401);
    }

    const to = validateEmail(body.to);
    const subject = validateSubject(body.subject);
    const html = validateHtml(body.html);

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        cc: [ccAddress],
        reply_to: replyTo,
        subject,
        html,
      }),
    });

    const responseBody = await response.text();
    if (!response.ok) {
      error(`Resend email failed (${response.status}): ${responseBody}`);
      return res.json({ error: 'Email send failed.' }, 502);
    }

    log(`Email sent to ${to} by user ${userId || 'internal'}.`);
    return res.json({ ok: true });
  } catch (err) {
    error(`Email send failed: ${err.message}`);
    return res.json({ error: err.message || 'Internal Server Error' }, 500);
  }
};

function getWelcomeEmailHtml(name) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to ALIVE Nigeria App</title>
</head>
<body style="margin: 0; padding: 0; background-color: #FCFAF5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #17263B;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #FCFAF5; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 580px; background-color: #FFFFFF; border-radius: 16px; border: 1px solid #E7E0D1; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.05);">
          <!-- Header Banner -->
          <tr>
            <td style="background-color: #233E5F; padding: 36px 32px; text-align: center;">
              <img src="${ALIVE_LOGO_URL}" alt="ALIVE Nigeria" width="96" height="96" style="display: block; margin: 0 auto 16px; width: 96px; height: 96px; border: 0; outline: none; text-decoration: none;" />
              <h1 style="margin: 0; color: #E5B94D; font-size: 26px; font-weight: 800; letter-spacing: 0.5px;">ALIVE Nigeria</h1>
              <p style="margin: 8px 0 0; color: #F7F4EC; font-size: 14px; opacity: 0.9;">Connecting Faith, Fellowship & Mission</p>
            </td>
          </tr>
          <!-- Body Content -->
          <tr>
            <td style="padding: 36px 32px;">
              <h2 style="margin: 0 0 16px; color: #17263B; font-size: 20px; font-weight: 700;">Welcome, ${name}!</h2>
              <p style="margin: 0 0 18px; line-height: 1.6; color: #475569; font-size: 15px;">
                We are thrilled to welcome you to the <strong>ALIVE Nigeria</strong> community. Your account is now active and ready to explore!
              </p>
              <p style="margin: 0 0 24px; line-height: 1.6; color: #475569; font-size: 15px;">
                Here is what you can do right away:
              </p>
              <!-- Features List -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom: 28px;">
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #F6F2E9;">
                    <strong style="color: #233E5F;">📖 Bible Reader & Games</strong>
                    <div style="color: #687586; font-size: 13px; margin-top: 2px;">Read scriptures, play Bible memory games, and explore daily verses.</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #F6F2E9;">
                    <strong style="color: #233E5F;">🏛️ ALIVE Chapters Across Nigeria</strong>
                    <div style="color: #687586; font-size: 13px; margin-top: 2px;">Connect with your local chapter, participate in activities, and join fellowships.</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0; border-bottom: 1px solid #F6F2E9;">
                    <strong style="color: #233E5F;">🙏 Prayer Wall & Testimonies</strong>
                    <div style="color: #687586; font-size: 13px; margin-top: 2px;">Share prayer requests, strengthen each other in faith, and testify of God's goodness.</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 10px 0;">
                    <strong style="color: #233E5F;">🌱 Discipleship & Mission Training</strong>
                    <div style="color: #687586; font-size: 13px; margin-top: 2px;">Access books, tracts, interactive study guides, podcasts, and video resources.</div>
                  </td>
                </tr>
              </table>

              <!-- Action Button -->
              <div style="text-align: center; margin: 32px 0 20px;">
                <a href="https://app.alivenigeria.org" style="display: inline-block; background-color: #E5B94D; color: #17263B; text-decoration: none; padding: 14px 32px; border-radius: 10px; font-weight: 700; font-size: 15px; box-shadow: 0 4px 12px rgba(229,185,77,0.35);">Launch ALIVE Nigeria App</a>
              </div>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="background-color: #F6F2E9; padding: 24px 32px; text-align: center; border-top: 1px solid #E7E0D1;">
              <p style="margin: 0 0 6px; color: #687586; font-size: 13px;">
                Need help or have questions? Email us anytime at <a href="mailto:app@alivenigeria.org" style="color: #233E5F; font-weight: 600;">app@alivenigeria.org</a>
              </p>
              <p style="margin: 0; color: #94A3B8; font-size: 12px;">
                &copy; ${new Date().getFullYear()} ALIVE Nigeria. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

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

