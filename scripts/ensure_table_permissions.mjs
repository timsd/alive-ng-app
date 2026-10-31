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
    const value = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
    process.env[key] = value;
  }
}

loadDotEnv();

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const databaseId = process.env.APPWRITE_DATABASE_ID;
const apiKey = process.env.APPWRITE_API_KEY;

if (!endpoint || !projectId || !databaseId || !apiKey) {
  console.error('Missing required Appwrite env variables in .env');
  process.exit(1);
}

const headers = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
};

async function appwriteFetch(path, options = {}) {
  const url = `${endpoint}${path}`;
  const res = await fetch(url, { ...options, headers: { ...headers, ...(options.headers || {}) } });
  return res;
}

const standardPermissions = [
  'read("any")',
  'create("users")',
  'update("users")',
  'delete("users")',
];

async function run() {
  console.log(`Connecting to Appwrite: ${endpoint}, Database: ${databaseId}`);

  // Fetch all tables with proper Appwrite queries[] pagination
  let allTables = [];
  let offset = 0;
  const limit = 100;
  while (true) {
    const query = new URLSearchParams();
    query.append('queries[]', JSON.stringify({ method: 'limit', values: [limit] }));
    query.append('queries[]', JSON.stringify({ method: 'offset', values: [offset] }));
    const listRes = await appwriteFetch(`/tablesdb/${encodeURIComponent(databaseId)}/tables?${query}`);
    if (!listRes.ok) {
      throw new Error(`Failed to list tables (${listRes.status}): ${await listRes.text()}`);
    }
    const data = await listRes.json();
    const batch = data.tables || [];
    allTables.push(...batch);
    const total = data.total ?? allTables.length;
    offset += limit;
    if (offset >= total || batch.length === 0) break;
  }
  const tables = allTables;
  console.log(`Found ${tables.length} tables in Appwrite TablesDB.`);

  let updatedCount = 0;
  const serverOnlyTables = new Set(['officer_registry']);
  for (const table of tables) {
    if (serverOnlyTables.has(table.$id)) {
      console.log(`[SKIP] ${table.name} (${table.$id}) is server-only.`);
      continue;
    }
    const currentPerms = table.$permissions || [];
    const missing = standardPermissions.filter((p) => !currentPerms.includes(p));

    if (missing.length === 0) {
      console.log(`[OK] ${table.name} (${table.$id}) already has all permissions.`);
      continue;
    }

    const newPerms = Array.from(new Set([...currentPerms, ...standardPermissions]));
    console.log(`[UPDATING] ${table.name} (${table.$id}): adding [${missing.join(', ')}]...`);

    const updateRes = await appwriteFetch(`/tablesdb/${databaseId}/tables/${table.$id}`, {
      method: 'PUT',
      body: JSON.stringify({
        name: table.name,
        permissions: newPerms,
      }),
    });

    if (!updateRes.ok) {
      console.warn(`  Warning updating ${table.name}: ${updateRes.status} ${await updateRes.text()}`);
    } else {
      console.log(`  Successfully updated permissions on ${table.name}.`);
      updatedCount++;
    }
  }

  console.log(`\nDone! Updated permissions on ${updatedCount} tables.`);
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
