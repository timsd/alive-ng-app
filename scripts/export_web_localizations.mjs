import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
const output = new URL('../web/locales/', import.meta.url);
mkdirSync(output, { recursive: true });
for (const locale of ['en', 'yo', 'ig', 'ha']) {
  const arb = JSON.parse(readFileSync(new URL('../lib/l10n/app_' + locale + '.arb', import.meta.url), 'utf8'));
  const messages = Object.fromEntries(Object.entries(arb).filter(([key]) => !key.startsWith('@')));
  writeFileSync(new URL(locale + '.json', output), JSON.stringify(messages));
}
console.log('Exported HTML translation dictionaries from ARB catalogs.');
