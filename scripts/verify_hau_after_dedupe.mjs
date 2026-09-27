// Confirms the Hausa translation is still searchable after the duplicate-book
// delete, and that the removed alias names are really gone.
//
//   node scripts/verify_hau_after_dedupe.mjs
import { DatabaseSync } from 'node:sqlite';

const db = new DatabaseSync('assets/bible/bible.db', { readOnly: true });

console.log('--- removed alias names must be absent ---');
for (const name of ['ESTA', 'HABAKUK', 'MALAKAI', 'RUT']) {
  const n = db.prepare("select count(*) as n from bible_chapters where version='HAU' and book=?").get(name).n;
  console.log(`  ${name.padEnd(9)} ${n === 0 ? 'absent (correct)' : `!! STILL PRESENT (${n})`}`);
}

console.log('\n--- kept English names must be present with verses ---');
for (const name of ['Esther', 'Habakkuk', 'Malachi', 'Ruth']) {
  const r = db.prepare(`
    select count(*) as chapters, (select count(*) from bible_verses v
      join bible_chapters c2 on c2.id = v.chapter_id
      where c2.version='HAU' and c2.book=?) as verses
    from bible_chapters where version='HAU' and book=?`).get(name, name);
  console.log(`  ${name.padEnd(9)} ${r.chapters} chapters, ${r.verses} verses`);
}

console.log('\n--- Hausa full-text search must still return results ---');
// A word that appears throughout the Hausa text.
for (const term of ['Allah', 'insa', 'duka']) {
  const rows = db.prepare(`
    select c.book, c.chapter, v.verse_number, substr(v.text, 1, 70) as text
    from bible_search s
    join bible_verses v on v.id = s.rowid
    join bible_chapters c on c.id = v.chapter_id
    where bible_search match ? and c.version = 'HAU'
    limit 2`).all(term);
  console.log(`  '${term}' -> ${rows.length} shown`);
  for (const r of rows) console.log(`      ${r.book} ${r.chapter}:${r.verse_number}  ${r.text}`);
}

console.log('\n--- index integrity ---');
const orphanIdx = db.prepare(`
  select count(*) as n from bible_search s
  left join bible_verses v on v.id = s.rowid where v.id is null`).get().n;
const orphanVerses = db.prepare(`
  select count(*) as n from bible_verses v
  left join bible_chapters c on c.id = v.chapter_id where c.id is null`).get().n;
const indexed = db.prepare('select count(*) as n from bible_search').get().n;
const verses = db.prepare('select count(*) as n from bible_verses').get().n;
console.log(`  index rows ${indexed}, verses ${verses}, orphans in index ${orphanIdx}, orphan verses ${orphanVerses}`);
console.log(orphanIdx === 0 && orphanVerses === 0 && indexed === verses
  ? '  OK' : '  !! MISMATCH');
