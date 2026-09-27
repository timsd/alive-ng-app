// Grants write access on a bucket that is currently server-only.
//
// board_documents is deliberately not readable by members -- board papers are
// trustees-only, and the read path is meant to go through the access function
// rather than a public bucket permission. But admin uploads go through the
// user's own session (Storage.createFile), not an API key, so with no
// create("users") rule every upload failed with a 401 that the admin screen
// flattened into a generic message.
//
// So this adds the write rules only and deliberately leaves read alone.
//
//   node scripts/grant_bucket_write.mjs <bucketId> [--read]
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

const bucketId = process.argv[2];
if (!bucketId) {
  console.error('usage: node scripts/grant_bucket_write.mjs <bucketId> [--read]');
  process.exit(1);
}
const alsoRead = process.argv.includes('--read');

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  return { status: r.status, j: await r.json().catch(() => ({})) };
};

const before = await get(`/storage/buckets/${bucketId}`);
if (before.status >= 300) {
  console.error(`${before.status}: ${JSON.stringify(before.j).slice(0, 300)}`);
  process.exit(1);
}

const current = before.j.$permissions ?? before.j.permissions ?? [];
console.log(`${bucketId} (${before.j.name})`);
console.log(`  before: ${current.length ? current.join('  ') : '(server only)'}`);

const wanted = ['create("users")', 'update("users")', 'delete("users")'];
if (alsoRead) wanted.unshift('read("users")');

const next = [...current];
for (const p of wanted) {
  if (!next.includes(p)) next.push(p);
}

if (next.length === current.length) {
  console.log('  already correct; nothing to change');
  process.exit(0);
}

const upd = await fetch(`${endpoint}/v1/storage/buckets/${bucketId}`, {
  method: 'PUT',
  headers,
  body: JSON.stringify({
    name: before.j.name,
    enabled: before.j.enabled ?? true,
    fileSecurity: before.j.fileSecurity ?? false,
    permissions: next,
    allowedFileExtensions: before.j.allowedFileExtensions ?? [],
    maximumFileSize: before.j.maximumFileSize,
    encryptionKey: before.j.encryptionKey ?? '',
  }),
});
const updText = await upd.text();
console.log(`  PUT -> ${upd.status}`);
if (upd.status >= 300) {
  console.log(`  ${updText.slice(0, 400)}`);
  process.exit(1);
}

const after = await get(`/storage/buckets/${bucketId}`);
const perms = after.j.$permissions ?? after.j.permissions ?? [];
console.log(`  after:  ${perms.join('  ')}`);
if (!alsoRead && !perms.some((p) => p.startsWith('read('))) {
  console.log('  (read intentionally left restricted)');
}
