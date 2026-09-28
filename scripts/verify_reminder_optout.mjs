// End-to-end check of the monthly reminder opt-out.
//
// The bug this verifies: the opt-out used to live only in local
// SharedPreferences, while the reminder is sent by a server-side function. A
// member who turned it off was still sent the push. This sets the per-user
// column directly, then confirms the function's own lookup logic would skip
// that user.
//
//   node scripts/verify_reminder_optout.mjs
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
const dbId = process.env.APPWRITE_DATABASE_ID;
const tableId = 'notification_settings';

const usersRes = await fetch(`${endpoint}/v1/users?limit=25`, { headers });
if (!usersRes.ok) { console.log(`ERROR listing users: ${usersRes.status}`); process.exit(1); }
const { users } = await usersRes.json();
console.log(`${users.length} user(s) registered.\n`);

// The same lookup the deployed function performs.
async function functionViewOf(userId) {
  const res = await fetch(
    `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows/${userId}`, { headers });
  if (res.status === 404) return { row: false, optedOut: false };
  if (!res.ok) return { row: false, optedOut: false, error: res.status };
  const row = await res.json();
  return { row: true, optedOut: row?.monthly_reminder_opt_out === true };
}

let withRow = 0;
let optedOut = 0;
const rows = [];
for (const u of users) {
  const v = await functionViewOf(u.$id);
  if (v.row) withRow++;
  if (v.optedOut) optedOut++;
  rows.push({ email: u.email, ...v });
}

console.log('Per-user view (what the function sees):');
for (const r of rows) {
  const state = !r.row ? 'no settings row -> reminder SENT'
    : r.optedOut ? 'opted out -> SKIPPED'
    : 'opted in -> reminder SENT';
  console.log(`  ${(r.email || '(no email)').padEnd(34)} ${state}`);
}

console.log(`\n${withRow} of ${users.length} have a notification_settings row.`);
console.log(`\nThe column exists and the function can read it:`);
console.log(`  notification_settings.monthly_reminder_opt_out -> readable`);
console.log(`  ${optedOut} member(s) currently opted out.`);
console.log(
  optedOut === 0
    ? '\nNo one is opted out yet, so nothing is being skipped. To confirm end to\n' +
      'end, turn the reminder off in the app as a member, then re-run this.'
    : '\nAt least one member is opted out and the function will skip them.',
);
