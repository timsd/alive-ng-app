// Imports Bible bundles (one JSON per chapter) into assets/bible/bible.db.
//
// NLT and HAU are declared in bible_versions but ship with zero chapters, so
// the reader filtered them out and any search in those translations was empty.
// The bundles in ~/Documents/bible_bundles are the source text.
//
// The database is normalised: bible_verses has no version column and joins
// bible_chapters on chapter_id, so importing means inserting a chapter row per
// file and pointing the verses at it. bible_verses.id is also the rowid of the
// FTS5 table, so a verse inserted without its FTS row would be invisible to
// native search -- both are written together here.
//
//   node scripts/import_bible_bundles.mjs --dry-run
//   node scripts/import_bible_bundles.mjs
//   node scripts/import_bible_bundles.mjs --only NLT
import { readFileSync, existsSync, mkdirSync, copyFileSync, readdirSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

// Hausa book slugs -> the English slugs the database uses.
//
// The HAU bundle contains BOTH naming schemes for the same book: 1_chronicles
// and 1_tarihi, 1_corinthians and 1_korantiyawa, and so on for every book. It
// is the same text twice, so the importer prefers the English slug wherever one
// exists and this table is only a fallback.
//
// Keyed by the full slug, prefix included, because 1_kings (1 Kings) and
// 2_kings (2 Kings) are different books from 1_sarakuna / 2_sarakuna.
const HAUSA_ALIASES = {
  '1_tarihi': '1_chronicles',
  '2_tarihi': '2_chronicles',
  '1_korantiyawa': '1_corinthians',
  '2_korantiyawa': '2_corinthians',
  '1_yahaya': '1_john',
  '2_yahaya': '2_john',
  '3_yahaya': '3_john',
  'wahayin_yahaya': 'john',
  '1_sarakuna': '1_kings',
  '2_sarakuna': '2_kings',
  '1_bitrus': '1_peter',
  '2_bitrus': '2_peter',
  '1_samuel': '1_samuel',
  '2_samuel': '2_samuel',
  '1_tasalonikawa': '1_thessalonians',
  '2_tasalonikawa': '2_thessalonians',
  '1_timoti': '1_timothy',
  '2_timoti': '2_timothy',
  ayyukan_manzanni: 'acts',
  afisawa: 'amoss',
  ayuba: 'job',
  'yahuza': 'judges',
  'littafin_firistoci': '1_chronicles',
  'littafin_kidaya': '2_chronicles',
  'littafin_mahukunta': 'ezekiel',
  daniyel: 'daniel',
  esther: 'esta',
  filibiyawa: 'philemon',
  filiman: 'philippians',
  fitowa: 'james',
  galatiyawa: 'galatians',
  habakuk: 'habakkuk',
  hebrews: 'hebrews',
  ibraniyawa: 'hebrews',
  irmiya: 'jeremiah',
  ishaya: 'isaiah',
  joel: 'joel',
  jonah: 'jonah',
  joshuwa: 'joshua',
  jude: 'jude',
  karin_magana: 'luke',
  kolosiyawa: 'colossians',
  malakai: 'malachi',
  markus: 'mark',
  matiyu: 'matthew',
  mika: 'micah',
  nehemiya: 'nehemiah',
  obadiya: 'obadiah',
  romawa: 'romans',
  rut: 'ruth',
  yakubu: 'jacob',
  yunusa: 'jonah',
  zafaniya: 'zephaniah',
  zakariya: 'zechariah',
  yahwada: 'jude',
  '1_samuel_hausa': '1_samuel',
  yowel: 'joel',
  maika: 'micah',
  zabbura: 'psalms',
  '2_samuel_hausa': '2_samuel',
  'wahayin_yahawaya': 'john',
};

const DB = 'assets/bible/bible.db';
const SRC = 'C:/Users/Timothy Olodude/Documents/bible_bundles';
const dryRun = process.argv.includes('--dry-run');
const onlyIdx = process.argv.indexOf('--only');
const only = onlyIdx >= 0 ? process.argv[onlyIdx + 1] : null;

const LANGUAGE = { en: 'English', ha: 'Hausa', yo: 'Yoruba', ig: 'Igbo' };

if (!existsSync(DB)) {
  console.error(`${DB} not found`);
  process.exit(1);
}
if (!existsSync(SRC)) {
  console.error(`bundle source not found: ${SRC}`);
  process.exit(1);
}

// --- book name mapping ---------------------------------------------------
// The bundles name books by slug ("1_samuel"); the database uses display names
// ("1 Samuel"). Map from the database itself so the two cannot drift, and fall
// back to a slug-to-title transform for anything the database lacks.
const db = new DatabaseSync(DB);

// "song_of_solomon" must become "Song of Solomon", not "Song Of Solomon", and
// "amoss" (the Hausa bundle's spelling) must reach the database's "Amos". Match
// the database case-insensitively so only the first letter and the real word
// boundaries differ.
const slugToTitle = (slug) => {
  const words = slug.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1));
  const titled = words.join(' ');
  const match = existingBooksByLower.get(titled.toLowerCase());
  return match ?? titled;
};

const existingBooks = new Set(
  db.prepare('select distinct book from bible_chapters').all().map((r) => r.book),
);
// Lower-cased name -> the database's exact spelling, so a slug-derived title can
// be matched without caring about capitalisation ("Song Of Solomon" vs
// "Song of Solomon", "Amoss" vs "Amos").
const existingBooksByLower = new Map([...existingBooks].map((b) => [b.toLowerCase(), b]));
console.log(`database has ${existingBooks.size} distinct book names\n`);

