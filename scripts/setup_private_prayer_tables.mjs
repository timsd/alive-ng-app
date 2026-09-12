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

const endpoint = (process.env.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1').replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const apiKey = process.env.APPWRITE_API_KEY;

if (!apiKey) {
  console.log('APPWRITE_API_KEY not set. Run this script with APPWRITE_API_KEY to provision tables in Appwrite.');
}

const headers = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey || '',
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

async function ensureTable(tableId, name, permissions = standardPermissions) {
  console.log(`Checking table: ${tableId}...`);
  const getRes = await appwriteFetch(`/tablesdb/${encodeURIComponent(databaseId)}/tables/${encodeURIComponent(tableId)}`);
  if (getRes.ok) {
    console.log(`Table ${tableId} exists.`);
    return;
  }

  console.log(`Creating table: ${tableId} (${name})...`);
  const createRes = await appwriteFetch(`/tablesdb/${encodeURIComponent(databaseId)}/tables`, {
    method: 'POST',
    body: JSON.stringify({
      tableId,
      name,
      permissions,
    }),
  });

  if (!createRes.ok) {
    const text = await createRes.text();
    console.error(`Failed to create table ${tableId}:`, text);
  } else {
    console.log(`Created table ${tableId} successfully.`);
  }
}

async function ensureStringColumn(tableId, key, size = 255, required = false, isArray = false) {
  const res = await appwriteFetch(
    `/tablesdb/${encodeURIComponent(databaseId)}/tables/${encodeURIComponent(tableId)}/columns/string`,
    {
      method: 'POST',
      body: JSON.stringify({ key, size, required, array: isArray }),
    }
  );
  if (res.ok) console.log(`  + column ${tableId}.${key}`);
}

async function ensureIntegerColumn(tableId, key, required = false) {
  const res = await appwriteFetch(
    `/tablesdb/${encodeURIComponent(databaseId)}/tables/${encodeURIComponent(tableId)}/columns/integer`,
    {
      method: 'POST',
      body: JSON.stringify({ key, required }),
    }
  );
  if (res.ok) console.log(`  + column ${tableId}.${key}`);
}

async function ensureBooleanColumn(tableId, key, required = false, defaultValue = false) {
  const res = await appwriteFetch(
    `/tablesdb/${encodeURIComponent(databaseId)}/tables/${encodeURIComponent(tableId)}/columns/boolean`,
    {
      method: 'POST',
      body: JSON.stringify({ key, required, default: defaultValue }),
    }
  );
  if (res.ok) console.log(`  + column ${tableId}.${key}`);
}

async function ensureDatetimeColumn(tableId, key, required = false) {
  const res = await appwriteFetch(
    `/tablesdb/${encodeURIComponent(databaseId)}/tables/${encodeURIComponent(tableId)}/columns/datetime`,
    {
      method: 'POST',
      body: JSON.stringify({ key, required }),
    }
  );
  if (res.ok) console.log(`  + column ${tableId}.${key}`);
}

async function main() {
  if (!apiKey) {
    console.log('Skipping remote provisioning because APPWRITE_API_KEY is not configured in environment.');
    return;
  }

  console.log(`Setting up Private Prayer & Testimony tables in Database: ${databaseId}...`);

  // 1. private_prayer_rooms
  await ensureTable('private_prayer_rooms', 'Private Prayer Rooms');
  await ensureStringColumn('private_prayer_rooms', 'name', 255, true);
  await ensureStringColumn('private_prayer_rooms', 'description', 5000, false);
  await ensureStringColumn('private_prayer_rooms', 'allowed_roles', 64, false, true);
  await ensureStringColumn('private_prayer_rooms', 'allowed_user_ids', 128, false, true);
  await ensureStringColumn('private_prayer_rooms', 'created_by', 128, true);
  await ensureIntegerColumn('private_prayer_rooms', 'member_count', false);
  await ensureDatetimeColumn('private_prayer_rooms', 'created_at', false);
  await ensureDatetimeColumn('private_prayer_rooms', 'updated_at', false);

  // 2. prayer_testimonies
  await ensureTable('prayer_testimonies', 'Prayer Testimonies');
  await ensureStringColumn('prayer_testimonies', 'prayer_request_id', 128, true);
  await ensureStringColumn('prayer_testimonies', 'user_id', 128, true);
  await ensureStringColumn('prayer_testimonies', 'author_name', 255, false);
  await ensureStringColumn('prayer_testimonies', 'title', 255, true);
  await ensureStringColumn('prayer_testimonies', 'body', 10000, true);
  await ensureDatetimeColumn('prayer_testimonies', 'created_at', false);
  await ensureDatetimeColumn('prayer_testimonies', 'updated_at', false);

  // 3. columns on prayer_requests for private rooms & testimonies
  console.log('Ensuring private prayer columns on prayer_requests...');
  await ensureBooleanColumn('prayer_requests', 'is_private', false, false);
  await ensureStringColumn('prayer_requests', 'room_id', 128, false);
  await ensureStringColumn('prayer_requests', 'testimony_id', 128, false);

  console.log('Setup finished.');
}

main().catch((err) => {
  console.error('Error in setup_private_prayer_tables:', err);
});
