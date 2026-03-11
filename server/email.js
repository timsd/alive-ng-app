// email.js — Send emails via Resend API
// Requires RESEND_API_KEY environment variable.

const RESEND_API_KEY = process.env.RESEND_API_KEY || '';
const SENDER_EMAIL = process.env.SENDER_EMAIL || 'onboarding@resend.dev';

/**
 * Send a transactional email via Resend.
 * @param {string} to - Recipient email address.
 * @param {string} subject - Email subject.
 * @param {string} html - HTML body.
 * @returns {Promise<void>}
 */
export async function sendTransactionalEmail(to, subject, html) {
  if (!RESEND_API_KEY) {
    console.warn('sendTransactionalEmail: RESEND_API_KEY not set, skipping');
    return;
  }
  const resp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: SENDER_EMAIL,
      to: [to],
      subject,
      html,
    }),
  });
  if (!resp.ok) {
    const body = await resp.text();
    throw new Error(`Resend email failed (${resp.status}): ${body}`);
  }
}
