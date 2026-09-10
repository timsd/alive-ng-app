// Live diagnostic for the ALIVE-NG Appwrite backend.
//
// Unlike `npm run appwrite:dry-run` (which only logs intended actions), this
// script CONNECTS to the live Appwrite server using APPWRITE_API_KEY and
// reports EXACTLY what is missing versus scripts/appwrite_infrastructure_schema.mjs:
//   - missing database
//   - missing tables/collections
//   - missing columns/attributes per table
//   - missing indexes per table
//   - missing public read("any") permissions
//   - missing buckets, teams, and messaging topics
//
// Usage:
//   node --env-file=.env scripts/diagnose_appwrite_infrastructure.mjs
//   npm run appwrite:diagnose
//
// Exit code is 1 when anything is missing, 0 when the backend fully matches
// the schema, so it can be used in CI.

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

const {
  appwriteProject,
  buckets,
  publicReadTableIds,
  tables,
  teams,
  topics,
} = await import('./appwrite_infrastructure_schema.mjs');

const endpoint = (appwriteProject.endpoint || '').replace(/\/$/, '');
const projectId = appwriteProject.projectId;
const databaseId = appwriteProject.databaseId;
const apiKey = process.env.APPWRITE_API_KEY;

const onlyTableArg = process.argv.find((arg) => arg.startsWith('--only-table='));
const onlyTableId = onlyTableArg?.split('=').slice(1).join('=');
const jsonOutput = process.argv.includes('--json');

if (!apiKey) {
  console.error('Missing APPWRITE_API_KEY. Set it in .env and re-run.');
  process.exit(2);
}

const baseHeaders = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
};

async function apiGet(path) {
  const response = await fetch(`${endpoint}${path}`, {
    headers: baseHeaders,
    signal: AbortSignal.timeout(30000),
  });
  const text = await response.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch (_) { body = text; }
  if (!response.ok && response.status !== 404) {
    throw new Error(`Appwrite request failed: HTTP ${response.status} at ${path}. Check connectivity and API-key scopes.`);
  }
  return { status: response.status, ok: response.ok, body };
}

// Detect whether the server exposes TablesDB routes (Appwrite 1.8.x).
async function detectTablesDB() {
  const res = await apiGet('/tablesdb');
  if (res.status === 404) return false;
  if (res.status === 401 || res.status === 403) {
    console.error(
      `TablesDB route check returned ${res.status}. The APPWRITE_API_KEY needs ` +
      'databases/tables/columns/indexes/rows scopes.',
    );
    process.exit(2);
  }
  return true;
}

const useTablesDB = await detectTablesDB();
const collectionSegment = useTablesDB ? 'tables' : 'collections';
const databaseSegment = useTablesDB ? 'tablesdb' : 'databases';

console.log(`Endpoint:        ${endpoint}`);
console.log(`Project:         ${projectId}`);
console.log(`Database:        ${databaseId}`);
console.log(`API mode:        ${useTablesDB ? 'TablesDB (1.8.x)' : 'Legacy Databases (1.7.x)'}`);
console.log('');

const report = {
  mode: useTablesDB ? 'tablesdb' : 'legacy',
  databaseMissing: false,
  missingTables: [],
  tableIssues: [],
  missingBuckets: [],
  missingTeams: [],
  missingTopics: [],
};

// 1) Database existence
const dbRes = await apiGet(`/${databaseSegment}/${encodeURIComponent(databaseId)}`);
if (!dbRes.ok) {
  report.databaseMissing = true;
  console.log(`[MISSING] database ${databaseId} (HTTP ${dbRes.status})`);
  console.log('  -> Run: npm run appwrite:provision');
  console.log('');
} else {
  console.log(`[OK] database ${databaseId}`);
}

// 2) List all tables/collections (paginated)
async function listAllCollections() {
  const all = [];
  let offset = 0;
  const limit = 100;
  for (;;) {
    const query = new URLSearchParams();
    query.append('queries[]', JSON.stringify({ method: 'limit', values: [limit] }));
    query.append('queries[]', JSON.stringify({ method: 'offset', values: [offset] }));
    const res = await apiGet(
      `/${databaseSegment}/${encodeURIComponent(databaseId)}/${collectionSegment}?${query}`,
    );
    if (!res.ok) {
      if (res.status === 404) throw new Error('Table listing route was not found; this does not mean all tables are missing.');
      throw new Error(`Failed to list ${collectionSegment}: HTTP ${res.status} ${JSON.stringify(res.body)}`);
    }
    const items = res.body?.[collectionSegment] || res.body?.collections || res.body?.tables || [];
    all.push(...items);
    const total = res.body?.total ?? all.length;
    offset += limit;
    if (offset >= total || items.length === 0) break;
  }
  return all;
}

