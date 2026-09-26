// Adds expected_response / expected_response_mode to `kids_missions` and
// backfills the 10 seeded activities with a passage, or with a verification
// method a person can actually confirm.
//
// Before this, six of the ten activities were scored against their task
// label ("Learn and recite the Beatitudes from Matthew 5:3-12"), so a
// perfect recitation scored near zero and reciting the label scored full
// marks. `description` is what the child reads on screen and must stay that
// way -- the passage lives in its own field.
//
// Idempotent: existing columns and non-empty responses are left alone.
//
//   node scripts/migrate_kids_mission_expected_responses.mjs
import { existsSync, readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}
loadDotEnv();

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = process.env.APPWRITE_DATABASE_ID;
const collectionId = 'kids_missions';

for (const [name, value] of Object.entries({ endpoint, projectId, apiKey, databaseId })) {
  if (!value) throw new Error(`Missing ${name} in .env`);
}

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

async function api(method, path, body) {
  let lastErr;
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(`${endpoint}/v1${path}`, {
        method,
        headers,
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const text = await res.text();
      if (res.ok) return text ? JSON.parse(text) : {};
      const err = new Error(`HTTP ${res.status}: ${text.slice(0, 200)}`);
      err.status = res.status;
      throw err;
    } catch (e) {
      lastErr = e;
      if (e.status && e.status < 500) throw e;
      await new Promise((r) => setTimeout(r, 800 * attempt));
    }
  }
  throw lastErr;
}

// ── The passages, taken from the Bible shipped in the app ────────────────
const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });
const kjvPassage = (book, chapter, from, to) =>
  db
    .prepare(
      `SELECT v.verse_number, v.text
       FROM bible_verses v JOIN bible_chapters c ON c.id = v.chapter_id
       WHERE c.book = ? AND c.chapter = ? AND c.version = 'KJV'
       ORDER BY v.verse_number`,
    )
    .all(book, chapter)
    .filter((v) => v.verse_number >= from && v.verse_number <= to)
    .map((v) => v.text)
    .join(' ');

const BEATITUDES = kjvPassage('Matthew', 5, 3, 12);
if (!BEATITUDES) throw new Error('Matthew 5:3-12 missing from bible.db');

const BOOKS = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
  'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms',
  'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah',
  'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah',
  'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
  '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians',
  'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
  'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John',
  '2 John', '3 John', 'Jude', 'Revelation',
].join(', ');

// ── Per-activity plan ────────────────────────────────────────────────────
//
// `passage`  -> store the text, keep the spoken/typed scoring.
// `witness`  -> the answer is the child's own words, so a person confirms
//               it. Speech recognition is the wrong instrument: it compares
//               against text the child never said.
const PLAN = {
  'Memorize the Beatitudes': {
    passage: BEATITUDES,
    mode: 'recite',
    verification_method: 'quiz',
  },
  'Learn the Books of the Bible': {
    passage: BOOKS,
    mode: 'recite',
    verification_method: 'story',
  },
  'Share a Bible Story': { witness: true },
  'Prayer Walk': { witness: true },
  'Teach a Bible Song': { witness: true },
  'Invite a Friend to Church': { witness: true },
};

// ── 1. Columns ───────────────────────────────────────────────────────────
const base = `/databases/${databaseId}/collections/${collectionId}`;
const listed = await api('GET', `${base}/attributes?limit=1000`);
const existing = new Set(
  (listed.attributes || listed.columns || []).map((c) => c.key || c.attributeKey || c.name),
);
console.log(`existing columns: ${[...existing].join(', ')}\n`);

for (const [key, size] of [['expected_response', 4000], ['expected_response_mode', 32]]) {
  if (existing.has(key)) {
    console.log(`  = ${key} (already present)`);
    continue;
  }
  try {
    await api('POST', `${base}/attributes/string`, {
      key,
      size,
      required: false,
      xss: false,
      encrypt: false,
    });
    console.log(`  + ${key} (created, size ${size})`);
  } catch {
    // Appwrite 1.7 uses the typed path; older builds use the generic one.
    try {
      await api('POST', `${base}/attributes`, { key, size, type: 'string', required: false });
      console.log(`  + ${key} (created via generic path)`);
    } catch (e) {
      console.log(`  ! ${key} failed: ${e.message}`);
    }
  }
}

// ── 2. Backfill ──────────────────────────────────────────────────────────
const { documents } = await api('GET', `${base}/documents?limit=100`);
let changed = 0;

for (const doc of documents) {
  const plan = PLAN[doc.title];
  if (!plan) {
    console.log(`  - ${doc.title}: no change planned`);
    continue;
  }
  if (doc.expected_response) {
    console.log(`  = ${doc.title}: already has a passage, left alone`);
    continue;
  }

  const payload = plan.witness
    ? { expected_response_mode: null, verification_method: 'witness' }
    : {
        expected_response: plan.passage,
        expected_response_mode: plan.mode,
        verification_method: plan.verification_method,
      };

  await api('PATCH', `${base}/documents/${doc.$id}`, payload);
  changed++;
  console.log(
    plan.witness
      ? `  * ${doc.title}: verification -> witness (a person confirms)`
      : `  * ${doc.title}: passage stored (${plan.passage.length} chars), verification -> ${plan.verification_method}`,
  );
}

console.log(`\nDone. ${changed} of ${documents.length} activities updated.`);

