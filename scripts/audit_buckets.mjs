// Reports every storage bucket's permissions, to check that an upload from the
// admin dashboard or the content manager can actually succeed.
//
// A missing create rule for the admin role is the usual cause, and it is
// invisible until someone tries to upload. This also compares what the app
// expects (the buckets named in appwrite_backend_config.dart) against what
// exists, so a renamed or missing bucket is caught here rather than at runtime.
//
//   node scripts/audit_buckets.mjs
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

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  return { status: r.status, j: await r.json().catch(() => ({})) };
};

// The buckets the app names, with what each is for.
const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
// System Exports and Backups is written by server-side jobs, never by the
// admin UI, so a missing create("users") there is intentional rather than a
// problem. Listing it explicitly stops the audit flagging it every run.
const SERVER_ONLY = new Set(['system_exports']);

// Read is intentionally withheld here: board papers are trustees-only and are
// meant to be served through the access-verification function rather than a
// bucket permission. Reported as a note, not a fault, so the distinction stays
// visible instead of being "fixed" by opening the bucket to every member.
const READ_VIA_FUNCTION = new Set(['board_documents']);

const expected = [
  ['profileFilesBucketId', 'profile pictures'],
  ['boardDocumentsBucketId', 'board documents (trustees only)'],
  ['tractFilesBucketId', 'tracts'],
  ['podcastMediaBucketId', 'podcast audio'],
  ['contentMediaBucketId', 'content media'],
  ['meetingFilesBucketId', 'meeting files'],
  ['systemExportsBucketId', 'system exports'],
].map(([key, purpose]) => {
  const m = cfg.match(new RegExp(`${key}\\s*=\\s*'([^']+)'`));
  return { key, purpose, id: m ? m[1] : null };
});

const res = await get('/storage/buckets?limit=100');
// `get` returns { status, j }, not a Response, so there is no `.ok` to read.
if (res.status >= 300) {
  console.error(`${res.status}: ${JSON.stringify(res.j).slice(0, 300)}`);
  process.exit(1);
}
const buckets = res.j.buckets || [];
console.log(`${buckets.length} bucket(s) exist\n`);

const byId = new Map(buckets.map((b) => [b.$id, b]));

let problems = 0;
for (const e of expected) {
  if (!e.id) {
    console.log(`MISSING CONFIG  ${e.key} is not set in appwrite_backend_config.dart`);
    problems++;
    continue;
  }
  const b = byId.get(e.id);
  if (!b) {
    // The list route can omit a bucket, so probe it directly before failing.
    const probe = await get(`/storage/buckets/${e.id}`);
    if (probe.status === 404) {
      console.log(`MISSING BUCKET  ${e.id.padEnd(20)} (${e.purpose})`);
      problems++;
      continue;
    }
  }
  const bucket = b ?? (await get(`/storage/buckets/${e.id}`)).j;
  const perms = bucket.$permissions ?? bucket.permissions ?? [];
  const hasCreate = perms.some((p) => p.startsWith('create('));
  const hasReadAny = perms.some((p) => p === 'read("any")');
  const hasReadUsers = perms.some((p) => /^read\("users"\)$/.test(p));
  const hasDelete = perms.some((p) => p.startsWith('delete('));

  const flags = [];
  // Notes are deliberate design decisions, reported so they stay visible but
  // not counted as faults.
  const notes = [];
  if (SERVER_ONLY.has(e.id)) {
    notes.push('server-side only, by design -- not uploaded from the admin UI');
  } else {
    if (!hasCreate) flags.push('NO create() -- uploads from admin/content manager will fail');
    if (!hasDelete) flags.push('no delete() -- old files cannot be removed');
  }
  // Read is checked for every bucket, including board_documents, because a
  // trustees-only document that nobody can fetch is a dead end. board_documents
  // is meant to be served through the access function rather than the bucket.
  if (!hasReadAny && !hasReadUsers && !SERVER_ONLY.has(e.id)) {
    if (READ_VIA_FUNCTION.has(e.id)) {
      notes.push('read is restricted on purpose -- trustees-only, served by the access function');
    } else {
      flags.push('not readable by members');
      problems++;
    }
  }

  console.log(`${e.id.padEnd(20)} ${e.purpose}`);
  console.log(`  name:         ${bucket.name}`);
  console.log(`  fileSecurity: ${bucket.fileSecurity}  enabled: ${bucket.enabled}`);
  console.log(`  permissions:  ${perms.length ? perms.join('  ') : '(server only)'}`);
  for (const n of notes) console.log(`  -- ${n}`);
  if (flags.length) {
    for (const f of flags) console.log(`  !! ${f}`);
    problems++;
  } else {
    console.log('  ok');
  }
  console.log('');
}

console.log(problems === 0 ? 'All buckets are upload-ready.' : `${problems} bucket issue(s) found.`);
process.exit(problems === 0 ? 0 : 1);
