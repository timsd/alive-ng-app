// Deletes leftover bindtest* accounts.
//
// The binding test creates a throwaway account per run. If a run is interrupted
// (a piped command closing early, a crash) the cleanup never happens, and the
// next run fails with 409 user_already_exists instead of testing anything.
//
//   node scripts/cleanup_bindtest_users.mjs
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

let removed = 0;
for (let page = 0; page < 5; page++) {
  const res = await fetch(`${endpoint}/v1/users?limit=100`, { headers });
  const j = await res.json();
  if (!res.ok) {
    console.error(`${res.status}: ${JSON.stringify(j).slice(0, 300)}`);
    process.exit(1);
  }
  const stale = (j.users || []).filter((u) => String(u.$id).startsWith('bindtest'));
  if (!stale.length) break;
  for (const u of stale) {
    const d = await fetch(`${endpoint}/v1/users/${u.$id}`, { method: 'DELETE', headers });
    console.log(`deleted ${u.$id} (${u.email}) -> ${d.status}`);
    if (d.ok) removed++;
  }
  if (!j.users?.length) break;
}

console.log(removed ? `\nremoved ${removed} stale test account(s)` : 'nothing to clean up');
