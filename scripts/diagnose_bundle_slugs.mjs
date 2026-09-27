// Reports how a bundle's book slugs resolve against the database's book names.
//
// Written because the HAU import produced zero chapters and the interleaved
// console output made it impossible to see why. It separates the three
// possible failures: the slug does not match a database book, the chapter file
// is unreadable, or the file parsed but held no verses.
//
//   node scripts/diagnose_bundle_slugs.mjs <bundleZip>
import { readFileSync, readdirSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const zip = process.argv[2];
if (!zip) {
  console.error('usage: node scripts/diagnose_bundle_slugs.mjs <bundleZip>');
  process.exit(1);
}

const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });
const books = db.prepare('select distinct book from bible_chapters').all().map((r) => r.book);
const byLower = new Map(books.map((b) => [b.toLowerCase(), b]));

const work = join(tmpdir(), `diag-${Date.now()}`);
execFileSync('powershell', [
  '-NoProfile', '-Command',
  `Expand-Archive -LiteralPath '${zip}' -DestinationPath '${work}' -Force`,
], { stdio: 'ignore' });

const slugToTitle = (slug) =>
  slug.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

const files = readdirSync(work).filter((f) => f.endsWith('.json'));
console.log(`${zip}: ${files.length} json files`);

const resolved = new Map();
const unresolved = new Map();
let emptyVerses = 0;
let unparsed = 0;

for (const f of files) {
  const m = /^([a-z0-9_]+?)_(\d+)\.json$/i.exec(f);
  if (!m) continue;
  const slug = m[1];
  const title = slugToTitle(slug);
  const book = byLower.get(title.toLowerCase());
  if (!book) {
    unresolved.set(slug, (unresolved.get(slug) ?? 0) + 1);
    continue;
  }
  let data;
  try {
    data = JSON.parse(readFileSync(join(work, f), 'utf8'));
  } catch {
    unparsed++;
    continue;
  }
  const list = Array.isArray(data) ? data : (data.verses ?? null);
  if (!Array.isArray(list) || !list.length) {
    emptyVerses++;
    continue;
  }
  resolved.set(book, (resolved.get(book) ?? 0) + list.length);
}

console.log(`resolved books: ${resolved.size}  chapters/verses total: ${[...resolved.values()].reduce((a, b) => a + b, 0)}`);
console.log(`unresolved slugs: ${unresolved.size} (covering ${[...unresolved.values()].reduce((a, b) => a + b, 0)} files)`);
console.log(`files with no verses: ${emptyVerses}, unparsed: ${unparsed}`);

if (unresolved.size) {
  console.log('\nunresolved slugs (and the title they produce):');
  for (const [slug, n] of [...unresolved.entries()].sort()) {
    console.log(`  ${slug.padEnd(24)} -> "${slugToTitle(slug)}"  (${n} chapters)`);
  }
}

console.log('\nfirst 10 resolved books:');
for (const [book, verses] of [...resolved.entries()].slice(0, 10)) {
  console.log(`  ${book.padEnd(24)} ${verses} verses`);
}

rmSync(work, { recursive: true, force: true });
