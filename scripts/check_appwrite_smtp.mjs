// Reports whether Appwrite can send its own recovery email.
//
// The branded reset link cannot be built: Appwrite 1.8's createRecovery returns
// userId but an EMPTY secret (see test_password_reset.mjs). The only copy of
// the secret is in Appwrite's own recovery mail. So if SMTP is not configured on
// the Appwrite project, the branded mail goes out with a link that cannot work
// and no native mail is sent either -- which is exactly "the link does not
// work".
//
//   node scripts/check_appwrite_smtp.mjs
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
const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};

const res = await fetch(`${endpoint}/v1/projects/${process.env.APPWRITE_PROJECT_ID}`, { headers });
if (!res.ok) {
  console.log(`ERROR ${res.status}: ${(await res.text()).slice(0, 200)}`);
  process.exit(1);
}
const p = await res.json();

console.log('Appwrite project email configuration:\n');
console.log(`  smtp_server   : ${p.smtpServer || '(NOT SET)'}`);
console.log(`  smtp_port     : ${p.smtpPort ?? '(not set)'}`);
console.log(`  smtp_secure   : ${p.smtpSecure ?? '(not set)'}`);
console.log(`  sender_name   : ${p.senderName || '(NOT SET)'}`);
console.log(`  sender_email  : ${p.senderEmail || '(NOT SET)'}`);

const configured = Boolean(p.smtpServer && p.senderEmail);
console.log('');
if (configured) {
  console.log('  SMTP is configured: Appwrite can send its own recovery email,');
  console.log('  which is the only place the recovery secret exists.');
  console.log('  Next check: the recovery URL in Console > Auth > Security, and');
  console.log('  whether an email actually arrives.');
} else {
  console.log('  !! SMTP is NOT configured.');
  console.log('  Appwrite cannot send its native recovery email, and that email is');
  console.log('  the only source of the recovery secret. Password reset therefore');
  console.log('  cannot complete until SMTP is set up on the Appwrite project.');
  console.log('  Console > Project > Settings > SMTP:');
  console.log('    - use the same verified Resend domain (smtp.resend.com, port 465)');
  console.log('    - sender: ALIVE Nigeria <msg@app.alivenigeria.org>');
}

// The client-side recovery URL is what the secret is appended to.
console.log('\nClient recovery URL:');
const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const m = cfg.match(/passwordRecoveryUrl\s*=\s*'([^']+)'/);
console.log(`  ${m ? m[1] : '(not found in config)'}`);
console.log('  Appwrite appends ?userId=..&secret=.. to this URL, and the router');
console.log('  reads both from the query string and the fragment.');
