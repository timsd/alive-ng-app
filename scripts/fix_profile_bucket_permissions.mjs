// Grants the profile-pictures bucket the permissions a signed-in member needs.
//
// Every bucket in the project was provisioned with an EMPTY permission list,
// so no client can create or read a file in any of them. That is why choosing
// a new profile picture silently failed: the upload request was rejected by
// the bucket before the per-file public-read permission was ever considered.
//
// Scoped deliberately to `profile_files`. The other eight buckets (board
// documents, tracts, podcasts, meetings) are left untouched, because
// blanket-opening them would expose trustee and board material -- the exact
// risk the leadership privacy work was meant to avoid. Each needs its own
// decision about who may read it.
//
//   node scripts/fix_profile_bucket_permissions.mjs
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

const BUCKET = 'profile_files';
const WANTED = ['read("any")', 'create("users")', 'update("users")', 'delete("users")'];

const before = await (await fetch(`${endpoint}/v1/storage/buckets/${BUCKET}`, { headers })).json();
console.log(`before: permissions=${JSON.stringify(before.permissions)}`);

const res = await fetch(`${endpoint}/v1/storage/buckets/${BUCKET}`, {
  method: 'PUT',
  headers,
  body: JSON.stringify({
    name: 'profile_files',
    permissions: WANTED,
    enabled: true,
    fileSecurity: false,
    allowedFileExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    maximumFileSize: 5 * 1024 * 1024,
  }),
});
console.log(`PUT -> ${res.status}`);

const after = await (await fetch(`${endpoint}/v1/storage/buckets/${BUCKET}`, { headers })).json();
console.log(`after:  permissions=${JSON.stringify(after.permissions)}`);
console.log(`        maxSize=${after.maximumFileSize}  ext=${JSON.stringify(after.allowedFileExtensions)}`);
const ok = WANTED.every((p) => (after.permissions || []).includes(p));
console.log(
  ok
    ? '\nOK: a signed-in member can now upload and view a profile picture.'
    : '\nFAILED: permissions did not stick.',
);
