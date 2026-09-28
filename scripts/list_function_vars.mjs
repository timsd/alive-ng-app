// Lists the environment variables on one Appwrite Function, by name.
//
// check_function_vars.mjs redacts values and prints every function, which makes
// it hard to confirm that a *specific* variable is present on a specific
// function -- a rejected variable is indistinguishable from an absent one in
// that output.
//
//   node scripts/list_function_vars.mjs delete_account
const fnId = process.argv[2] || 'delete_account';

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

const res = await fetch(`${endpoint}/v1/functions/${fnId}/variables?limit=100`, { headers });
if (!res.ok) {
  console.log(`ERROR ${res.status}: ${(await res.text()).slice(0, 200)}`);
  process.exit(1);
}
const vars = (await res.json()).variables ?? [];
console.log(`${fnId}: ${vars.length} variable(s)\n`);
for (const v of vars) {
  // Show the shape without leaking the secret.
  const shown = /KEY|SECRET|TOKEN|PASSWORD/.test(v.key)
    ? `[set, ${String(v.value).length} chars]`
    : v.value;
  console.log(`  ${v.key.padEnd(34)} ${shown}`);
}

const has = (k) => vars.some((v) => v.key === k);
console.log('');
for (const required of ['RESEND_API_KEY', 'SENDER_EMAIL', 'REPLY_TO_EMAIL']) {
  console.log(`  ${required.padEnd(34)} ${has(required) ? 'present' : 'MISSING'}`);
}
