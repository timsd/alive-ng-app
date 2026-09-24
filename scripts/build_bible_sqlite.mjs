import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { DatabaseSync } from 'node:sqlite';

const DB_OUTPUT = 'assets/bible/bible.db';
const ARCHIVE_DIR = 'bible_bundles_archive_to_delete';

// Clean verse text like in Flutter
function cleanVerseText(raw) {
  if (!raw) return '';
  let text = String(raw)
    .replace(/<f[\s\S]*?<\/f>/gi, '')
    .replace(/<x[\s\S]*?<\/x>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
  return text.replace(/\s+/g, ' ').trim();
}

// Fast pure-Node zip reader
function readZipEntries(zipPath) {
  const buf = fs.readFileSync(zipPath);
  let pos = 0;
  const entries = [];
  while (pos < buf.length - 4) {
    const sig = buf.readUInt32LE(pos);
    if (sig === 0x04034b50) {
      const method = buf.readUInt16LE(pos + 8);
      const compSize = buf.readUInt32LE(pos + 18);
      const nameLen = buf.readUInt16LE(pos + 26);
      const extraLen = buf.readUInt16LE(pos + 28);
      const name = buf.toString('utf8', pos + 30, pos + 30 + nameLen);
      const dataStart = pos + 30 + nameLen + extraLen;
      const compData = buf.subarray(dataStart, dataStart + compSize);
      
      let data;
      if (method === 0) {
        data = compData;
      } else if (method === 8) {
        try {
          data = zlib.inflateRawSync(compData);
        } catch (_) {}
      }
      if (data && name.toLowerCase().endsWith('.json')) {
        entries.push({ name, data: data.toString('utf8') });
      }
      pos = dataStart + compSize;
    } else {
      pos++;
    }
  }
  return entries;
}

console.log('--- Initializing SQLite Bible Database Builder ---');

// Ensure output dir exists and remove old DB if exists
if (fs.existsSync(DB_OUTPUT)) {
  fs.unlinkSync(DB_OUTPUT);
}

const db = new DatabaseSync(DB_OUTPUT);

// Enable WAL mode & performance PRAGMAs for fast building
db.exec(`
  PRAGMA journal_mode = OFF;
  PRAGMA synchronous = 0;
  PRAGMA cache_size = 100000;
`);

// 1. Create Schema
console.log('Creating database schema...');
db.exec(`
  CREATE TABLE bible_books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    abbreviation TEXT NOT NULL,
    chapters INTEGER NOT NULL,
    testament TEXT NOT NULL,
    book_order INTEGER NOT NULL,
    translations TEXT,
    UNIQUE(name, abbreviation)
  );

  CREATE TABLE bible_versions (
    code TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    language TEXT NOT NULL,
    language_code TEXT NOT NULL,
    description TEXT
  );

  CREATE TABLE bible_chapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book TEXT NOT NULL,
    chapter INTEGER NOT NULL,
    version TEXT NOT NULL,
    language TEXT NOT NULL,
    metadata TEXT,
    UNIQUE(book, chapter, version, language)
  );

  CREATE TABLE bible_verses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chapter_id INTEGER NOT NULL,
    verse_number INTEGER NOT NULL,
    text TEXT NOT NULL,
    footnotes TEXT,
    cross_references TEXT,
    FOREIGN KEY (chapter_id) REFERENCES bible_chapters (id) ON DELETE CASCADE,
    UNIQUE(chapter_id, verse_number)
  );

  CREATE VIRTUAL TABLE bible_search USING fts5(
    text,
    content=''
  );
`);

// 2. Insert Books
console.log('Inserting Bible books...');
const insertBookStmt = db.prepare(`
  INSERT OR IGNORE INTO bible_books (name, abbreviation, chapters, testament, book_order, translations)
  VALUES (?, ?, ?, ?, ?, ?)
`);

if (fs.existsSync('assets/bible/books_en.json')) {
  const books = JSON.parse(fs.readFileSync('assets/bible/books_en.json', 'utf8'));
  db.exec('BEGIN TRANSACTION');
  for (const b of books) {
    insertBookStmt.run(
      b.name,
      b.abbreviation,
      b.chapters,
      b.testament,
      b.order,
      b.translations ? JSON.stringify(b.translations) : null
    );
  }
  db.exec('COMMIT');
}

// 3. Insert Versions metadata
console.log('Inserting Bible versions metadata...');
const insertVersionStmt = db.prepare(`
  INSERT OR REPLACE INTO bible_versions (code, name, language, language_code, description)
  VALUES (?, ?, ?, ?, ?)
`);

const versionsList = [
  { code: 'KJV', name: 'King James Version', language: 'English', language_code: 'en' },
  { code: 'NLT', name: 'New Living Translation', language: 'English', language_code: 'en' },
  { code: 'NIV', name: 'New International Version', language: 'English', language_code: 'en' },
  { code: 'ASV', name: 'American Standard Version', language: 'English', language_code: 'en' },
  { code: 'NASB', name: 'New American Standard Bible', language: 'English', language_code: 'en' },
  { code: 'NKJV', name: 'New King James Version', language: 'English', language_code: 'en' },
  { code: 'BM', name: 'Biblica Yoruba (BM)', language: 'Yoruba', language_code: 'yo' },
  { code: 'HAU', name: 'Biblica Hausa (HAU)', language: 'Hausa', language_code: 'ha' },
  { code: 'IGBOB', name: 'Biblica Igbo (IGBOB)', language: 'Igbo', language_code: 'ig' },
];

db.exec('BEGIN TRANSACTION');
for (const v of versionsList) {
  insertVersionStmt.run(v.code, v.name, v.language, v.language_code, `${v.name} (${v.language})`);
}
db.exec('COMMIT');

// 4. Ingestion helper
const insertChapterStmt = db.prepare(`
  INSERT OR REPLACE INTO bible_chapters (book, chapter, version, language, metadata)
  VALUES (?, ?, ?, ?, ?)
`);

const insertVerseStmt = db.prepare(`
  INSERT OR REPLACE INTO bible_verses (chapter_id, verse_number, text, footnotes, cross_references)
  VALUES (?, ?, ?, ?, ?)
`);

const insertFtsStmt = db.prepare(`
  INSERT INTO bible_search (rowid, text)
  VALUES (?, ?)
`);

function processChapterJson(jsonData, fallbackBook, fallbackChapter, versionCode, langCode) {
  let parsed;
  try {
    parsed = typeof jsonData === 'string' ? JSON.parse(jsonData) : jsonData;
  } catch (_) {
    return;
  }

  const meta = parsed.metadata || {};
  const book = meta.book || fallbackBook;
  const chapter = Number(meta.chapter || fallbackChapter);
  const verses = parsed.verses || [];
  if (!book || !chapter || verses.length === 0) return;

  const chapRes = insertChapterStmt.run(
    book,
    chapter,
    versionCode,
    langCode,
    JSON.stringify(meta)
  );
  const chapterId = Number(chapRes.lastInsertRowid);

  for (const v of verses) {
    const verseNum = Number(v.verse ?? v.number ?? 0);
    const rawText = v.text ?? '';
    const cleanText = cleanVerseText(rawText);
    if (verseNum <= 0 || !cleanText) continue;

    const verseRes = insertVerseStmt.run(
      chapterId,
      verseNum,
      cleanText,
      v.footnotes ? JSON.stringify(v.footnotes) : null,
      v.crossReferences ? JSON.stringify(v.crossReferences) : null
    );

    insertFtsStmt.run(
      Number(verseRes.lastInsertRowid),
      cleanText
    );
  }
}

// 5. Ingest each version
for (const v of versionsList) {
  const t0 = Date.now();
  console.log(`Ingesting version ${v.code} (${v.language_code})...`);

  // Check if zip exists in assets/bible_bundles or loose in assets/bible
  const zipPath = `assets/bible_bundles/${v.language_code}/${v.code}.zip`;
  const looseDir = `assets/bible/${v.language_code}/${v.code}`;

  db.exec('BEGIN TRANSACTION');
  let count = 0;

  if (fs.existsSync(zipPath)) {
    const entries = readZipEntries(zipPath);
    for (const entry of entries) {
      processChapterJson(entry.data, '', 0, v.code, v.language_code);
      count++;
    }
  } else if (fs.existsSync(looseDir)) {
    const files = fs.readdirSync(looseDir).filter(f => f.endsWith('.json'));
    for (const file of files) {
      const fullPath = path.join(looseDir, file);
      const content = fs.readFileSync(fullPath, 'utf8');
      processChapterJson(content, '', 0, v.code, v.language_code);
      count++;
    }
  } else {
    console.warn(`Warning: source not found for ${v.code}`);
  }

  db.exec('COMMIT');
  const elapsed = ((Date.now() - t0) / 1000).toFixed(2);
  console.log(`Finished ${v.code}: ${count} chapters ingested in ${elapsed}s`);
}

// 6. Create Indexes
console.log('Building B-Tree compound indexes...');
db.exec(`
  CREATE UNIQUE INDEX idx_chapters_lookup ON bible_chapters (language, version, book, chapter);
  CREATE INDEX idx_verses_lookup ON bible_verses (chapter_id, verse_number);
`);

console.log('Optimizing and vacuuming database...');
db.exec(`
  PRAGMA optimize;
  VACUUM;
`);

const stats = fs.statSync(DB_OUTPUT);
const sizeMb = (stats.size / (1024 * 1024)).toFixed(2);
console.log(`--- SQLite Bible Database Created Successfully! ---`);
console.log(`Path: ${DB_OUTPUT}`);
console.log(`Size: ${sizeMb} MB`);

// Verify sample lookup
const sample = db.prepare(`
  SELECT c.book, c.chapter, v.verse_number, v.text, c.version, c.language
  FROM bible_verses v
  JOIN bible_chapters c ON v.chapter_id = c.id
  WHERE c.book = 'John' AND c.chapter = 3 AND v.verse_number = 16 AND c.version = 'KJV'
`).get();
console.log('Sample Verse Lookup (John 3:16 KJV):', sample);

// Verify FTS search
const ftsSample = db.prepare(`
  SELECT book, chapter, verse, text, version FROM bible_search
  WHERE bible_search MATCH 'light of the world' AND version = 'KJV'
  LIMIT 3
`).all();
console.log('Sample FTS5 Search (light of the world KJV):', ftsSample);

// Move zip bundles to archive folder outside assets
if (!fs.existsSync(ARCHIVE_DIR)) {
  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });
}
if (fs.existsSync('assets/bible_bundles')) {
  console.log(`Moving assets/bible_bundles to ${ARCHIVE_DIR}...`);
  fs.cpSync('assets/bible_bundles', path.join(ARCHIVE_DIR, 'bible_bundles'), { recursive: true });
  fs.rmSync('assets/bible_bundles', { recursive: true, force: true });
}

// Clean up loose json folders in assets/bible/en (ASV, NLT, etc.)
if (fs.existsSync('assets/bible/en')) {
  console.log('Removing loose json folders from assets/bible/en...');
  fs.rmSync('assets/bible/en', { recursive: true, force: true });
}

console.log('ALL DONE! Single SQLite Bible database is ready.');
