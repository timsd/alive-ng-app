// Sets the admin flag that lets members opt out of the monthly giving reminder.
//
// The flag lives in app_settings / monthly_reminder / value.user_toggle_enabled.
// While it is false the member toggle is hidden AND the reminder ignores any
// per-user opt-out, so everybody is reminded. This had never been created, so
// the reminder was in that state by accident rather than by decision.
//
//   node scripts/set_reminder_admin_flag.mjs            (report only)
//   node scripts/set_reminder_admin_flag.mjs --enable
//   node scripts/set_reminder_admin_flag.mjs --disable
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
const tableId = process.env.APPWRITE_APP_SETTINGS_TABLE_ID || 'app_settings';
const DOC_ID = 'monthly_reminder';

const wantsEnable = process.argv.includes('--enable');
const wantsDisable = process.argv.includes('--disable');
if (wantsEnable && wantsDisable) {
  console.error('Pass at most one of --enable / --disable.');
  process.exit(1);
}

const url = `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows/${DOC_ID}`;
const current = await fetch(url, { headers });
let existing = null;
if (current.ok) {
  const row = await current.json();
  let v = row.value;
  if (typeof v === 'string') { try { v = JSON.parse(v); } catch { /* leave as-is */ } }
  existing = v;
}

// A required `key` column means the row cannot be created without it. Read the
// table's columns rather than guessing, so the write matches the real schema.
const colsRes = await fetch(
  `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/columns?limit=200`, { headers });
const cols = (await colsRes.json()).columns ?? [];
const required = cols.filter((c) => c.required).map((c) => c.key);
console.log(`required columns on ${tableId}: ${required.join(', ') || '(none)'}\n`);

console.log(`app_settings / ${DOC_ID}`);
console.log(`  current: ${existing === null ? '(document does not exist)' : JSON.stringify(existing)}`);

if (!wantsEnable && !wantsDisable) {
  console.log(
    existing?.user_toggle_enabled === true
      ? '\n  Members CAN opt out. No change needed.'
      : '\n  Members CANNOT opt out; everyone is reminded. ' +
        'Re-run with --enable to change that.',
  );
  process.exit(0);
}

const enabled = wantsEnable;
// PATCH bodies must be wrapped in { data: ... } on Appwrite 1.8.
const payload = { data: { value: JSON.stringify({ user_toggle_enabled: enabled }) } };
let res = await fetch(url, { method: 'PATCH', headers, body: JSON.stringify(payload) });

if (res.status === 404) {
  // Appwrite create needs the key inside data, and rowId in the body.
  res = await fetch(`${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      ...payload,
      rowId: DOC_ID,
      // The table is keyed by a separate `key` column, so the row id and the
      // key column both have to carry the document name. Appwrite rejects the
      // whole write with row_invalid_structure when a required one is missing.
      data: { ...payload.data, key: DOC_ID },
    }),
  });
  console.log(res.ok ? '  created' : `  FAILED (${res.status})`);
} else {
  console.log(res.ok ? '  updated' : `  FAILED (${res.status})`);
}

if (!res.ok) {
  console.error(await res.text());
  process.exit(1);
}

// Read back rather than trusting the write.
const verify = await fetch(url, { headers });
const row = await verify.json();
let v = row.value;
if (typeof v === 'string') { try { v = JSON.parse(v); } catch {} }
console.log(`  now: ${JSON.stringify(v)}`);
console.log(
  v?.user_toggle_enabled === enabled
    ? `\n  OK: members ${enabled ? 'can now' : 'can no longer'} opt out.`
    : '\n  !! Read-back does not match. Check the value column type (string vs json).',
);
