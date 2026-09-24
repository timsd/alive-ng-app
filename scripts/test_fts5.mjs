import { DatabaseSync } from 'node:sqlite';

const db = new DatabaseSync(':memory:');
db.exec('CREATE VIRTUAL TABLE fts_test USING fts5(title, body);');
db.exec("INSERT INTO fts_test VALUES ('genesis', 'in the beginning god created');");
const rows = db.prepare("SELECT * FROM fts_test WHERE fts_test MATCH 'beginning'").all();
console.log('FTS5 Works! Result:', rows);
