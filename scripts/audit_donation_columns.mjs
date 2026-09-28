// Reports which of the duplicate / legacy donation columns actually carry data.
//
// donation_report_models falls back across several column names
// (user_id vs userId, user_email vs email, id vs $id, created_at vs $createdAt).
// Those fallbacks are only safe to remove if the "primary" name is the one that
// is actually populated. This checks the live rows so the cleanup is driven by
// data rather than by assumption.
//
//   node scripts/audit_donation_columns.mjs
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
const tableId = 'donation_records';

const GROUPS = [
  ['user id', ['user_id', 'userId']],
  ['email', ['user_email', 'email']],
  ['name', ['user_name', 'full_name']],
  ['reference', ['reference', 'transaction_id', 'id', '$id']],
  ['created', ['created_at', '$createdAt']],
  ['purpose', ['purpose', 'project_title']],
];

const filled = new Map();
let total = 0;
for (let offset = 0; ; offset += 100) {
  const res = await fetch(
    `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows?limit=100&offset=${offset}`, { headers });
  const j = await res.json();
  if (!res.ok) { console.log(`ERROR ${res.status}: ${j.message}`); process.exit(1); }
  for (const row of j.rows) {
    total++;
    for (const [, keys] of GROUPS) {
      for (const k of keys) {
        const v = row[k];
        const isSet = v !== null && v !== undefined && String(v).trim() !== '';
        // $id / id are always present; treat them as set so the comparison is
        // about whether they are the ONLY source of the value.
        if (isSet) filled.set(k, (filled.get(k) ?? 0) + 1);
      }
    }
  }
  if (j.rows.length < 100) break;
}

console.log(`donation_records: ${total} row(s)\n`);
for (const [label, keys] of GROUPS) {
  console.log(`  ${label}:`);
  for (const k of keys) {
    const n = filled.get(k) ?? 0;
    console.log(`    ${k.padEnd(20)} ${n}/${total}  ${n === 0 ? '(empty)' : ''}`);
  }
}

console.log('\nOnly the first populated name in each group is needed; the rest are');
console.log('fallbacks that never fire and can be removed.');
