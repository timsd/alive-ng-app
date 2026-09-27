// Proves a profile edit actually persists, by performing the same write the
// edit screen makes and reading it back.
//
// A profile save that reports "Profile updated successfully!" while persisting
// nothing is invisible from the UI, so this checks the row directly. The
// failing behaviour was an empty input becoming null, which copyWith treats as
// "keep the current value" and the profile service drops before the write.
//
//   node scripts/test_profile_save.mjs <userId> <field> <value>
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

const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const usersId = cfg.match(/usersCollectionId\s*=\s*'([^']+)'/)?.[1];

const userId = process.argv[2];
const field = process.argv[3] || 'location';
const value = process.argv[4] ?? 'Lagos';

if (!userId) {
  console.error('usage: node scripts/test_profile_save.mjs <userId> [field] [value]');
  process.exit(1);
}

const get = async () => {
  const r = await fetch(`${endpoint}/v1/databases/${db}/collections/${usersId}/documents/${userId}`, { headers });
  if (!r.ok) throw new Error(`read -> ${r.status}: ${(await r.text()).slice(0, 200)}`);
  return r.json();
};

const before = await get();
console.log(`user ${userId}`);
console.log(`  before: ${field} = ${JSON.stringify(before[field])}`);

// Mirrors userProfileToAppwriteData -> _buildProfileData, which always writes
// updated_at and passes profile fields through put() (nulls dropped).
const payload = { [field]: value, updated_at: new Date().toISOString() };
const patch = await fetch(`${endpoint}/v1/databases/${db}/collections/${usersId}/documents/${userId}`, {
  method: 'PATCH',
  headers,
  body: JSON.stringify({ data: payload }),
});
const patchText = await patch.text();
console.log(`\nwrite ${field}=${JSON.stringify(value)} -> ${patch.status}`);
if (!patch.ok) {
  console.log(`  ${patchText.slice(0, 300)}`);
  process.exit(1);
}

const after = await get();
console.log(`  after:  ${field} = ${JSON.stringify(after[field])}`);
console.log(
  after[field] === value
    ? '\nPASS: the value persisted.'
    : '\nFAIL: the write was accepted but the value did not change.',
);

// Show that an empty string clears, which is what the fixed save path relies on.
if (value !== '') {
  console.log('\nnow clearing it with an empty string (the case that used to no-op)...');
  await fetch(`${endpoint}/v1/databases/${db}/collections/${usersId}/documents/${userId}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ data: { [field]: '', updated_at: new Date().toISOString() } }),
  });
  const cleared = await get();
  console.log(`  after clear: ${field} = ${JSON.stringify(cleared[field])}`);
  console.log(
    cleared[field] === ''
      ? 'PASS: an empty string clears the field.'
      : 'FAIL: an empty string did not clear the field.',
  );
}
