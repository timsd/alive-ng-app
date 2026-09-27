// Proves the office binding works: signs up with a queued officer's address,
// then checks that the office was attached to the new account and the registry
// row retired.
//
//   node scripts/test_office_binding.mjs [email]
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
const call = async (method, p, body) => {
  const res = await fetch(`${endpoint}/v1${p}`, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const t = await res.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  return { status: res.status, j, t };
};

// A queued officer's address, so this is a real test of the real path.
const email = (process.argv[2] || 'deovolente52@gmail.com').toLowerCase();
const userId = `bindtest${crypto.randomBytes(4).toString('hex')}`;
const password = `Tst-${crypto.randomBytes(8).toString('hex')}!aA1`;

const queue = await call(
  'GET',
  `/databases/${db}/collections/officer_registry/documents?limit=200`,
);
const pending = (queue.j.documents || []).filter(
  (d) => String(d.email || '').toLowerCase() === email && !d.consumed,
);
console.log(`registry rows pending for ${email}: ${pending.length}`);
for (const p of pending) console.log(`  ${p.office_id} (consumed=${p.consumed})`);
if (!pending.length) {
  console.log('\nnothing queued for this address, so there is nothing to prove.');
  process.exit(0);
}

let createdId = null;
try {
  console.log(`\nsigning up as ${email} (userId ${userId})...`);
  const created = await call('POST', '/account', { userId, email, password, name: 'Binding Test' });
  console.log(`  POST /account -> ${created.status}`);
  if (created.status >= 300) throw new Error(created.t.slice(0, 200));
  createdId = created.j.$id;

  // The function is event-driven, so give it a moment to run.
  for (let i = 0; i < 12; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const holders = await call(
      'GET',
      `/databases/${db}/collections/org_office_holders/documents?limit=200`,
    );
    const bound = (holders.j.documents || []).filter((h) => h.user_id === createdId);
    if (bound.length) {
      console.log(`\nBOUND after ${(i + 1) * 5}s:`);
      for (const b of bound) console.log(`  ${b.office_id}  name=${b.full_name}  bound_by=${b.bound_by}`);
      const after = await call(
        'GET',
        `/databases/${db}/collections/officer_registry/documents?limit=200`,
      );
      const stillPending = (after.j.documents || []).filter(
        (d) => String(d.email || '').toLowerCase() === email && !d.consumed,
      );
      console.log(`\n  registry rows still pending: ${stillPending.length} (expect 0)`);
      console.log(
        stillPending.length === 0
          ? '\nPASS: the office was bound and the row retired.'
          : '\nPARTIAL: bound, but the queue was not retired.',
      );
      break;
    }
    console.log(`  waiting... ${(i + 1) * 5}s`);
  }
} finally {
  if (createdId) {
    const c = await call('DELETE', `/users/${createdId}`);
    console.log(`\ncleanup: DELETE /users/{id} -> ${c.status}`);
    // Put the queue rows back so the real signup still binds.
    const after = await call('GET', `/databases/${db}/collections/officer_registry/documents?limit=200`);
    for (const d of after.j.documents || []) {
      if (String(d.email || '').toLowerCase() !== email) continue;
      await call('PATCH', `/databases/${db}/collections/officer_registry/documents/${d.$id}`, {
        data: { consumed: false, consumed_by: '', consumed_at: '' },
      });
    }
    console.log('queue rows restored for the real signup');
  }
}

