// Removes duplicate books from a translation in assets/bible/bible.db.
//
// The Hausa import ran over a bundle that lists four books in Hausa orthography
// (ESTA, HABAKUK, MALAKAI, RUT) while the rest of that same translation uses
// English names. Each of those four therefore exists twice -- once under the
// Hausa name and once under the English one -- so the Hausa reader lists
// Esther, Habakkuk, Malachi and Ruth twice, and a search can return the same
// verse from either row.
//
// The two rows hold identical verse counts, so they are the same data imported
// twice rather than two different translations of a book.
//
// Removes the row whose name is NOT the canonical English one, since the other
// 62 books in this translation are English-named and the reader resolves book
// names against English. Rebuilds the FTS index afterwards, because deleting a
// chapter leaves its verse rows in the search index otherwise.
//
//   node scripts/fix_duplicate_books.mjs          (reports what it would do)
//   node scripts/fix_duplicate_books.mjs --apply  (deletes)
import { DatabaseSync } from 'node:sqlite';
import { copyFileSync, existsSync } from 'node:fs';

const APPLY = process.argv.includes('--apply');

// The Hausa-spelled name -> the English name to keep.
const KEEP = { ESTA: 'Esther', HABAKUK: 'Habakkuk', MALAKAI: 'Malachi', RUT: 'Ruth' };

const db = new DatabaseSync('assets/bible/bible.db');
db.exec('pragma foreign_keys = on');

// For each Hausa-spelled book, compare it against its English-named twin
// chapter by chapter. Only a chapter that exists in both, under the same
// chapter number and with the same number of verses, is a true duplicate.
const removable = [];
const keptReasons = [];

for (const [hausa, english] of Object.entries(KEEP)) {
  const hausaChapters = db.prepare(`
    SELECT c.id, c.chapter, COUNT(v.id) AS verses
    FROM bible_chapters c LEFT JOIN bible_verses v ON v.chapter_id = c.id
    WHERE c.version = 'HAU' AND c.book = ?
    GROUP BY c.id ORDER BY c.chapter`).all(hausa);

  if (!hausaChapters.length) continue;

  for (const hc of hausaChapters) {
    const twin = db.prepare(`
      SELECT c.id, COUNT(v.id) AS verses
      FROM bible_chapters c LEFT JOIN bible_verses v ON v.chapter_id = c.id
      WHERE c.version = 'HAU' AND c.book = ? AND c.chapter = ?
      GROUP BY c.id`).get(english, hc.chapter);

    if (!twin) {
      keptReasons.push(`${hausa} ${hc.chapter}: ${english} has no chapter ${hc.chapter}`);
    } else if (twin.verses !== hc.verses) {
      keptReasons.push(`${hausa} ${hc.chapter}: ${hc.verses} verses vs ${english} ${twin.verses} -- text differs`);
    } else {
      removable.push({ ...hc, book: hausa, english });
    }
  }
}

for (const r of keptReasons) console.log(`keeping ${r}`);
if (keptReasons.length) console.log('');

const books = [...new Set(removable.map((r) => r.book))];
const removableVerses = removable.reduce((a, b) => a + b.verses, 0);
console.log(`${removable.length} chapter rows across ${books.length} book(s) would be deleted: ` +
  `${books.join(', ') || '(none)'} (${removableVerses} verses, all duplicated elsewhere)`);

if (!APPLY) {
  console.log('\nDry run. Re-run with --apply to delete.');
  process.exit(0);
}

if (!removable.length) {
  console.log('Nothing to delete.');
  process.exit(0);
}

if (existsSync('assets/bible/bible.db.bak')) {
  console.log('\nRefusing to run: assets/bible/bible.db.bak already exists. Move it first.');
  process.exit(1);
}
copyFileSync('assets/bible/bible.db', 'assets/bible/bible.db.bak');
console.log('Backed up to assets/bible/bible.db.bak');

// FTS5 'delete-all' cannot run inside a transaction, so the index rebuild is
// done outside it. That means the chapter deletes commit first and the reindex
// is a separate step: if reindexing fails the verses are already gone from the
// tables and the index is simply stale, which is recoverable by re-running.
// Wrapping both in one transaction instead aborts the whole thing on the
// delete-all, which is what this script originally did.
db.exec('begin');
try {
  for (const row of removable) db.prepare('delete from bible_chapters where id = ?').run(row.id);
  db.exec('commit');
  console.log(`Deleted ${removable.length} chapter rows.`);
} catch (e) {
  try { db.exec('rollback'); } catch { /* already rolled back */ }
  console.error('Delete failed, rolled back:', e.message);
  process.exit(1);
}

try {
  db.exec("insert into bible_search(bible_search) values('delete-all')");
  const reindex = db.prepare('insert into bible_search(rowid, text) select id, text from bible_verses');
  reindex.run();
  const indexed = db.prepare('select count(*) AS n from bible_search').get().n;
  const verses = db.prepare('select count(*) AS n from bible_verses').get().n;
  console.log(`Reindexed bible_search: ${indexed} rows (bible_verses has ${verses}).`);
  if (indexed !== verses) {
    console.error('!! Index size does not match verse count. Re-run before deploying.');
    process.exit(1);
  }
} catch (e) {
  console.error('Chapters are deleted but reindexing failed:', e.message);
  console.error('Restore with: copy assets/bible/bible.db.bak assets/bible/bible.db');
  process.exit(1);
}

const after = db.prepare(`
  SELECT COUNT(DISTINCT c.book) AS books, COUNT(*) AS chapters, COUNT(v.id) AS verses
  FROM bible_chapters c LEFT JOIN bible_verses v ON v.chapter_id = c.id
  WHERE c.version = 'HAU'`).get();
console.log(`\nHAU now: ${after.books} books, ${after.chapters} chapters, ${after.verses} verses`);

const orphans = db.prepare(`
  SELECT COUNT(*) AS n FROM bible_verses v
  LEFT JOIN bible_chapters c ON c.id = v.chapter_id WHERE c.id IS NULL`).get();
console.log(`orphan verses: ${orphans.n}`);
console.log('\nRun scripts/audit_translations.mjs to confirm.');
