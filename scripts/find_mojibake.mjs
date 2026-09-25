/**
 * Scans source files for mojibake: characters that appear when a UTF-8 file is
 * decoded as Latin-1/Windows-1252 (e.g. box-drawing rules turning into
 * "â”€â”€"). Resend renders those literally, so they must not ship in an email.
 *
 *   node scripts/find_mojibake.mjs [paths...]
 */
import fs from 'node:fs';
import path from 'node:path';

const t = fs.readFileSync('appwrite_functions/paystackPayments/src/main.js', 'utf8').split('\n');
for (const n of [54, 85, 122, 124, 127, 513]) {
  const line = t[n - 1];
  const idx = line.indexOf('\u00e2');
  const codes = [...line]
    .slice(idx, idx + 5)
    .map((c) => 'U+' + c.codePointAt(0).toString(16).toUpperCase().padStart(4, '0'));
  console.log(`${n}: ${JSON.stringify(line.trim())}`);
  console.log(`     mojibake at ${idx}: ${codes.join(' ')}`);
}
process.exit(0);

const roots = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ['appwrite_functions', 'lib', 'web', 'scripts'];

const hits = [];

function walk(p) {
  const stat = fs.statSync(p);
  if (stat.isDirectory()) {
    for (const entry of fs.readdirSync(p)) {
      if (entry === 'node_modules' || entry === '.git' || entry === 'build') continue;
      walk(path.join(p, entry));
    }
    return;
  }
  if (!/\.(js|mjs|cjs|dart|html|json|arb|md)$/.test(p)) return;

  const text = fs.readFileSync(p, 'utf8');
  text.split('\n').forEach((line, i) => {
    if (!SUSPECT.test(line)) return;
    hits.push({ file: p, line: i + 1, text: line.trim().slice(0, 160) });
  });
}

for (const root of roots) walk(root);

if (hits.length === 0) {
  console.log('No mojibake found.');
} else {
  console.log(`${hits.length} suspect line(s):\n`);
  for (const h of hits) {
    console.log(`${h.file}:${h.line}`);
    console.log(`   ${h.text}\n`);
  }
}
