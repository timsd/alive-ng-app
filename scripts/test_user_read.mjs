// Confirms whether the project's API key can read a user record, which is what
// bindOfficeOnSignup needs to turn a users.*.create event's id into an email.
// The function's own key reports "no available server" for users.get, and it is
// worth knowing whether that is the key's scopes or the users service itself.
//
//   node scripts/test_user_read.mjs <userId|email>
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

const arg = process.argv[2];
let userId = arg;

// With no argument, create a throwaway account so there is always something to
// read. That mirrors exactly what the function does moments after a signup.
if (!arg || arg === '--create') {
  const created = await fetch(`${endpoint}/v1/account`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId: `readtest${Math.random().toString(36).slice(2, 10)}`,
      email: `readtest${Date.now()}@example.com`,
      password: 'Tst-readonly-1aA1!',
      name: 'Read Test',
    }),
  });
  const cj = await created.json();
  if (!created.ok) {
    console.log(`create failed: ${created.status} ${JSON.stringify(cj).slice(0, 300)}`);
    process.exit(1);
  }
  userId = cj.$id;
  console.log(`created throwaway user ${userId} (${cj.email})`);
} else if (!arg.startsWith('user')) {
  // Treat anything else as an email and resolve it to an id first.
  const list = await fetch(`${endpoint}/v1/users?limit=100`, { headers });
  const lj = await list.json();
  const found = (lj.users || []).find(
    (u) => String(u.email || '').toLowerCase() === arg.toLowerCase(),
  );
  if (!found) {
    console.log(`no user with email ${arg}`);
    process.exit(1);
  }
  userId = found.$id;
}
console.log(`target: ${userId}`);

const res = await fetch(`${endpoint}/v1/users/${userId}`, { headers });
const t = await res.text();
console.log(`GET /users/{id} -> ${res.status}`);
if (!res.ok) {
  console.log(t.slice(0, 500));
} else {
  const u = JSON.parse(t);
  console.log(`  email: ${u.email}`);
  console.log(`  name:  ${u.name}`);
}
