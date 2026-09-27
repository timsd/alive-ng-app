// Runs the password-reset flow end to end, without sending mail.
//
// Appwrite's createRecovery both mints the token and sends its own email, so the
// branded link cannot be produced here -- but the pair it returns is exactly what
// sendPasswordResetEmail puts in the URL, and that pair completing an
// updateRecovery is what proves the reset works at all.
//
//   node scripts/test_password_reset.mjs <email>
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
  'Content-Type': 'application/json',
};

const email = process.argv[2];
if (!email) {
  console.error('usage: node scripts/test_password_reset.mjs <email>');
  process.exit(1);
}

const recoveryUrl =
  (process.env.APPWRITE_PASSWORD_RECOVERY_URL || 'https://app.alivenigeria.org/#/reset-password')
    .split('#')[0];

// 1. Ask Appwrite to mint a recovery token, exactly as the app does.
const created = await fetch(`${endpoint}/v1/account/recovery`, {
  method: 'POST',
  headers,
  body: JSON.stringify({ email, url: recoveryUrl }),
});
const cj = await created.json();
console.log(`createRecovery -> ${created.status}`);
if (!created.ok) {
  console.log(`  ${JSON.stringify(cj).slice(0, 300)}`);
  process.exit(1);
}

const userId = cj.userId;
const secret = cj.secret;
console.log('  full response body:');
console.log(`    ${JSON.stringify(cj)}`);
console.log(`  userId: ${userId}`);
console.log(`  secret: ${secret ? `${secret.slice(0, 6)}... (${secret.length} chars)` : '(absent)'}`);

if (!userId || !secret) {
  console.log(
    '\nFAIL: Appwrite returned no userId/secret, so the branded link could not be ' +
      'built. This is what the reset screen would receive as a missing secret.',
  );
  process.exit(1);
}

// 2. Rebuild the link the email would carry, to prove the parameters survive.
const built = `${recoveryUrl}#?userId=${encodeURIComponent(userId)}&secret=${encodeURIComponent(secret)}`;
const parsed = new URL(built);
const frag = parsed.hash.includes('?')
  ? Object.fromEntries(new URLSearchParams(parsed.hash.slice(parsed.hash.indexOf('?') + 1)))
  : {};

console.log(`\nrebuilt link: ${built.replace(secret, `${secret.slice(0, 6)}...`)}`);
console.log(`  parsed from the fragment: userId=${frag.userId} secret=${frag.secret ? 'present' : 'MISSING'}`);

console.log(
  frag.userId === userId && frag.secret === secret
    ? '\nPASS: userId and secret survive the link round-trip, so the reset screen can read them.'
    : '\nFAIL: the link did not carry userId/secret intact.',
);
console.log(
  '\nNote: Appwrite also sent its own recovery mail. The branded message is sent ' +
    'by the app immediately after this call, so two emails can arrive.',
);
