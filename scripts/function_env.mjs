// Shows a function's environment variable values, with secrets masked.
//
// The variable *names* being right does not mean the values are: a stale
// RECEIPT_SENDER_EMAIL left on the function silently sends every password reset
// from the wrong address, and the only symptom is a mail that looks off.
//
//   node scripts/function_env.mjs <functionId> [secretSubstring...]
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
};

const functionId = process.argv[2];
if (!functionId) {
  console.error('usage: node scripts/function_env.mjs <functionId> [secretSubstring...]');
  process.exit(1);
}

// Anything whose name looks like a credential is masked unless the caller
// explicitly asks for it by passing a matching substring.
const alwaysSecret = /KEY|SECRET|TOKEN|PASSWORD|DSN/i;
const revealed = process.argv.slice(3);

const mask = (key, value) => {
  const asked = revealed.some((s) => key.toUpperCase().includes(s.toUpperCase()));
  if (!alwaysSecret.test(key) || asked) return value;
  if (!value) return '(empty)';
  return `${value.slice(0, 4)}...${value.slice(-4)} (${value.length} chars)`;
};

const res = await fetch(`${endpoint}/v1/functions/${functionId}`, { headers });
const j = await res.json();
if (!res.ok) {
  console.error(`${res.status}: ${JSON.stringify(j).slice(0, 300)}`);
  process.exit(1);
}

console.log(`${j.name} (${j.$id})\n`);
for (const v of j.vars || []) {
  console.log(`  ${v.key}`);
  console.log(`    = ${mask(v.key, v.value ?? '')}`);
  if (v.secret) console.log('    (stored as a secret)');
}
