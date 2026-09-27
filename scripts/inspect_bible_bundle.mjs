// Inspects a Bible bundle: what is inside, and what shape the data is.
//
// The bundles in ~/Documents/bible_bundles are the source for the translations
// missing from assets/bible/bible.db (NLT and HAU have chapters declared in
// bible_versions but zero verses), so the import script needs to know the
// exact layout before it can read them.
//
//   node scripts/inspect_bible_bundle.mjs <bundleZip> [version]
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const zip = process.argv[2];
if (!zip) {
  console.error('usage: node scripts/inspect_bible_bundle.mjs <bundleZip> [version]');
  process.exit(1);
}

const out = join(tmpdir(), `bundle-inspect-${Date.now()}`);
execFileSync('powershell', [
  '-NoProfile',
  '-Command',
  `Expand-Archive -LiteralPath '${zip}' -DestinationPath '${out}' -Force`,
]);

// List what came out.
const list = execFileSync('powershell', [
  '-NoProfile',
  '-Command',
  `Get-ChildItem -Recurse -File '${out}' | Select-Object -ExpandProperty FullName`,
], { encoding: 'utf8' });
console.log(`${zip}\ncontains:`);
for (const line of list.trim().split(/\r?\n/)) console.log(`  ${line}`);

// Find the data file and describe it.
const files = list.trim().split(/\r?\n/).filter(Boolean);
const dataFile = files.find((f) => /\.(json|txt|csv|tsv)$/i.test(f));
if (!dataFile) {
  console.log('\nno data file found');
  process.exit(0);
}

const raw = readFileSync(dataFile, 'utf8');
console.log(`\n${dataFile}: ${raw.length} bytes`);
console.log(`first 400 chars:\n${raw.slice(0, 400)}\n`);

let parsed;
try {
  parsed = JSON.parse(raw);
} catch (e) {
  console.log(`not JSON: ${e.message}`);
  process.exit(0);
}

if (Array.isArray(parsed)) {
  console.log(`JSON array with ${parsed.length} items`);
  console.log(`item shape: ${JSON.stringify(parsed[0], null, 2).slice(0, 600)}`);
  const keys = new Set();
  for (const it of parsed.slice(0, 500)) {
    for (const k of Object.keys(it)) keys.add(k);
  }
  console.log(`keys seen: ${[...keys].join(', ')}`);
  // Which books/chapters does it actually cover?
  const books = new Set();
  const chapters = new Set();
  for (const it of parsed) {
    if (it.book) books.add(it.book);
    if (it.chapter != null) chapters.add(`${it.book} ${it.chapter}`);
  }
  console.log(`distinct books: ${books.size}`);
  console.log(`distinct chapters: ${chapters.size}`);
  console.log(`sample books: ${[...books].slice(0, 8).join(', ')}`);
} else if (parsed && typeof parsed === 'object') {
  const keys = Object.keys(parsed);
  console.log(`JSON object with ${keys.length} top-level keys`);
  console.log(`first keys: ${keys.slice(0, 10).join(', ')}`);
  const first = parsed[keys[0]];
  console.log(`value under "${keys[0]}": ${JSON.stringify(first, null, 2).slice(0, 600)}`);
}