const liveCollections = report.databaseMissing ? [] : (await listAllCollections() || []);
const liveById = new Map();
for (const item of liveCollections) {
  const id = item.$id || item.id;
  const columns = item.columns || item.attributes || [];
  const indexes = item.indexes || [];
  liveById.set(id, {
    name: item.name,
    permissions: item.$permissions || [],
    columnKeys: new Set(columns.map((c) => c.key)),
    indexKeys: new Set(indexes.map((ix) => ix.key)),
  });
}

console.log(`Live ${collectionSegment} found: ${liveById.size}`);
console.log('');


// 3) Compare each schema table
const schemaTables = onlyTableId ? tables.filter((t) => t.id === onlyTableId) : tables;

for (const table of schemaTables) {
  const live = liveById.get(table.id);
  if (!live) {
    report.missingTables.push(table.id);
    console.log(`[MISSING TABLE] ${table.id} (${table.name})`);
    continue;
  }

  const missingColumns = (table.columns || []).filter((c) => !live.columnKeys.has(c.key)).map((c) => c.key);
  const missingIndexes = (table.indexes || []).filter((ix) => !live.indexKeys.has(ix.key)).map((ix) => ix.key);

  const wantsPublicRead = publicReadTableIds.has(table.id);
  const hasPublicRead = live.permissions.some((p) => p === 'read("any")');
  const missingPermission = wantsPublicRead && !hasPublicRead;

  if (missingColumns.length || missingIndexes.length || missingPermission) {
    report.tableIssues.push({ id: table.id, name: table.name, missingColumns, missingIndexes, missingPermission });
    console.log(`[ISSUE] ${table.id} (${table.name})`);
    if (missingColumns.length) console.log(`   missing columns: ${missingColumns.join(', ')}`);
    if (missingIndexes.length) console.log(`   missing indexes: ${missingIndexes.join(', ')}`);
    if (missingPermission) console.log('   missing permission: read("any")');
  }
}

// 4) Buckets
for (const bucket of buckets) {
  const res = await apiGet(`/storage/buckets/${encodeURIComponent(bucket.id)}`);
  if (!res.ok) {
    report.missingBuckets.push(bucket.id);
    console.log(`[MISSING BUCKET] ${bucket.id} (${bucket.name}) HTTP ${res.status}`);
  }
}

// 5) Teams
for (const team of teams) {
  const res = await apiGet(`/teams/${encodeURIComponent(team.id)}`);
  if (!res.ok) {
    report.missingTeams.push(team.id);
    console.log(`[MISSING TEAM] ${team.id} (${team.name}) HTTP ${res.status}`);
  }
}

// 6) Topics
for (const topic of topics) {
  const res = await apiGet(`/messaging/topics/${encodeURIComponent(topic.id)}`);
  if (!res.ok) {
    report.missingTopics.push(topic.id);
    console.log(`[MISSING TOPIC] ${topic.id} (${topic.name}) HTTP ${res.status}`);
  }
}

// Summary
const totalIssues =
  (report.databaseMissing ? 1 : 0) +
  report.missingTables.length +
  report.tableIssues.length +
  report.missingBuckets.length +
  report.missingTeams.length +
  report.missingTopics.length;

console.log('');
console.log('================ DIAGNOSIS SUMMARY ================');
console.log(`Mode:                 ${report.mode}`);
console.log(`Database missing:     ${report.databaseMissing}`);
console.log(`Missing tables:       ${report.missingTables.length}`);
console.log(`Tables with issues:   ${report.tableIssues.length}`);
console.log(`Missing buckets:      ${report.missingBuckets.length}`);
console.log(`Missing teams:        ${report.missingTeams.length}`);
console.log(`Missing topics:       ${report.missingTopics.length}`);
console.log(`TOTAL ISSUES:         ${totalIssues}`);
console.log('===================================================');

if (totalIssues > 0) {
  console.log('');
  console.log('Fix by provisioning the live backend:');
  console.log('  npm run appwrite:provision          (TablesDB / Appwrite 1.8.x)');
  console.log('  npm run appwrite:provision:legacy   (legacy Databases / Appwrite 1.7.x)');
  console.log('  npm run appwrite:permissions        (permissions only)');
}

if (jsonOutput) {
  console.log('');
  console.log(JSON.stringify(report, null, 2));
}

process.exit(totalIssues > 0 ? 1 : 0);

