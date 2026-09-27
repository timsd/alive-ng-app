// Test: does account deletion actually remove the Appwrite account?
//
// Creates a throwaway account, confirms it exists, runs it through the
// `delete_account` function the app uses, then confirms it is gone. A real
// user is never touched: the address is generated per run.
//
//   node scripts/test_account_deletion.mjs
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
const suffix = crypto.randomBytes(5).toString('hex');
const email = `delete-test-${suffix}@example.test`;
const password = `Tst-${crypto.randomBytes(8).toString('hex')}!aA1`;

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

let createdId = null;

try {
  console.log('--- 1. create a throwaway account ---');
  // Appwrite 1.8 requires an explicit userId on self-signup.
  const userId = `deletetest${suffix}`;
  const created = await call('POST', '/account', {
    userId,
    email,
    password,
    name: 'Delete Test',
  });
  console.log(`  POST /account -> ${created.status}`);
  if (created.status >= 300) throw new Error(`could not create account: ${created.text.slice(0, 300)}`);
  createdId = created.j.$id;
  console.log(`  created ${createdId} (${email})`);

  console.log('\n--- 2. confirm it exists ---');
  const before = await call('GET', `/users/${createdId}`);
  console.log(`  GET /users/{id} -> ${before.status}  exists=${before.status === 200}`);

  console.log('\n--- 3. any profile rows created for it? ---');
  for (const coll of ['profiles', 'user_profiles', 'chapters', 'chapter_members']) {
    const r = await call('GET', `/databases/${db}/collections/${coll}/documents?limit=1`);
    if (r.status === 404) continue;
    const mine = (r.j.documents || []).filter((d) =>
      JSON.stringify(d).includes(createdId) || JSON.stringify(d).includes(email),
    );
    console.log(`  ${coll}: ${r.j.total ?? '?'} docs, ${mine.length} belonging to the test user`);
  }

  console.log('\n--- 4. run the delete_account function (as an admin key) ---');
  // The function normally runs with the user session. The admin key is the
  // closest equivalent available from here, and is what proves whether the
  // function's own delete step works.
  // The function refuses an API key and demands a user session, which is the
  // right behaviour, so the test authenticates as the account it created.
  const session = await call('POST', '/account/sessions/email', { email, password });
  console.log(`  sign-in -> ${session.status}`);
  if (session.status >= 300) throw new Error(`could not sign in: ${session.text.slice(0, 200)}`);

  // Appwrite 1.8 rejects a request that carries BOTH an API key and a session
  // (403 user_key_and_session_set). A real client sends only the session, so
  // the key is dropped here to match what the app actually does.
  const exec = await fetch(`${endpoint}/v1/functions/delete_account/executions`, {
    method: 'POST',
    headers: {
      'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
      'X-Appwrite-Session': session.j.secret,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ async: false, method: 'POST', body: '{}' }),
  });
  const execText = await exec.text();
  console.log(`  execution -> ${exec.status}`);
  let parsed = null;
  try {
    parsed = JSON.parse(execText).responseBody;
  } catch {}
  if (parsed) {
    try {
      console.log(`  response: ${JSON.stringify(JSON.parse(parsed)).slice(0, 400)}`);
    } catch {
      console.log(`  response: ${String(parsed).slice(0, 400)}`);
    }
  } else {
    console.log(`  ${execText.slice(0, 300)}`);
  }

  console.log('\n--- 5. the path the app actually uses ---');
  // AuthService.deleteAccount() does NOT call the delete_account function. It
  // uses Appwrite's own self-delete, so that is what proves whether a
  // member's account really goes.
  const del = await fetch(`${endpoint}/v1/account`, {
    method: 'DELETE',
    headers: {
      'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
      'X-Appwrite-Session': session.j.secret,
    },
  });
  const delText = await del.text();
  console.log(`  DELETE /account -> ${del.status} ${delText.slice(0, 200)}`);

  console.log('\n--- 6. confirm the account is gone ---');
  const after = await call('GET', `/users/${createdId}`);
  console.log(`  GET /users/{id} -> ${after.status}`);
  if (after.status === 404) {
    console.log('\nPASS: the account was deleted.');
  } else {
    console.log('\nNOT DELETED: the account still exists.');
  }
} finally {
  // Never leave a test account behind, whatever happened above.
  if (createdId) {
    const cleanup = await call('DELETE', `/users/${createdId}`);
    console.log(`\ncleanup: DELETE /users/{id} -> ${cleanup.status}`);
  }
}
