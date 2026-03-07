import nodemailer from 'nodemailer';

export async function sendTransactionalEmail({ to, subject, html }) {
  const user = process.env.BREVO_SMTP_USER;
  const pass = process.env.BREVO_SMTP_PASS;
  const from = process.env.SENDER_EMAIL || 'noreply@alivenigeria.org';

  if (!user || !pass) {
    throw new Error('Missing BREVO_SMTP_USER/BREVO_SMTP_PASS env');
  }

  const transporter = nodemailer.createTransport({
    host: 'smtp-relay.brevo.com',
    port: 587,
    secure: false,
    auth: { user, pass },
  });

  await transporter.sendMail({
    from,
    to,
    subject,
    html,
  });
}
