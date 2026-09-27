// Prints a collection's real attribute schema.
//
// Needed before writing to a collection: an update naming an attribute the
// schema does not have is rejected with 'Unknown attribute', and the error does
// not list the valid names. bindOfficeOnSignup hit this on org_office_holders,
// which has no bound_at/bound_by.
//
//   node scripts/describe_collection.mjs <collectionId>
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
const db = process.env.APPWRITE_DATABASE_ID;

const collectionId = process.argv[2];
if (!collectionId) {
  console.error('usage: node scripts/describe_collection.mjs <collectionId>');
  process.exit(1);
}

const res = await fetch(
  `${endpoint}/v1/databases/${db}/collections/${collectionId}/attributes?limit=200`,
  { headers },
);
const t = await res.text();
if (!res.ok) {
  console.error(`${res.status}: ${t.slice(0, 300)}`);
  process.exit(1);
}
const j = JSON.parse(t);

console.log(`${collectionId}: ${j.total} attribute(s)\n`);
for (const a of j.attributes || []) {
  const extra = [
    a.required ? 'required' : 'optional',
    a.array ? 'array' : null,
    a.default !== undefined && a.default !== null ? `default=${a.default}` : null,
  ]
    .filter(Boolean)
    .join(' ');
  console.log(`  ${String(a.key).padEnd(22)} ${String(a.type).padEnd(12)} ${extra}`);
}

// A sample document shows the shape real rows take.
const docs = await fetch(
  `${endpoint}/v1/databases/${db}/collections/${collectionId}/documents?limit=1`,
  { headers },
);
const dj = await docs.json();
if (dj.documents?.length) {
  const sample = { ...dj.documents[0] };
  for (const k of Object.keys(sample)) {
    if (k.startsWith('$') && !['$id', '$createdAt', '$updatedAt'].includes(k)) delete sample[k];
  }
  console.log(`\nsample document:\n${JSON.stringify(sample, null, 2).slice(0, 800)}`);
}
