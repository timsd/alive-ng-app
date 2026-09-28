// Sends one real email through Resend to prove the branded pipeline works.
//
// The belief that "branded email is not working" came from password reset, where
// Appwrite 1.8.1 never returns the recovery secret -- a different problem from
// Resend delivery. This separates the two: if a test send arrives, Resend and
// the verified domain are fine and only the password-reset path is broken.
//
//   node scripts/test_resend_send.mjs <recipient>
const recipient = process.argv[2] || 'dammyolodude@gmail.com';

import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
}
const key = process.env.RESEND_API_KEY;
const from = process.env.SENDER_EMAIL || 'ALIVE Nigeria App <msg@app.alivenigeria.org>';
const replyTo = process.env.REPLY_TO_EMAIL || 'app@alivenigeria.org';

if (!key) { console.log('RESEND_API_KEY is not set in .env'); process.exit(1); }

console.log(`from      : ${from}`);
console.log(`reply_to  : ${replyTo}`);
console.log(`to        : ${recipient}\n`);

const res = await fetch('https://api.resend.com/emails', {
  method: 'POST',
  headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from,
    to: [recipient],
    reply_to: replyTo,
    subject: 'ALIVE Nigeria - email delivery test',
    html: '<p>This is a delivery test. If you are reading it, branded email works.</p>',
  }),
});

const body = await res.json();
console.log(`status: ${res.status}`);
if (res.ok) {
  console.log(`id: ${body.id}`);
  console.log('\nResend accepted it. Check the inbox (and spam) for the message.');
  console.log('If it does not arrive, check Resend dashboard > Logs for the delivery status.');
} else {
  console.log(JSON.stringify(body, null, 2));
}
