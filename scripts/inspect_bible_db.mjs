// Reports what is actually inside the bundled bible.db: which versions and
// languages are present, and how complete each one is.
//
// The reader showed no NLT and an incomplete Hausa, and a search for
// "jesus wept" returned nothing. This distinguishes "the data is missing" from
// "the query is wrong", which look identical from the UI.
//
//   node scripts/inspect_bible_db.mjs
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const db = new DatabaseSync('assets/bible/bible.db');

const tables = db
  .prepare("select name from sqlite_master where type='table' order by name")
  .all()
  .map((r) => r.name);
console.log(`tables: ${tables.join(', ')}\n`);

for (const t of tables) {
  if (t.startsWith('sqlite_')) continue;
  try {
    const n = db.prepare(`select count(*) as c from "${t}"`).get().c;
    console.log(`  ${t.padEnd(20)} ${String(n).padStart(8)} rows`);
  } catch {
    console.log(`  ${t.padEnd(20)} (count failed)`);
  }
}

if (tables.includes('bible_versions')) {
  console.log('\nbible_versions:');
  for (const v of db.prepare('select * from bible_versions').all()) {
    console.log(`  ${JSON.stringify(v)}`);
  }
}


// Column names differ from the model's field names, so read them rather than
// assume: bible_verses has no `version` column.
for (const t of ['bible_verses', 'bible_books', 'bible_chapters', 'user_progress']) {
  if (!tables.includes(t)) continue;
  const cols = db.prepare(`select name from pragma_table_info('${t}')`).all().map((r) => r.name);
  console.log(`\n${t}: ${cols.join(', ')}`);
}

if (tables.includes('bible_verses')) {
  // bible_verses has no version column: it joins to bible_chapters on
  // chapter_id, and that is where version/language live.
  const perVersion = `
    select c.version as v, c.language as lang, count(*) as c
    from bible_verses vv
    join bible_chapters c on c.id = vv.chapter_id
    group by c.version, c.language
    order by c.version`;

  console.log('\ncompleteness (a full Bible is ~31,102 verses):');
  for (const r of db.prepare(perVersion).all()) {
    const pct = ((r.c / 31102) * 100).toFixed(1);
    console.log(
      `  ${String(r.v).padEnd(8)} ${String(r.lang ?? '-').padEnd(8)} ${String(pct).padStart(7)}%  (${r.c})`,
    );
  }

  const base = `from bible_verses vv join bible_chapters c on c.id = vv.chapter_id`;

  // Reproduce the failing search to see whether it is missing data or a bad query.
  console.log('\nsearch "jesus wept" (LIKE on verse text):');
  for (const v of ['KJV', 'NIV', 'NLT', 'NASB', 'NKJV', 'ASV']) {
    const n = db
      .prepare(`select count(*) as c ${base} where c.version = ? and vv.text like '%Jesus wept%'`)
      .get(v).c;
    const loose = db
      .prepare(`select count(*) as c ${base} where c.version = ? and vv.text like '%weep%'`)
      .get(v).c;
    console.log(`  ${v.padEnd(6)} exact 'Jesus wept': ${n}   any 'weep': ${loose}`);
  }

  console.log('\nrows matching both "Jesus" and "weep" (AND, any version):');
  for (const r of db
    .prepare(`select c.version as v, c.language as lang, c.book, c.chapter, vv.verse_number as vn, vv.text as t ${base} where vv.text like '%Jesus%' and vv.text like '%weep%' limit 8`)
    .all()) {
    console.log(`  ${r.v}/${r.lang ?? '-'} ${r.book} ${r.chapter}:${r.vn}  ${String(r.t).slice(0, 80)}`);
  }

  console.log('\nJohn 11:35 per version (checks NLT and HAU really load):');
  for (const r of db
    .prepare(`select c.version as v, c.language as lang, vv.text as t ${base} where c.book = 'John' and c.chapter = 11 and vv.verse_number = 35 order by c.version`)
    .all()) {
    console.log(`  ${String(r.v).padEnd(8)} ${String(r.lang ?? '-').padEnd(8)} ${String(r.t).slice(0, 70)}`);
  }

  console.log('\nfirst 3 chapters of NLT and HAU (is either sparse?):');
  for (const v of ['NLT', 'HAU']) {
    const n = db.prepare(`select count(*) as c ${base} where c.version = ?`).get(v).c;
    const books = db
      .prepare(`select count(distinct c.book) as c ${base} where c.version = ?`)
      .get(v).c;
    console.log(`  ${v.padEnd(6)} verses=${String(n).padStart(7)}  distinct books=${books}`);
  }

  console.log('\nFTS5 search for "weep":');
  try {
    for (const r of db
      .prepare("select * from bible_search where bible_search match 'weep' limit 3")
      .all()) {
      console.log(`  ${JSON.stringify(r).slice(0, 200)}`);
    }
  } catch (e) {
    console.log(`  FTS query failed: ${e.message}`);
  }
}
