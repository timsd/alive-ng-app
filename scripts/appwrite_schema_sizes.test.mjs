import assert from 'node:assert/strict';
import test from 'node:test';
import { tables } from './appwrite_infrastructure_schema.mjs';

test('text fallback uses off-row storage on Appwrite 1.8 MariaDB', () => {
  // Utopia Database 3.5.0 SQL adapter uses VARCHAR up to 16381 characters.
  // Larger strings use TEXT, costing only 20 bytes of the row-size budget.
  for (const table of tables) {
    for (const column of table.columns) {
      if (column.type !== 'text') continue;
      assert.ok(column.size > 16381 && column.size <= 65535,
        `${table.id}.${column.key} must use the TEXT-backed string fallback`);
    }
  }
});
