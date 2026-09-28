// Reads Appwrite's built-in email templates.
//
// Appwrite's recovery email is the only source of the recovery secret (see
// check_appwrite_smtp.mjs and test_password_reset.mjs), so once SMTP is set this
// template is what the member actually clicks. The Console can edit it by hand;
// this reports the current state so a change can be verified afterwards.
//
//   node scripts/check_appwrite_templates.mjs
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

const res = await fetch(`${endpoint}/v1/templates/email`, { headers });
if (!res.ok) {
  console.log(`ERROR ${res.status}: ${(await res.text()).slice(0, 300)}`);
  console.log('\nIf this is a 401/403 the API key lacks a templates scope; the');
  console.log('templates can still be edited in Console > Project > Settings >');
  console.log('Templates, or in the Appwrite dashboard.');
  process.exit(1);
}

const templates = (await res.json()).templates ?? [];
console.log(`${templates.length} email template(s)\n`);
for (const t of templates) {
  const isRecovery = t.type === 'recovery';
  const marker = isRecovery ? ' <-- the password reset email' : '';
  console.log(`  ${String(t.name).padEnd(22)} type=${t.type.padEnd(12)} ` +
    `subject=${t.subject ?? '(none)'}${marker}`);
  if (isRecovery) {
    const body = t.body ?? '';
    console.log(`     body length: ${body.length} chars`);
    console.log(`     mentions {{link}}: ${body.includes('{{link}}')}`);
    console.log(`     mentions {{user}}: ${body.includes('{{user}}') || body.includes('{{name}}')}`);
    console.log(`     brand name in body: ${body.includes('ALIVE') ? 'yes' : 'no (Appwrite default)'}`);
  }
}

console.log('\nPlaceholders Appwrite provides for the recovery template:');
console.log('  {{user}}        the recipient address');
console.log('  {{link}}        the recovery URL, already carrying userId + secret');
console.log('  {{project}}     project name');
console.log('  {{redirect}}    the redirect URL from the recovery request');
console.log('\n{{link}} is the important one: it is the only place the secret appears.');
