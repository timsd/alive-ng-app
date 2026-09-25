/**
 * Repairs mojibake: sequences that appear when UTF-8 bytes were decoded as
 * Windows-1252 / Latin-1, so a box-drawing rule reads as three junk characters,
 * the naira sign as junk, an em dash as junk, and so on.
 *
 * These are visible in the Appwrite function logs (which is where they were
 * spotted) and would render literally in any email body containing them, so
 * they must not ship. Only genuine mojibake sequences are touched.
 *
 *   node scripts/fix_mojibake.mjs [paths...]
 */
import fs from 'node:fs';
import path from 'node:path';

// Mojibake source -> intended character. Written as explicit escapes so this
// file itself can never become a source of new mojibake.
const REPLACEMENTS = [
  // Em dash: Windows-1252 decodes the UTF-8 bytes E2 80 94 as U+00E2 U+20AC
  // U+0094, which Node then shows as U+201D. Both orderings occur in this repo.
  ['\u00E2\u20AC\u201D', '\u2014'],
  ['\u00E2\u20AC\u00A2', '\u2014'],
  ['\u00E2\u20AC\u201C', '\u2013'], // en dash
  ['\u00E2\u20AC\u00A2\u00E2\u0080\u009C', '\u2022'], // bullet
  ['\u00E2\u201A\u00A6', '\u20A6'], // naira sign
  ['\u00E2\u2030\u02C6', '\u2248'], // almost equal
  ['\u00E2\u2030\u00A5', '\u2265'], // greater or equal
  ['\u00C3\u2014', '\u2014'],
  ['\u00C3\u2019', '\u2019'],
  ['\u00C3\u201C', '\u201C'],
  ['\u00C3\u00A9', '\u00E9'],
  ['\u00C3\u00A8', '\u00E8'],
  ['\u00C3\u00BC', '\u00FC'],
  ['\u00C3\u00B6', '\u00F6'],
  ['\u00C3\u00A4', '\u00E4'],
  ['\u00C3\u00B1', '\u00F1'],
  ['\u00C2\u00A0', ' '],
];

// The three-byte mojibake of a box-drawing rule is U+00E2 U+201D U+20AC.
// Longest runs are restored first so a long divider is not left half-converted.
for (let n = 40; n >= 1; n--) {
  REPLACEMENTS.push(['\u00E2\u201D\u20AC'.repeat(n), '\u2500'.repeat(n)]);
}

const roots = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ['appwrite_functions', 'lib', 'web'];

let changedFiles = 0;
let changedLines = 0;

function fixLine(line) {
  let out = line;
  for (const [bad, good] of REPLACEMENTS) {
    if (!good) continue;
    while (out.includes(bad)) {
      out = out.replace(bad, good);
      changedLines++;
    }
  }
  return out;
}

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

  const original = fs.readFileSync(p, 'utf8');
  const fixed = original.split('\n').map(fixLine).join('\n');
  if (fixed !== original) {
    fs.writeFileSync(p, fixed, 'utf8');
    changedFiles++;
    console.log(`fixed: ${p}`);
  }
}

for (const root of roots) walk(root);

console.log(`\n${changedFiles} file(s) changed, ${changedLines} replacement(s).`);
