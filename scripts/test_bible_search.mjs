// Reproduces the app's FTS5 search, with and without a version/language filter.
//
// "jesus wept" works against the raw index but returned nothing in the app,
// which points at the filter rather than the query: NLT and HAU are listed in
// bible_versions but have zero chapters, so any search filtered to them is
// empty no matter what the terms are.
//
//   node scripts/test_bible_search.mjs "jesus wept"
import { DatabaseSync } from 'node:sqlite';

const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });
const query = process.argv[2] || 'jesus wept';

const normalised = query.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, '').trim();
const tokens = normalised.split(/\s+/);
const matchExpr = tokens.length > 1
  ? `"${normalised}" OR ${tokens.join(' OR ')}`
  : normalised;

console.log(`query: ${JSON.stringify(query)}`);
console.log(`matchExpr: ${matchExpr}\n`);

const run = (label, version, language) => {
  const filters = [];
  const args = [matchExpr];
  if (version) { filters.push('c.version = ?'); args.push(version); }
  if (language) { filters.push('c.language = ?'); args.push(language); }
  const whereExtra = filters.length ? ` AND ${filters.join(' AND ')}` : '';
  args.push(5);
  const sql = `
    SELECT c.book, c.chapter, v.verse_number AS verse, c.version, substr(v.text,1,60) AS text
    FROM bible_search
    JOIN bible_verses v ON v.id = bible_search.rowid
    JOIN bible_chapters c ON c.id = v.chapter_id
    WHERE bible_search MATCH ?${whereExtra}
    ORDER BY bm25(bible_search)
    LIMIT ?`;
  let rows = [];
  let err = null;
  try { rows = db.prepare(sql).all(...args); } catch (e) { err = e.message; }
  const tag = `${label}`.padEnd(28);
  if (err) { console.log(`${tag} ERROR ${err}`); return; }
  console.log(`${tag} ${rows.length} result(s)`);
  for (const r of rows) {
    console.log(`    ${r.version} ${r.book} ${r.chapter}:${r.verse}  ${r.text}`);
  }
};

run('no filter', null, null);

console.log('');
for (const v of ['KJV', 'NIV', 'NKJV', 'NASB', 'ASV', 'NLT', 'HAU', 'BM', 'IGBOB']) {
  run(`version = ${v}`, v, null);
}

console.log('');
for (const l of ['en', 'ha', 'yo', 'ig']) {
  run(`language = ${l}`, null, l);
}

console.log('\nversions listed in bible_versions vs those with actual chapters:');
const listed = db.prepare('select code, language from bible_versions order by code').all();
const loaded = new Set(
  db.prepare('select distinct version as v from bible_chapters').all().map((r) => r.v),
);
for (const v of listed) {
  console.log(`  ${v.code.padEnd(8)} ${String(v.language).padEnd(8)} ${loaded.has(v.code) ? 'loaded' : '*** EMPTY ***'}`);
}