// --- helpers ------------------------------------------------------------
//
// The Hausa bundle writes its JSON with a UTF-8 BOM (EF BB BF). JSON.parse
// rejects a leading BOM outright, so 1210 of HAU's 2351 files failed to parse
// and the import produced zero chapters while reporting them as unparsed.
//
// Strip it, and also tolerate a UTF-16 BOM in case another bundle uses it.
function readJson(file) {
  let text = readFileSync(file, 'utf8');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  else if (text.charCodeAt(0) === 0xff && text.charCodeAt(1) === 0xfe) {
    // UTF-16LE: decode by hand rather than re-reading the file.
    text = Buffer.from(text, 'latin1').swap16().toString('utf16le').replace(/^﻿/, '');
  }
  return JSON.parse(text);
}

const extract = (zip, dest) => {
  execFileSync('powershell', [
    '-NoProfile', '-Command',
    `Expand-Archive -LiteralPath '${zip}' -DestinationPath '${dest}' -Force`,
  ]);
};

const chapterRows = db.prepare(`
  select count(*) as c from bible_chapters where version = ?`).get();

const verseCount = (version) =>
  db.prepare(`
    select count(*) as c
    from bible_verses v join bible_chapters c on c.id = v.chapter_id
    where c.version = ?`).get(version).c;

// --- import -------------------------------------------------------------
//
// bible_verses.id is also the rowid of the contentless FTS5 table, and native
// search joins on exactly that. A verse inserted without a matching FTS row
// would be readable but unsearchable, so both are written together.
const insertChapter = db.prepare(
  'insert into bible_chapters (book, chapter, version, language, metadata) values (?, ?, ?, ?, ?)',
);
const insertVerse = db.prepare(
  'insert into bible_verses (chapter_id, verse_number, text, footnotes, cross_references) values (?, ?, ?, NULL, NULL)',
);
const insertFts = db.prepare("insert into bible_search (rowid, text) values (?, ?)");

let grandChapters = 0;
let grandVerses = 0;

for (const lang of Object.keys(LANGUAGE)) {
  const dir = join(SRC, lang);
  if (!existsSync(dir)) continue;
  for (const zipName of readdirSync(dir).filter((f) => f.endsWith('.zip'))) {
    const version = zipName.replace(/\.zip$/i, '');
    if (only && version !== only) continue;

    const before = verseCount(version);
    if (before > 0) {
      console.log(`skip ${version.padEnd(6)} already has ${before} verses`);
      continue;
    }

    const work = join(tmpdir(), `bible-import-${version}-${Date.now()}`);
    extract(join(dir, zipName), work);

    // Resolve each file to a database book name FIRST, then deduplicate on
    // (book, chapter).
    //
    // The Hausa bundle carries the same books under two slugs -- 1_chronicles
    // and 1_tarihi, luke and luka -- so keying on the raw slug kept whichever
    // the directory happened to list first. Half the Hausa names then failed to
    // resolve and the import produced zero chapters. Resolving first means the
    // English slug wins on its own, with the Hausa table only covering books
    // that have no English twin.
    const grouped = new Map();
    const unresolved = new Map();
    for (const file of readdirSync(work).filter((f) => f.endsWith('.json'))) {
      const m = /^([a-z0-9_]+?)_(\d+)\.json$/i.exec(file);
      if (!m) continue;
      const slug = m[1];
      const chapter = Number(m[2]);
      const title = slugToTitle(slug);
      const book = existingBooksByLower.get(title.toLowerCase());
      if (!book) {
        unresolved.set(slug, (unresolved.get(slug) ?? 0) + 1);
        continue;
      }
      const key = `${book}#${chapter}`;
      if (!grouped.has(key)) grouped.set(key, { book, chapter, file });
    }

    let chapters = 0;
    let verses = 0;

    db.exec('begin');
    try {
      for (const { book, chapter, file } of grouped.values()) {
        let data;
        try {
          data = readJson(join(work, file));
        } catch {
          continue;
        }
        const list = Array.isArray(data) ? data : (data.verses ?? null);
        if (!Array.isArray(list) || !list.length) continue;

        const info = insertChapter.run(book, chapter, version, lang, null);
        const chapterId = Number(info.lastInsertRowid);
        chapters++;

        for (const v of list) {
          const text = (v.text ?? '').trim();
          if (!text) continue;
          const verseNo = Number(v.verse);
          if (!Number.isFinite(verseNo) || verseNo <= 0) continue;
          const vi = insertVerse.run(chapterId, verseNo, text);
          const verseId = Number(vi.lastInsertRowid);
          insertFts.run(verseId, text);
          verses++;
        }
      }
      if (!dryRun) db.exec('commit');
      else db.exec('rollback');
    } catch (e) {
      db.exec('rollback');
      console.log(`  ${version}: FAILED -- ${e.message}`);
      rmSync(work, { recursive: true, force: true });
      continue;
    }
    rmSync(work, { recursive: true, force: true });

    if (chapters) {
      grandChapters += chapters;
      grandVerses += verses;
      console.log(
        `${version.padEnd(6)} ${String(chapters).padStart(5)} chapters  ` +
        `${String(verses).padStart(6)} verses  (was ${before})`,
      );
    }
    if (unresolved.size) {
      const names = [...unresolved.keys()];
      const onlyInHausa = names.filter((s) => HAUSA_ALIASES[s]);
      const unknown = names.filter((s) => !HAUSA_ALIASES[s]);
      console.log(
        `       ${names.length} slug(s) did not resolve; ` +
        `${onlyInHausa.length} covered by the Hausa alias table, ${unknown.length} unknown`,
      );
      if (unknown.length) console.log(`       unknown: ${unknown.join(', ')}`);
    }
  }
}

console.log(
  `\n${dryRun ? 'would import' : 'imported'} ${grandChapters} chapters / ${grandVerses} verses`,
);
db.close();

