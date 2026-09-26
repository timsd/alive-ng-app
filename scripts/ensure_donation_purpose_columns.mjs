/**
 * Ensures the `donation_records` table has the columns the receipt/reporting
 * layer writes.
 *
 * Appwrite rejects a whole document write when it contains an unknown
 * attribute ("Invalid document structure: Unknown attribute: \"purpose\""), so
 * adding the field in code is not enough -- the column has to exist.
 *
 * Uses raw `fetch` rather than node-appwrite on purpose: the installed SDK
 * injects an undici dispatcher that fails against this server with
 * "no available server" (503), while native fetch works.
 *
 * Idempotent: existing columns are left alone.
 *
 *   node scripts/ensure_donation_purpose_columns.mjs
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
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = process.env.APPWRITE_DATABASE_ID;
const collectionId = process.env.APPWRITE_DONATION_RECORDS_COLLECTION_ID || 'donation_records';

for (const [name, value] of Object.entries({ endpoint, projectId, apiKey, databaseId })) {
  if (!value) throw new Error(`Missing ${name} in .env`);
}

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

async function api(method, path, body) {
  // The API occasionally times out on connect from this host, so retry a few
  // times before surfacing the failure.
  let lastErr;
  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const res = await fetch(`${endpoint}/v1${path}`, {
        method,
        headers,
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const text = await res.text();
      let json = {};
      try { json = text ? JSON.parse(text) : {}; } catch { /* keep raw */ }
      if (!res.ok) {
        const err = new Error(json.message || text || `HTTP ${res.status}`);
        err.status = res.status;
        throw err;
      }
      return json;
    } catch (e) {
      // An HTTP-level error is a real answer from the server: do not retry it.
      if (e.status) throw e;
      lastErr = e;
      if (attempt < 4) {
        console.log(`  (retry ${attempt}/3 after: ${e.message})`);
        await new Promise((r) => setTimeout(r, 1500 * attempt));
      }
    }
  }
  throw lastErr;
}

// The project may expose the legacy collections API or the newer tables API.
let base;
let kind;
try {
  await api('GET', `/databases/${databaseId}/collections/${collectionId}`);
  base = `/databases/${databaseId}/collections/${collectionId}/attributes`;
  kind = 'collections/attributes';
  console.log(`Using collections/attributes for ${collectionId}.`);
} catch (e) {
  if (e.status === 404) {
    base = `/tablesdb/${databaseId}/tables/${collectionId}/columns`;
    kind = 'tables/columns';
    console.log(`Using tables/columns for ${collectionId}.`);
  } else {
    throw e;
  }
}

const listed = await api('GET', `${base}?limit=1000`);
const items = listed.attributes || listed.columns || [];
const existingKeys = new Set(items.map((c) => c.key || c.attributeKey || c.name));
console.log(`Existing ${kind}: ${[...existingKeys].join(', ')}\n`);

const WANTED = [
  { key: 'purpose', size: 512, required: false },
  { key: 'project_title', size: 512, required: false },
  // Stamped by the payment handlers once a gift has been added to a project
  // target, so the same charge is never counted twice across the verify call
  // and the Paystack webhook. See `PROJECT_CREDIT_FIELD` in the two functions.
  { key: 'project_credited_at', size: 64, required: false },
];

const isAttributes = kind === 'collections/attributes';
let created = 0;

for (const col of WANTED) {
  if (existingKeys.has(col.key)) {
    console.log(`  = ${col.key} (already present)`);
    continue;
  }
  try {
    // Appwrite 1.7 routes attribute creation per TYPE: the collection path is
    // ".../attributes/string", not a generic POST to ".../attributes".
    const path = isAttributes ? `${base}/string` : base;
    await api('POST', path, {
      key: col.key,
      size: col.size,
      required: col.required,
      ...(isAttributes ? { xss: false, encrypt: false } : { type: 'string' }),
    });
    console.log(`  + ${col.key} (created, size ${col.size})`);
    created++;
  } catch (e) {
    console.log(`  ! ${col.key} failed: ${e.message}`);
  }
}

console.log(
  `\nDone. ${created} column(s) created on ${collectionId} (${databaseId}).` +
    (created ? '' : ' Nothing to do.'),
);
