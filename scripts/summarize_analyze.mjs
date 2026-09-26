/**
 * Summarises `flutter analyze` output by lint rule and by file, so the
 * pre-existing `info` backlog can be triaged instead of eyeballed.
 *
 *   node scripts/summarize_analyze.mjs [analyze-output.txt]
 */
import { readFileSync } from 'node:fs';

const path = process.argv[2] ?? 'all.txt';
const text = readFileSync(path, 'utf8');

const byRule = new Map();
const byFile = new Map();

for (const line of text.split(/\r?\n/)) {
  const m = line.match(/^\s*(info|warning|error)\s+-\s+(.*?)\s+-\s+(lib[^\s:]+)(?::\d+:\d+)?\s+-?\s*(\S+)\s*$/);
  if (!m) continue;
  const [, severity, , file, rule] = m;
  byRule.set(rule, (byRule.get(rule) ?? 0) + 1);
  byFile.set(file, (byFile.get(file) ?? 0) + 1);
}

const total = [...byRule.values()].reduce((a, b) => a + b, 0);
console.log(`Parsed ${total} issue(s) from ${path}\n`);

console.log('BY RULE');
for (const [rule, n] of [...byRule].sort((a, b) => b[1] - a[1])) {
  console.log(`  ${String(n).padStart(3)}  ${rule}`);
}

console.log('\nBY FILE (top 15)');
for (const [file, n] of [...byFile].sort((a, b) => b[1] - a[1]).slice(0, 15)) {
  console.log(`  ${String(n).padStart(3)}  ${file}`);
}
