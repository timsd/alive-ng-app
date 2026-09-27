// Binds org_office_holders rows to real Appwrite accounts, and reconciles
// the board chair with `org_structure.dart`.
//
// The seed could only write names: every holder row shipped with an empty
// `user_id`, so nothing could match a signed-in account and the finance gate
// had no way to resolve a Treasurer or President. Accounts that do not exist
// are left unbound, which fails safe -- the gate denies rather than guessing
// from a display name.
//
//   node scripts/bind_org_office_holders.mjs          (report only)
//   node scripts/bind_org_office_holders.mjs --apply  (write)
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
const APPLY = process.argv.includes('--apply');

const get = async (p) => {
  const res = await fetch(`${endpoint}/v1${p}`, { headers });
  const text = await res.text();
  let j = {};
  try { j = JSON.parse(text); } catch {}
  return { status: res.status, j, text };
};

// Appwrite 1.8 reads a PATCH document body as empty unless it is wrapped.
const patch = async (id, data) => {
  const res = await fetch(`${endpoint}/v1/databases/${db}/collections/org_office_holders/documents/${id}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ data }),
  });
  return { status: res.status, text: await res.text() };
};

const BINDINGS = [
  { email: 'dammyolodude@gmail.com',    fullName: 'Timothy Olodude',     offices: ['treasurer', 'director_logistics'] },
  { email: 'peterscaleb50@gmail.com',    fullName: 'Caleb Peters',        offices: ['secretary', 'communication_director'] },
  { email: 'jamespat84@gmail.com',       fullName: 'Nwoko Patience Mfon', offices: ['executive_president'] },
  { email: 'praiseelechi@gmail.com',     fullName: 'Emenike Ekechi',      offices: ['director_evangelism', 'director_programming', 'director_health'] },
  { email: 'deovolente52@gmail.com',     fullName: 'Godstime Esuku',      offices: ['speaker', 'director_amtc'] },
];

// The board chair is Jerry Kwarba in `org_structure.dart`. The seed wrote a
// different name into these rows, which the About page and the roster would
// both have shown.
const CHAIR_FIX = { officeIds: ['board_of_trustees'], fullName: 'Jerry Kwarba' };

const users = [];
for (let offset = 0; offset < 1000; offset += 100) {
  const r = await get(`/users?limit=100&offset=${offset}`);
  if (r.status !== 200) break;
  users.push(...(r.j.users || []));
  if (users.length >= (r.j.total ?? users.length) || (r.j.users || []).length === 0) break;
}
const byEmail = new Map(users.map((u) => [String(u.email || '').toLowerCase(), u]));
console.log(`accounts: ${users.length}   mode: ${APPLY ? 'APPLY' : 'report only'}\n`);

const holdersRes = await get(`/databases/${db}/collections/org_office_holders/documents?limit=200`);
const holders = holdersRes.j.documents || [];
console.log(`org_office_holders: ${holders.length} rows\n`);

// ── chair reconciliation ────────────────────────────────────────────────
for (const officeId of CHAIR_FIX.officeIds) {
  const row = holders.find((h) => h.office_id === officeId);
  if (!row) continue;
  if (row.full_name === CHAIR_FIX.fullName) {
    console.log(`  = ${officeId} chair already "${CHAIR_FIX.fullName}"`);
    continue;
  }
  const was = row.full_name;
  if (!APPLY) {
    console.log(`  would set ${officeId} chair "${was}" -> "${CHAIR_FIX.fullName}"`);
    continue;
  }
  const res = await patch(row.$id, { full_name: CHAIR_FIX.fullName });
  console.log(
    `  * ${officeId} chair "${was}" -> "${CHAIR_FIX.fullName}"  (HTTP ${res.status})`,
  );
}

// ── account binding ─────────────────────────────────────────────────────
console.log('');
let bound = 0;
let skipped = 0;
for (const b of BINDINGS) {
  const user = byEmail.get(b.email);
  if (!user) {
    console.log(`  - ${b.fullName}: no account for ${b.email}; ${b.offices.length} office(s) left unbound`);
    skipped += b.offices.length;
    continue;
  }
  for (const officeId of b.offices) {
    const row = holders.find((h) => h.office_id === officeId);
    if (!row) {
      console.log(`  ! no holder row for ${officeId}`);
      continue;
    }
    if (row.user_id === user.$id) {
      console.log(`  = ${officeId} already bound`);
      continue;
    }
    if (!APPLY) {
      console.log(`  would bind ${officeId} -> ${user.$id} (${b.fullName})`);
      continue;
    }
    const res = await patch(row.$id, {
      user_id: user.$id,
      email: user.email,
      full_name: b.fullName,
    });
    if (res.status >= 200 && res.status < 300) {
      bound++;
      console.log(`  * ${officeId} -> ${user.$id} (${b.fullName})`);
    } else {
      console.log(`  ! ${officeId} -> HTTP ${res.status} ${res.text.slice(0, 100)}`);
    }
  }
}

console.log(`\n${APPLY ? 'Bound' : 'Would bind'} ${bound} office(s); ${skipped} left unbound (no account).`);
if (!APPLY) console.log('Re-run with --apply to write.');
