// Adds `monthly_reminder_opt_out` to the per-user `notification_settings` table.
//
// The monthly reminder opt-out is currently stored only in local
// SharedPreferences, but the monthlyDonationReminder function runs server-side
// and cannot see it. It instead reads a *shared* app_settings document listing
// opted-out user ids -- which nothing ever writes. Net effect: a member who
// turns the reminder off in the app is still sent the push.
//
// A per-user column fixes this properly. The function can then read the same
// row it already reads for other preferences, and the member's choice follows
// them across devices instead of living on one handset.
//
// Appwrite rejects a whole row write that contains an unknown attribute, so the
// column must exist before the client can write it.
//
// Idempotent: an existing column is left alone.
//
//   node scripts/ensure_reminder_optout_column.mjs
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}
loadDotEnv();

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = process.env.APPWRITE_DATABASE_ID;
const tableId = process.env.APPWRITE_NOTIFICATION_SETTINGS_TABLE_ID || 'notification_settings';

for (const [name, value] of Object.entries({ endpoint, projectId, apiKey, databaseId })) {
  if (!value) throw new Error(`Missing ${name} in .env`);
}

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

const COLUMNS = [
  {
    key: 'monthly_reminder_opt_out',
    type: 'boolean',
    required: false,
    // Default false: existing members keep receiving the reminder, which is the
    // behaviour before this column existed. Defaulting to true would silently
    // unsubscribe everyone the first time the function ran.
    value: false,
    // Nullable so an explicit "not set" is distinguishable from an explicit
    // false. Both mean "send the reminder" today, but the distinction matters if
    // the default ever changes.
    set: null,
    size: 0,
    encrypted: false,
  },
];

for (const col of COLUMNS) {
  const existing = await fetch(
    `${endpoint}/v1/tablesdb/${databaseId}/tables/${tableId}/columns/${col.key}`,
    { headers },
  );
  if (existing.ok) {
    console.log(`[skip] ${tableId}.${col.key} already exists.`);
    continue;
  }

  const res = await fetch(
    `${endpoint}/v1/tablesdb/${databaseId}/tables/${tableId}/columns/boolean`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({
        key: col.key,
        required: col.required,
        value: col.value,
        set: col.set,
        size: col.size,
        encrypted: col.encrypted,
      }),
    },
  );
  const body = await res.json();
  if (!res.ok) {
    console.error(`[FAIL] ${col.key}: ${res.status} ${body.message}`);
    process.exit(1);
  }
  console.log(`[ok] created ${tableId}.${col.key} (default ${col.value})`);
}

console.log('\nDone. Existing rows read as false, so no member is silently unsubscribed.');
