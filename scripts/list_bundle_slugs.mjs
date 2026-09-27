// Lists the book slugs in a bundle and, where present, the name in each file's
// metadata. Needed because the bundles do not all use the same slug scheme:
// NLT uses `1_chronicles_1.json` while HAU uses `1_bitrus_1.json`, so a single
// slug transform cannot map both onto the database's book names.
//
//   node scripts/list_bundle_slugs.mjs <bundleZip>
import { readFileSync, readdirSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const zip = process.argv[2];
if (!zip) {
  console.error('usage: node scripts/list_bundle_slugs.mjs <bundleZip>');
  process.exit(1);
}

const work = join(tmpdir(), `slug-list-${Date.now()}`);
execFileSync('powershell', [
  '-NoProfile', '-Command',
  `Expand-Archive -LiteralPath '${zip}' -DestinationPath '${work}' -Force`,
], { stdio: 'ignore' });

const files = readdirSync(work).filter((f) => f.endsWith('.json')).sort();
const slugs = new Map();
for (const f of files) {
  const m = /^([a-z0-9_]+?)_(\d+)\.json$/i.exec(f);
  if (!m) continue;
  if (!slugs.has(m[1])) slugs.set(m[1], f);
}

console.log(`${zip}`);
console.log(`${files.length} chapter files, ${slugs.size} distinct book slugs\n`);

for (const [slug, sample] of slugs) {
  let meta = null;
  try {
    const d = JSON.parse(readFileSync(join(work, sample), 'utf8'));
    meta = d.metadata ?? null;
  } catch { /* unreadable is reported by the importer */ }
  const shown = meta ? JSON.stringify(meta).slice(0, 150) : '(no metadata)';
  console.log(`  ${slug.padEnd(28)} ${shown}`);
}

rmSync(work, { recursive: true, force: true });
