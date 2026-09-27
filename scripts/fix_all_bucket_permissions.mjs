// Gives every storage bucket the permissions its content actually needs.
//
// All nine buckets were provisioned with an empty permission list, so no client
// could create or read a file in any of them: profile pictures failed to
// upload, and tract, podcast and media downloads could not be served.
//
// Access is decided per bucket by what the content is, not applied wholesale:
//
//   read("any")    public to the internet -- only for things already public
//                  (podcast audio, page imagery, release binaries)
//   read("users")  any signed-in member -- ministry material, but not public
//   (none)         server-side only -- board papers, financial exports, which
//                  must never be readable by a client at all
//
// Board documents and exports are deliberately left with NO client access.
// Appwrite bucket permissions cannot express "leaders only", so the honest
// options are server-only (chosen here) or wide open. Wide open would publish
// trustee and financial material, which is the opposite of the leadership
// privacy work. Serving them needs a function that checks the caller's office.
//
//   node scripts/fix_all_bucket_permissions.mjs          (report)
//   node scripts/fix_all_bucket_permissions.mjs --apply  (write)
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
const APPLY = process.argv.includes('--apply');

const READ_PUBLIC = ['read("any")', 'create("users")', 'update("users")', 'delete("users")'];
const READ_MEMBERS = ['read("users")', 'create("users")', 'update("users")', 'delete("users")'];
const SERVER_ONLY = [];

// uid, the permissions it should have, and why.
const PLAN = {
  profile_files: [READ_PUBLIC, 'A member picture. Viewable wherever it is shown; only the owner can change it.'],
  '6a08f51f002d2baf5e78': [READ_MEMBERS, 'Legacy default bucket, still referenced by config. Signed-in members only.'],
  content_media: [READ_PUBLIC, 'Imagery for content pages, which are public.'],
  podcast_media: [READ_PUBLIC, 'Episode audio, played straight in the browser.'],
  tract_files: [READ_MEMBERS, 'Tracts are ministry material, not for anonymous download.'],
  meeting_files: [READ_MEMBERS, 'Meeting uploads, for members in a call.'],
  app_releases: [['read("any")'], 'APKs for the published builds. Read-only, uploaded server-side.'],
  board_documents: [SERVER_ONLY, 'Board papers incl. trustee material. No client access at all.'],
  system_exports: [SERVER_ONLY, 'Financial and data exports. Never client-readable.'],
};

const list = await (await fetch(`${endpoint}/v1/storage/buckets?limit=100`, { headers })).json();
const buckets = list.buckets || [];
console.log(`mode: ${APPLY ? 'APPLY' : 'report only'}   buckets: ${buckets.length}\n`);

let changed = 0;
for (const b of buckets) {
  const plan = PLAN[b.$id];
  // Appwrite 1.8 returns the list under $permissions.
  const current = b.$permissions ?? b.permissions ?? [];
  if (!plan) {
    console.log(`  ? ${b.$id}  not in the plan; leaving alone (current: ${JSON.stringify(current)})`);
    continue;
  }
  const [wanted, why] = plan;
  const same = wanted.length === current.length && wanted.every((p) => current.includes(p));
  if (same) {
    console.log(`  = ${b.$id.padEnd(24)} already correct`);
    continue;
  }
  if (!APPLY) {
    console.log(`  ~ ${b.$id.padEnd(24)} ${JSON.stringify(current)} -> ${JSON.stringify(wanted)}`);
    console.log(`      ${why}`);
    changed++;
    continue;
  }
  const res = await fetch(`${endpoint}/v1/storage/buckets/${b.$id}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      name: b.name,
      permissions: wanted,
      enabled: b.enabled,
      fileSecurity: b.fileSecurity ?? false,
      allowedFileExtensions: b.allowedFileExtensions ?? [],
      maximumFileSize: b.maximumFileSize,
    }),
  });
  console.log(
    `  * ${b.$id.padEnd(24)} HTTP ${res.status}  ${JSON.stringify(wanted)}`,
  );
  changed++;
}

console.log(
  APPLY
    ? `\nApplied to ${changed} bucket(s).`
    : `\n${changed} bucket(s) would change. Re-run with --apply.`,
);
