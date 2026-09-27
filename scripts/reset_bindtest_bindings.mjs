// Clears org_office_holders rows left pointing at a deleted bindtest account.
//
// The binding test creates a throwaway user, the function binds the office to
// it, and the test then deletes the user. That leaves the holder row naming a
// user id that no longer exists, so when the real person signs up the office
// gate is gated on a dead account. The registry rows are restored as
// unconsumed, but the holders rows are not, so this puts them back.
//
//   node scripts/reset_bindtest_bindings.mjs [--dry-run]
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
const db = process.env.APPWRITE_DATABASE_ID;
const dryRun = process.argv.includes('--dry-run');

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  return { status: r.status, j: await r.json().catch(() => ({})) };
};

const users = await get('/users?limit=1000');
const liveIds = new Set((users.j.users || []).map((u) => u.$id));

const holders = await get(`/databases/${db}/collections/org_office_holders/documents?limit=200`);
const stale = (holders.j.documents || []).filter(
  (h) => h.user_id && !liveIds.has(h.user_id),
);

if (!stale.length) {
  console.log('nothing stale; every bound office points at a live user');
  process.exit(0);
}

console.log(`${dryRun ? 'would clear' : 'clearing'} ${stale.length} stale row(s):`);
for (const s of stale) {
  console.log(`  ${s.office_id}  ${s.full_name}  user_id=${s.user_id}`);
  if (dryRun) continue;
  // Appwrite 1.8 reads a PATCH body as empty unless wrapped in `data`.
  const r = await fetch(
    `${endpoint}/v1/databases/${db}/collections/org_office_holders/documents/${s.$id}`,
    {
      method: 'PATCH',
      headers,
      body: JSON.stringify({
        data: { user_id: '', email: '', is_current: false },
      }),
    },
  );
  console.log(`    -> ${r.status}`);
}

// Leave the registry queue consistent with the cleared holders.
const queue = await get(`/databases/${db}/collections/officer_registry/documents?limit=200`);
for (const d of queue.j.documents || []) {
  if (!d.consumed) continue;
  if (!String(d.consumed_by || '').startsWith('bindtest')) continue;
  console.log(`restoring queue row ${d.office_id} (was consumed by ${d.consumed_by})`);
  if (dryRun) continue;
  await fetch(`${endpoint}/v1/databases/${db}/collections/officer_registry/documents/${d.$id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({
      data: { consumed: false, consumed_by: '', consumed_at: '' },
    }),
  });
}

console.log(dryRun ? '\ndry run; nothing changed' : '\ndone');
