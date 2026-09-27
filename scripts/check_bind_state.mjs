// Checks that the rows the binding test touched were put back.
//
// The test deletes its throwaway account, so org_office_holders is left pointing
// at a user id that no longer exists. That stale pointer would block the real
// signup: the queue rows are restored as unconsumed, but the holders rows still
// name a dead user. This reports that state so it can be reset.
//
//   node scripts/check_bind_state.mjs [email]
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
const db = process.env.APPWRITE_DATABASE_ID;

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  const t = await r.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  return { status: r.status, j };
};

const email = (process.argv[2] || '').toLowerCase();

const queue = await get(`/databases/${db}/collections/officer_registry/documents?limit=200`);
const holders = await get(`/databases/${db}/collections/org_office_holders/documents?limit=200`);

const queued = (queue.j.documents || []).filter(
  (d) => !email || String(d.email || '').toLowerCase() === email,
);
console.log(`registry rows${email ? ` for ${email}` : ''}: ${queued.length}`);
for (const d of queued) {
  console.log(`  ${d.office_id}  consumed=${d.consumed}  by=${d.consumed_by || '-'}`);
}

// A holder row bound to a user id that no longer exists is stale.
const users = await get('/users?limit=1000');
const liveIds = new Set((users.j.users || []).map((u) => u.$id));

const holderRows = (holders.j.documents || []).filter((h) => h.user_id);
const stale = holderRows.filter((h) => !liveIds.has(h.user_id));
const bound = holderRows.filter((h) => liveIds.has(h.user_id));

console.log(`\nholder rows with a user_id: ${holderRows.length}`);
console.log(`  pointing at a live user:  ${bound.length}`);
for (const b of bound) console.log(`    ${b.office_id}  ${b.full_name}  <${b.email}>`);
console.log(`  pointing at a dead user:  ${stale.length}`);
for (const s of stale) {
  console.log(`    ${s.office_id}  ${s.full_name}  user_id=${s.user_id}`);
}

if (stale.length) {
  console.log(
    '\nThe dead rows above will block the real signup until cleared -- reset them with:',
  );
  console.log('  node scripts/reset_bindtest_bindings.mjs');
}
