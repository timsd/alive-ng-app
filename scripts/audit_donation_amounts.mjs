// Checks whether any live donation row relies on amount_kobo instead of amount.
//
// DonationRecord.fromJson does `amount: (json['amount'] as num).toDouble()`,
// which throws if amount is absent or null. If any row stores only amount_kobo,
// that call site would crash rather than degrade.
//
//   node scripts/audit_donation_amounts.mjs
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

let total = 0, ok = 0, missing = 0, nullAmount = 0, koboOnly = 0;
const problems = [];

for (let offset = 0; ; offset += 100) {
  const res = await fetch(
    `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows?limit=100&offset=${offset}`,
    { headers },
  );
  const j = await res.json();
  if (!res.ok) { console.log(`ERROR ${res.status}: ${j.message}`); process.exit(1); }
  for (const row of j.rows) {
    total++;
    const a = row.amount;
    const k = row.amount_kobo;
    if (a === null || a === undefined) {
      if (k !== null && k !== undefined && k !== 0) {
        koboOnly++;
        problems.push({ id: row.$id, amount: a, amount_kobo: k });
      } else if (a === null) nullAmount++;
      else missing++;
    } else ok++;
  }
  if (j.rows.length < 100) break;
}

console.log(`donation_records: ${total} row(s)\n`);
console.log(`  amount populated          ${ok}`);
console.log(`  amount null               ${nullAmount}`);
console.log(`  amount missing            ${missing}`);
console.log(`  amount_kobo only (!)      ${koboOnly}`);

if (koboOnly > 0) {
  console.log('\n  !! These rows would CRASH DonationRecord.fromJson:');
  for (const p of problems) console.log(`     ${p.id}: amount=${p.amount} amount_kobo=${p.amount_kobo}`);
} else {
  console.log('\n  OK: every row has a usable `amount`, so the unguarded cast is safe today.');
  console.log('      It remains fragile only for a future row written without amount.');
}
