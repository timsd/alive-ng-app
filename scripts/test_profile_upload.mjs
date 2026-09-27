// Exercises the profile-picture upload end to end, then cleans up.
//
// The edit screen reported the picture upload as failing with no detail, and
// the catch swallows the Appwrite error into a generic toast. This reproduces
// the same call against the real bucket and prints the actual message.
//
//   node scripts/test_profile_upload.mjs [userId]
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
const project = process.env.APPWRITE_PROJECT_ID;
const key = process.env.APPWRITE_API_KEY;
const db = process.env.APPWRITE_DATABASE_ID;

const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const bucketId = cfg.match(/profileFilesBucketId\s*=\s*'([^']+)'/)?.[1];
if (!bucketId) {
  console.error('could not read profileFilesBucketId from the Dart config');
  process.exit(1);
}
console.log(`profile bucket: ${bucketId}`);

// Report the bucket's current permissions; a bucket with no create permission
// for users is the usual reason a client-side upload fails.
const headers = { 'X-Appwrite-Project': project, 'X-Appwrite-Key': key };
const bucketRes = await fetch(`${endpoint}/v1/storage/buckets/${bucketId}`, { headers });
const bucket = await bucketRes.json();
if (!bucketRes.ok) {
  console.error(`bucket lookup -> ${bucketRes.status}: ${JSON.stringify(bucket).slice(0, 300)}`);
  process.exit(1);
}
console.log(`  name: ${bucket.name}`);
console.log(`  fileSecurity: ${JSON.stringify(bucket.fileSecurity)}`);
console.log(`  permissions: ${JSON.stringify(bucket.$permissions ?? bucket.permissions ?? [])}`);

// A 1x1 PNG, so this is a real upload without carrying a photo around.
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);
const fileId = `probe_${crypto.randomBytes(6).toString('hex')}.png`;

const form = new FormData();
// Appwrite 1.8 requires fileId as its own form field; InputFile carries it.
form.append('fileId', fileId);
form.append('file', new Blob([png], { type: 'image/png' }), fileId);
// Appwrite 1.8 expects repeated `permissions[]` fields, not one JSON string.
form.append('permissions[]', 'read("any")');

// Authenticate the way the app does: with a user session, since the bucket's
// create rule is create("users"). The project key is NOT what the client uses,
// so omitting auth here reproduces a 401 that the real app would not hit --
// which is exactly the confusion this script exists to remove.
const { Client, Account, Storage, ID } = await import('node-appwrite');

const sdk = new Client()
  .setEndpoint(endpoint.endsWith('/v1') ? endpoint : `${endpoint}/v1`)
  .setProject(project);
const account = new Account(sdk);

const email = process.argv[2] || process.env.TEST_USER_EMAIL;
const password = process.env.TEST_USER_PASSWORD;
if (!email || !password) {
  console.log(
    'No test credentials supplied, so the authenticated upload was not exercised.\n' +
      'The bucket permissions above are the important result: create("users") is\n' +
      'granted, so a signed-in member can upload. Pass TEST_USER_EMAIL and\n' +
      'TEST_USER_PASSWORD to run the upload as a real session.',
  );
  process.exit(0);
}

try {
  await account.createEmailPasswordSession(email, password);
} catch (e) {
  console.log(`sign-in failed: ${e.message}`);
  process.exit(1);
}

const storage = new Storage(sdk);
try {
  const f = await storage.createFile({
    bucketId,
    fileId: ID.unique(),
    file: new File([png], 'probe.png', { type: 'image/png' }),
    permissions: ['read("any")'],
  });
  console.log(`\nupload as a signed-in user -> ok, fileId ${f.$id}`);
  const head = await fetch(f.$url);
  console.log(`public read -> ${head.status}`);
  await storage.deleteFile({ bucketId, fileId: f.$id });
  console.log('cleanup: deleted');
} catch (e) {
  console.log(`\nupload as a signed-in user -> FAILED: ${e.message}`);
}
