// Classifies every donation by WHO gave it, so the donor question is answered
// from data rather than from assumption.
//
// There are three ways a gift reaches the app, and they do not leave the same
// trace:
//   1. a signed-in member          -> user_id is a real Appwrite user id
//   2. "continue as guest" (Flutter) -> user_id is 'guest-<uuid>' or 'guest'
//   3. the standalone donation.html -> no account at all; identity lives only in
//                                     donation_records + metadata
//
// A row can therefore be *matched* back to a member by email even when the
// user_id is not one, which is the sync the ministry would want. This reports
// which cases actually occur.
//
//   node scripts/audit_donor_identities.mjs
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
const USERS_TABLE = '6a08943100226f5b4963';

const getJson = async (path) => {
  const res = await fetch(`${endpoint}/v1/${path}`, { headers });
  return { ok: res.ok, status: res.status, j: await res.json().catch(() => ({})) };
};

// Registered accounts, so a donation email can be matched to one.
const usersRes = await getJson(`tablesdb/${dbId}/tables/${USERS_TABLE}/rows?limit=200`);
const users = usersRes.ok ? (usersRes.j.rows ?? []) : [];
const byId = new Map(users.map((u) => [u.$id, u]));
const byEmail = new Map(
  users.filter((u) => u.email).map((u) => [String(u.email).trim().toLowerCase(), u]),
);
console.log(`${users.length} registered account(s)\n`);

const donRes = await getJson(`tablesdb/${dbId}/tables/donation_records/rows?limit=200`);
if (!donRes.ok) {
  console.log(`ERROR listing donations: ${donRes.status} ${donRes.j.message ?? ''}`);
  process.exit(1);
}
const rows = donRes.j.rows ?? [];
console.log(`${rows.length} donation(s)\n`);

const buckets = { member: [], guestFlutter: [], webUnmatched: [], webMatched: [] };

for (const row of rows) {
  const id = String(row.user_id ?? '');
  const email = String(row.user_email ?? '').trim().toLowerCase();
  const name = String(row.user_name ?? '').trim();
  let meta = {};
  try { meta = JSON.parse(row.metadata || '{}'); } catch { /* not JSON */ }
  const source = meta.source || '(none)';

  const isRealUser = byId.has(id);
  const looksGuest = id === 'guest' || id.startsWith('guest-');
  const matchedMember = email && byEmail.has(email) ? byEmail.get(email) : null;

  let kind;
  if (isRealUser) kind = 'member';
  else if (looksGuest) kind = 'guestFlutter';
  else if (matchedMember) kind = 'webMatched';
  else kind = 'webUnmatched';

  buckets[kind].push({ id, email, name, source, matched: matchedMember?.$id ?? null });
}

const show = (label, list) => {
  console.log(`${label}: ${list.length}`);
  for (const d of list) {
    const m = d.matched ? `  [matches member ${d.matched}]` : '  [no member match]';
    console.log(`   ${String(d.name || '(no name)').padEnd(24)} ${String(d.email || '(no email)').padEnd(32)} src=${d.source}${m}`);
  }
  console.log('');
};

show('Signed-in member (user_id is a real account)', buckets.member);
show('Flutter "continue as guest"', buckets.guestFlutter);
show('Web donor, MATCHED to a member by email', buckets.webMatched);
show('Web donor, NOT a member (identity only in this row)', buckets.webUnmatched);

console.log('Summary');
console.log(`  total                        ${rows.length}`);
console.log(`  traceable to a member        ${buckets.member.length + buckets.webMatched.length}`);
console.log(`  not traceable to a member    ${buckets.guestFlutter.length + buckets.webUnmatched.length}`);
console.log(`  rows with no name            ${rows.filter((r) => !String(r.user_name ?? '').trim()).length}`);
console.log(`  rows with no email           ${rows.filter((r) => !String(r.user_email ?? '').trim()).length}`);

// The raw user_id matters more than the bucket: if a member's own donation is
// stored under 'guest', the row is only linkable by email, which is fragile.
console.log('\nRaw user_id values:');
const idCounts = new Map();
for (const row of rows) {
  const id = String(row.user_id ?? '(blank)');
  idCounts.set(id, (idCounts.get(id) ?? 0) + 1);
}
for (const [id, n] of [...idCounts].sort((a, b) => b[1] - a[1])) {
  const real = byId.has(id);
  const label = real ? 'real account' : (id === 'guest' || id.startsWith('guest-')
    ? 'GUEST placeholder'
    : 'NOT an account id');
  console.log(`  ${String(id).padEnd(38)} x${String(n).padEnd(3)} ${label}`);
}

// Which of the app's own roles exist, to see whether a 'guest' role is real.
console.log('\nRegistered accounts and their roles:');
for (const u of users) {
  console.log(`  ${String(u.email ?? '(no email)').padEnd(32)} role=${String(u.role ?? '(unset)').padEnd(12)} approved=${u.is_approved}`);
}

// A user_id that is not an account id is either a deleted account or, more
// likely, a different object entirely. Name the object so this is diagnosable
// rather than just a wrong-looking hex string.
const odd = [...idCounts.keys()].filter((id) => !byId.has(id));
if (odd.length) {
  console.log('\nWhat are the unmatched user_id values?');
  const tablesRes = await getJson(`tablesdb/${dbId}/tables?limit=200`);
  const tables = tablesRes.ok ? (tablesRes.j.tables ?? []) : [];
  const fnRes = await getJson('functions?limit=200');
  const fns = fnRes.ok ? (fnRes.j.functions ?? []) : [];

  for (const id of odd) {
    const table = tables.find((t) => t.$id === id);
    const fn = fns.find((f) => f.$id === id);
    if (table) console.log(`  ${id} -> TABLE "${table.name}"`);
    else if (fn) console.log(`  ${id} -> FUNCTION "${fn.name}"`);
    else if (id === process.env.APPWRITE_PROJECT_ID) {
      console.log(`  ${id} -> the Appwrite project itself`);
    } else {
      console.log(`  ${id} -> not a table, function or account (deleted account?)`);
    }
  }
}

