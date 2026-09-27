// Creates `officer_registry` and seeds it with the officers who still have no
// Appwrite account, so that when they sign up their office is attached
// automatically by the bindOfficeOnSignup function.
//
// The registry is a queue: a row is pending until a signup claims it, then it
// is marked consumed. That is what stops a later account reusing an address
// from inheriting an office.
//
//   node scripts/seed_officer_registry.mjs [--apply]
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import crypto from 'node:crypto';

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
const COLLECTION = 'officer_registry';

const call = async (method, p, body) => {
  const res = await fetch(`${endpoint}/v1${p}`, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await res.text();
  let j = {};
  try { j = JSON.parse(text); } catch {}
  return { status: res.status, j, text };
};

// The officers confirmed by the ministry, and the offices each holds.
const OFFICERS = [
  { email: 'peterscaleb50@gmail.com',    fullName: 'Caleb Peters',        offices: ['secretary', 'communication_director'] },
  { email: 'jamespat84@gmail.com',       fullName: 'Nwoko Patience Mfon', offices: ['executive_president'] },
  { email: 'praiseelechi@gmail.com',     fullName: 'Emenike Ekechi',      offices: ['director_evangelism', 'director_programming', 'director_health'] },
  { email: 'deovolente52@gmail.com',     fullName: 'Godstime Esuku',      offices: ['speaker', 'director_amtc'] },
];

console.log(`mode: ${APPLY ? 'APPLY' : 'report only'}\n`);

// ── 1. the collection ───────────────────────────────────────────────────
const exists = await call('GET', `/databases/${db}/collections/${COLLECTION}`);
if (exists.status === 404) {
  if (!APPLY) {
    console.log(`collection ${COLLECTION} does not exist yet (would be created)`);
  } else {
    const created = await call('POST', `/databases/${db}/collections`, {
      collectionId: COLLECTION,
      name: 'Officer registry',
      permissions: [],          // server-only: never client readable
      documentSecurity: false,
      enabled: true,
    });
    console.log(`create ${COLLECTION} -> ${created.status}`);
    if (created.status >= 300) throw new Error(created.text.slice(0, 300));

    for (const col of [
      { key: 'email', size: 190, required: true },
      { key: 'full_name', size: 128, required: true },
      { key: 'office_id', size: 64, required: true },
      { key: 'consumed_by', size: 64, required: false },
      { key: 'consumed_at', size: 64, required: false },
    ]) {
      const r = await call(
        'POST',
        `/databases/${db}/collections/${COLLECTION}/attributes/string`,
        { key: col.key, size: col.size, required: col.required, xss: false, encrypt: false },
      );
      console.log(`  + ${col.key} -> ${r.status}`);
    }
    // A boolean, so a pending row is queryable as consumed == false.
    const r = await call(
      'POST',
      `/databases/${db}/collections/${COLLECTION}/attributes/boolean`,
      { key: 'consumed', required: false, default: false },
    );
    console.log(`  + consumed -> ${r.status}`);
  }
} else {
  console.log(`collection ${COLLECTION} exists (HTTP ${exists.status})`);
}

// ── 2. who already has an account (nothing to queue for them) ──────────
const usersRes = await call('GET', '/users?limit=100');
const accounts = new Set(
  (usersRes.j.users || []).map((u) => String(u.email || '').toLowerCase()),
);

// ── 3. the rows ─────────────────────────────────────────────────────────
const existingRes = await call('GET', `/databases/${db}/collections/${COLLECTION}/documents?limit=200`);
const existing = (existingRes.j.documents || []).filter(Boolean);

let queued = 0;
for (const officer of OFFICERS) {
  const email = officer.email.toLowerCase();
  if (accounts.has(email)) {
    console.log(`  - ${officer.fullName}: already has an account; not queued`);
    continue;
  }
  for (const officeId of officer.offices) {
    const already = existing.some(
      (d) => String(d.email || '').toLowerCase() === email && d.office_id === officeId,
    );
    if (already) continue;
    if (!APPLY) {
      console.log(`  ~ queue ${officer.fullName} (${email}) -> ${officeId}`);
      queued++;
      continue;
    }
    // Appwrite 1.8 requires a documentId on create and caps it at 36 chars,
    // which `office_<office>_<email>` easily exceeds. A short deterministic id
    // derived from the email and office keeps re-runs idempotent.
    const digest = crypto
      .createHash('sha256')
      .update(`${email}|${officeId}`)
      .digest('hex')
      .slice(0, 20);
    const r = await call('POST', `/databases/${db}/collections/${COLLECTION}/documents`, {
      documentId: `off_${digest}`,
      data: { email, full_name: officer.fullName, office_id: officeId, consumed: false },
    });
    console.log(`  * queue ${officeId} for ${email} -> ${r.status}`);
    if (r.status >= 300) console.log(`      ${r.text.slice(0, 200)}`);
    if (r.status < 300) queued++;
  }
}

console.log(APPLY ? `\nSeeded. ${queued} pending row(s).` : `\n${queued} row(s) would be queued. Re-run with --apply.`);
