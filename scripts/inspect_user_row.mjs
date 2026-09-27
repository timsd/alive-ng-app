// Dumps one row from the users table, to check what a profile edit actually
// wrote. A profile save that reports success but persists nothing shows up here
// as unchanged values.
//
//   node scripts/inspect_user_row.mjs <userId|email>
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

const arg = process.argv[2];
if (!arg) {
  console.error('usage: node scripts/inspect_user_row.mjs <userId|email>');
  process.exit(1);
}

// The users table's collection id is a generated Appwrite id, not the literal
// string "users", so read it from the Dart config rather than guessing.
const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const usersCollectionId = cfg.match(/usersCollectionId\s*=\s*'([^']+)'/)?.[1];
if (!usersCollectionId) {
  console.error('could not read usersCollectionId from appwrite_backend_config.dart');
  process.exit(1);
}

const list = await fetch(
  `${endpoint}/v1/databases/${db}/collections/${usersCollectionId}/documents?limit=100`,
  { headers },
);
const lj = await list.json();
if (!list.ok) {
  console.error(`${list.status}: ${JSON.stringify(lj).slice(0, 300)}`);
  process.exit(1);
}

const docs = lj.documents || [];
const row = docs.find((d) => d.$id === arg)
  || docs.find((d) => String(d.email || '').toLowerCase() === arg.toLowerCase());

if (!row) {
  console.log(`no matching row. users table has ${docs.length} row(s):`);
  for (const d of docs.slice(0, 15)) console.log(`  ${d.$id}  ${d.email}`);
  process.exit(1);
}

console.log(`row ${row.$id}  (${row.email})`);
console.log(`$updatedAt: ${row.$updatedAt}\n`);
console.log('fields:');
for (const [k, v] of Object.entries(row)) {
  if (k.startsWith('$') && k !== '$id' && k !== '$createdAt' && k !== '$updatedAt') continue;
  const s = typeof v === 'object' ? JSON.stringify(v) : String(v);
  console.log(`  ${k.padEnd(24)} ${s.length > 100 ? `${s.slice(0, 100)}...` : s}`);
}
