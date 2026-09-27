// Audits the database against the app: does every collection the code
// references exist, is it reachable, does it have a document-security level
// that lets members read/write, and which ones are still empty.
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';

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

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  const t = await r.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  return { status: r.status, j };
};

// Every collection id the Dart config points at.
const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const referenced = new Set(
  [...cfg.matchAll(/CollectionId\s*=\s*'([^']+)'/g)].map((m) => m[1]),
);
// Collections named in code but not in the config (e.g. hard-coded elsewhere).
const codeFiles = [];
(function walk(d) {
  for (const e of readdirSync(d)) {
    const f = join(d, e);
    if (statSync(f).isDirectory()) walk(f);
    else if (e.endsWith('.dart')) codeFiles.push(f);
  }
})('lib');
for (const f of codeFiles) {
  const s = readFileSync(f, 'utf8');
  for (const m of s.matchAll(/collectionId:\s*'([a-z][a-z0-9_]{3,})'/gi)) {
    referenced.add(m[1]);
  }
}

const list = await get(`/databases/${db}/collections?limit=1000`);
const cols = list.j.collections || [];
const byId = new Map(cols.map((c) => [c.$id, c]));
console.log(`collections present: ${cols.length} (server total ${list.j.total})`);
console.log(`collection ids referenced by the app: ${referenced.size}\n`);

const missing = [];
const rows = [];
for (const id of referenced) {
  const c = byId.get(id);
  if (!c) {
    // Probe directly: the list endpoint has been observed to ignore `offset`.
    const probe = await get(`/databases/${db}/collections/${id}/documents?limit=1`);
    if (probe.status === 404) missing.push(id);
    else {
      const d = await get(`/databases/${db}/collections/${id}/documents?limit=1`);
      rows.push({ id, n: d.j.total ?? 0, sec: '?', missingFromList: true });
    }
    continue;
  }
  const d = await get(`/databases/${db}/collections/${id}/documents?limit=1`);
  rows.push({
    id,
    n: d.j.total ?? 0,
    sec: c.documentSecurity,
    enabled: c.enabled,
    perms: c.$permissions ?? c.permissions ?? [],
  });
}

rows.sort((a, b) => a.id.localeCompare(b.id));
console.log('id'.padEnd(36) + 'docs'.padStart(7) + '  security      client perms');
for (const r of rows) {
  const perms = Array.isArray(r.perms) && r.perms.length ? r.perms.join(' ') : '(server only)';
  console.log(
    r.id.padEnd(36) +
      String(r.n).padStart(7) +
      `  ${String(r.sec ?? '?').padEnd(12)}  ${perms.slice(0, 60)}`,
  );
}

console.log(`\nMISSING (probed directly): ${missing.length}`);
for (const m of missing) console.log(`  ${m}`);

const empty = rows.filter((r) => r.n === 0);
console.log(`\nempty collections: ${empty.length} of ${rows.length}`);
for (const e of empty) console.log(`  ${e.id}`);
