/**
 * Reports total attribute usage per table and for the whole database.
 *
 * Appwrite enforces an overall attribute budget, so "The maximum number or
 * size of attributes for this collection has been reached" can actually mean
 * the DATABASE is full, not the individual table.
 *
 *   node scripts/check_attribute_budget.mjs
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}
loadDotEnv();

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};
const databaseId = process.env.APPWRITE_DATABASE_ID;

async function get(path) {
  let lastErr;
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(`${endpoint}/v1${path}`, { headers });
      const text = await res.text();
      if (!res.ok) throw new Error(text || `HTTP ${res.status}`);
      return JSON.parse(text);
    } catch (e) {
      lastErr = e;
      if (attempt < 4) await new Promise((r) => setTimeout(r, 1500 * attempt));
    }
  }
  throw lastErr;
}

const listed = await get(`/databases/${databaseId}/collections?limit=200`);
const rows = [];
let total = 0;

for (const c of listed.collections || []) {
  const attrs = await get(
    `/databases/${databaseId}/collections/${c.$id}/attributes?limit=200`,
  );
  const n = (attrs.attributes || []).length;
  total += n;
  rows.push({ id: c.$id, n });
}

rows.sort((a, b) => b.n - a.n);
console.log(`Attribute usage across ${rows.length} collection(s):\n`);
for (const r of rows) {
  const bar = '#'.repeat(Math.round(r.n / 2));
  console.log(`  ${String(r.n).padStart(3)}  ${r.id.padEnd(28)} ${bar}`);
}
console.log(`\nTOTAL: ${total}`);
