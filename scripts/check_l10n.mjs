import { readFileSync } from 'node:fs';
const read = locale => JSON.parse(readFileSync(new URL('../lib/l10n/app_' + locale + '.arb', import.meta.url), 'utf8'));
const base = Object.keys(read('en')).filter(key => !key.startsWith('@'));
let failed = false;
for (const locale of ['yo', 'ig', 'ha']) {
  const messages = read(locale);
  const missing = base.filter(key => typeof messages[key] !== 'string' || !messages[key].trim());
  if (missing.length) {
    failed = true;
    console.error(locale + ': ' + missing.length + ' missing translations: ' + missing.join(', '));
  }
}
if (failed) process.exitCode = 1;
else console.log('All four ARB catalogs have complete key coverage.');

