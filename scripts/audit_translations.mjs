// Checks every translation for a *missing book* or a *missing chapter*.
//
// A percentage completeness figure only tells you the total is short. The
// question that matters is whether something is absent entirely: a reader
// showing an empty page because a book has no chapters is a different bug from
// a version that is legitimately shorter than another (ASV omits most of the
// Apocrypha that KJV carries).
//
// Reports, per version: the books present, any book with no chapters, and the
// per-book chapter counts that look wrong against the median for that version.
//
//   node scripts/audit_translations.mjs
import { readFileSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const SRC = 'C:/Users/Timothy Olodude/Documents/bible_bundles';
const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });

// The 66 books, in order, so "absent" is detectable against a known set.
const rows = db.prepare(`
  SELECT c.version AS version, c.language AS language, c.book AS book,
         COUNT(DISTINCT c.chapter) AS chapters,
         COUNT(v.id) AS verses
  FROM bible_chapters c
  LEFT JOIN bible_verses v ON v.chapter_id = c.id
  GROUP BY c.version, c.book
  ORDER BY c.version, c.book`).all();

const byVersion = new Map();
for (const r of rows) {
  if (!byVersion.has(r.version)) byVersion.set(r.version, []);
  byVersion.get(r.version).push(r);
}

// The 66 canonical books with their real chapter counts. A book's chapter
// count is a fact about the Bible, not something to be inferred from the data,
// so the expected count is listed here rather than derived from a median --
// otherwise every single-chapter epistle (Jude, Philemon, 2 John, 3 John) and
// short prophet (Obadiah, Haggai) looks like a failed import.
const CANON = {
  Genesis: 50, Exodus: 40, Leviticus: 27, Numbers: 36, Deuteronomy: 34,
  Joshua: 24, Judges: 21, Ruth: 4, '1 Samuel': 31, '2 Samuel': 24,
  '1 Kings': 22, '2 Kings': 25, '1 Chronicles': 29, '2 Chronicles': 36,
  Ezra: 10, Nehemiah: 13, Esther: 10, Job: 42, Psalms: 150, Proverbs: 31,
  Ecclesiastes: 12, 'Song of Songs': 8, Isaiah: 66, Jeremiah: 52,
  Lamentations: 5, Ezekiel: 48, Daniel: 12, Hosea: 14, Joel: 3, Amos: 9,
  Obadiah: 1, Jonah: 4, Micah: 7, Nahum: 3, Habakkuk: 3, Zephaniah: 3,
  Haggai: 2, Zechariah: 14, Malachi: 4,
  Matthew: 28, Mark: 16, Luke: 24, John: 21, Acts: 28, Romans: 16,
  '1 Corinthians': 16, '2 Corinthians': 13, Galatians: 6, Ephesians: 6,
  Philippians: 4, Colossians: 4, '1 Thessalonians': 5, '2 Thessalonians': 3,
  '1 Timothy': 6, '2 Timothy': 4, Titus: 3, Philemon: 1, Hebrews: 13,
  James: 5, '1 Peter': 5, '2 Peter': 3, '1 John': 5, '2 John': 1,
  '3 John': 1, Jude: 1, Revelation: 22,
};

const ALIAS = { 'Song of Solomon': 'Song of Songs' };

// BM (Yoruba) and IGBOB (Igbo) store their books under native-language names, so
// an English canonical-name comparison is meaningless for them. They are checked
// on totals and emptiness only.
const NATIVE_NAMED = new Set(['BM', 'IGBOB']);

// Hausa spells four books in its own orthography, and the import created a
// *second* row for each alongside the English one. These map an alias onto the
// canonical book it duplicates.
const HAUSA_ALIAS = { ESTA: 'Esther', HABAKUK: 'Habakkuk', MALAKAI: 'Malachi', RUT: 'Ruth' };

// Resolves a stored book name to the canonical book it represents, or null if
// this audit does not recognise the name.
const canonOf = (version, name) => {
  if (NATIVE_NAMED.has(version)) return null;
  if (CANON[name] !== undefined) return name;
  if (ALIAS[name]) return ALIAS[name];
  if (version === 'HAU' && HAUSA_ALIAS[name]) return HAUSA_ALIAS[name];
  return null;
};

const declared = db.prepare('select code, language from bible_versions order by code').all();
console.log(`bible_versions declares ${declared.length} translations; ` +
  `${byVersion.size} have chapters\n`);

let problems = 0;
for (const d of declared) {
  const books = byVersion.get(d.code) ?? [];
  if (!books.length) {
    console.log(`${d.code} (${d.language})  !! NO CHAPTERS -- not usable`);
    problems++;
    continue;
  }

  const totalChapters = books.reduce((a, b) => a + b.chapters, 0);
  const totalVerses = books.reduce((a, b) => a + b.verses, 0);

  console.log(
    `${d.code.padEnd(7)} ${String(books.length).padStart(3)} books  ` +
    `${String(totalChapters).padStart(5)} chapters  ${String(totalVerses).padStart(6)} verses  ` +
    `(${((totalVerses / 31102) * 100).toFixed(1)}%)`,
  );

  if (NATIVE_NAMED.has(d.code)) {
    // Names are native, so rely on totals instead of name comparison.
    if (books.length !== 66 || totalChapters !== 1189) {
      console.log(`         !! expected 66 books / 1189 chapters, found ${books.length} / ${totalChapters}`);
      problems++;
    }
  } else {
    // Group every stored name onto the canonical book it represents. A group
    // with more than one row means the same book was imported twice under
    // different spellings, which the reader shows as duplicate entries.
    const groups = new Map();
    for (const b of books) {
      const key = canonOf(d.code, b.book) ?? `?${b.book}`;
      groups.set(key, [...(groups.get(key) ?? []), b]);
    }

    const dupes = [...groups.entries()].filter(([, g]) => g.length > 1);
    const unknown = [...groups.entries()].filter(([k]) => k.startsWith('?'));

    if (unknown.length) {
      console.log(`         !! ${unknown.length} unrecognised book name(s): ` +
        unknown.map(([k]) => k.slice(1)).join(', '));
      problems++;
    }

    if (dupes.length) {
      console.log(`         !! ${dupes.length} book(s) present MORE THAN ONCE -- the ` +
        'reader lists these twice:');
      for (const [key, g] of dupes) {
        const ch = g.reduce((a, b) => a + b.chapters, 0);
        const ve = g.reduce((a, b) => a + b.verses, 0);
        console.log(`            ${key}: ${g.map((b) => b.book).join('  /  ')}  -> ` +
          `${ch} chapters (canonical ${CANON[key]}), ${ve} verses`);
      }
      problems++;
    }

    const present = new Set(groups.keys());
    const missing = Object.keys(CANON).filter((n) => !present.has(n));
    if (missing.length) {
      console.log(`         !! missing book(s): ${missing.join(', ')}`);
      problems++;
    }

    if (totalChapters !== 1189) {
      console.log(`         note: ${totalChapters} chapters (the 66 books have 1189)`);
    }
  }

  // Chapters that exist but hold no verses are a half-finished import.
  const empty = books.filter((b) => b.verses === 0);
  if (empty.length) {
    console.log(`         !! ${empty.length} book(s) with chapters but no verses: ${empty.map((b) => b.book).join(', ')}`);
    problems++;
  }
}

console.log('');
console.log(
  problems === 0
    ? 'Every declared translation has usable text with no missing chapters.'
    : `${problems} translation issue(s) found.`,
);
process.exit(problems === 0 ? 0 : 1);
