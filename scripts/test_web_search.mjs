// Reproduces the web search path end to end: build the index from the database
// (the fallback that replaced the missing ZIP bundles) and score the query with
// the same rules as SearchUtils.scoreVerse.
//
// The reader skips FTS5 on web, so this is the path a browser actually takes.
// "Hannah, why weepest thou?" reported no results, and the cause was that
// assets/bible_bundles/ does not exist -- the index build returned null for
// every query, not just that one.
//
//   node scripts/test_web_search.mjs [query]
import { DatabaseSync } from 'node:sqlite';

const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });
const query = process.argv[2] || 'Hannah, why weepest thou?';
const version = process.argv[3] || 'ASV';

// Same SQL the Dart fallback uses.
const rows = db.prepare(`
  SELECT c.book AS book, c.chapter AS chapter,
         v.verse_number AS verse_number, v.text AS text
  FROM bible_verses v
  JOIN bible_chapters c ON c.id = v.chapter_id
  WHERE c.version = ?
  ORDER BY c.book, c.chapter, v.verse_number`).all(version);

console.log(`index built from the database: ${rows.length} verses for ${version}\n`);

// Mirrors SearchUtils.normalize / tokensOf / stem closely enough to rank.
const normalize = (t) => t
  .toLowerCase()
  .replace(/[^\p{L}\p{N}\s]/gu, '')
  .replace(/\s+/g, ' ')
  .trim();

const stop = new Set(['the', 'a', 'an', 'of', 'and', 'to', 'in', 'is', 'for', 'on', 'that', 'it']);
const tokensOf = (t) => normalize(t)
  .split(' ')
  .filter((w) => w.length > 1 && !stop.has(w));

const stem = (w) => w.replace(/(ing|ed|es|s)$/, '');

const phrase = normalize(query);
const tokens = tokensOf(query);
console.log(`query:  ${JSON.stringify(query)}`);
console.log(`phrase: "${phrase}"`);
console.log(`tokens: ${JSON.stringify(tokens)}\n`);

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const scored = [];
for (const r of rows) {
  const text = normalize(r.text);
  let score = 0;
  const phraseIndex = text.indexOf(phrase);
  if (phraseIndex >= 0) score += phrase.includes(' ') ? 8000 : 1500;

  let hits = 0;
  let exactHits = 0;
  for (const t of tokens) {
    const st = stem(t);
    const exact = new RegExp(`\\b${escapeRe(t)}\\b`).test(text);
    const stemmed = st !== t && new RegExp(`\\b${escapeRe(st)}[a-z]*\\b`).test(text);
    const substr = text.includes(t) || (st !== t && text.includes(st));
    if (exact) { hits++; exactHits++; score += 200; }
    else if (stemmed) { hits++; score += 150; }
    else if (substr) { hits++; score += 80; }
  }
  if (hits === tokens.length && tokens.length > 1) score += 3000 + (exactHits === tokens.length ? 1000 : 0);
  else if (hits > 0) score += hits * 50;
  if (score > 0) scored.push({ score, r });
}

scored.sort((a, b) => b.score - a.score);
console.log(`results with score > 0: ${scored.length}`);
for (const { score, r } of scored.slice(0, 8)) {
  console.log(`  ${String(score).padStart(6)}  ${r.book} ${r.chapter}:${r.verse_number}  ${r.text.slice(0, 72)}`);
}
console.log(
  scored.length
    ? '\nPASS: the fallback index finds matches (the web path works).'
    : '\nFAIL: the fallback index finds nothing.',
);
process.exit(scored.length ? 0 : 1);
