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

function pubspecVersionInfo() {
  const pubspecPath = resolve(process.cwd(), 'pubspec.yaml');
  if (!existsSync(pubspecPath)) return { version: '1.0.0', build: 1 };

  const content = readFileSync(pubspecPath, 'utf8');
  const match = content.match(/^version:\s*([^\s+]+)(?:\+(\d+))?/m);
  return {
    version: match?.[1] || '1.0.0',
    build: match?.[2] ? parseInt(match[2], 10) : 1,
  };
}

function requireEnv(name, fallback) {
  const value = process.env[name] || fallback;
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

loadDotEnv();

const endpoint = requireEnv(
  'APPWRITE_ENDPOINT',
  'https://api.alivenigeria.org/v1',
).replace(/\/$/, '');
const projectId = requireEnv('APPWRITE_PROJECT_ID', '6a3bef53002f5090dedf');
const databaseId = requireEnv('APPWRITE_DATABASE_ID', '6a089307002e54291a32');
const apiKey = requireEnv('APPWRITE_API_KEY');

const { version: detectedVersion, build: detectedBuild } = pubspecVersionInfo();
const latestVersion = process.env.APP_VERSION_LATEST || detectedVersion;
const buildNumber = process.env.APP_BUILD_NUMBER ? parseInt(process.env.APP_BUILD_NUMBER, 10) : detectedBuild;
const forceUpdate = (process.env.APP_VERSION_FORCE_UPDATE || 'false') === 'true';
const updateUrl =
  process.env.APP_VERSION_UPDATE_URL ||
  'https://api.alivenigeria.org/v1/storage/buckets/app_releases/files/alive_ng_android_release/download?project=6a3bef53002f5090dedf';
const now = new Date().toISOString();

const appVersionPayload = {
  latest_version: latestVersion,
  build_number: buildNumber,
  force_update: forceUpdate,
  update_url: updateUrl,
  play_store_url: 'https://play.google.com/store/apps/details?id=com.alive.alivengandroidapp',
};

const documentData = {
  key: 'app_version',
  setting_key: 'app_version',
  value: JSON.stringify(appVersionPayload),
  type: 'json',
  category: 'system',
  description: 'Controls ALIVE Nigeria app update prompts on Android, web and iOS.',
  is_public: true,
  updated_at: now,
};

const headers = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
};

const docUrl = `${endpoint}/databases/${databaseId}/collections/app_settings/documents/app_version`;

// Try updating first
let res = await fetch(docUrl, {
  method: 'PATCH',
  headers,
  body: JSON.stringify({ data: documentData }),
});

if (res.status === 404) {
  // Create document if it doesn't exist
  const createUrl = `${endpoint}/databases/${databaseId}/collections/app_settings/documents`;
  res = await fetch(createUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      documentId: 'app_version',
      data: documentData,
      permissions: ['read("any")'],
    }),
  });
  if (!res.ok) {
    throw new Error(`Failed to create app_version document (${res.status}): ${await res.text()}`);
  }
  console.log(`Created app_settings/app_version as v${latestVersion}.`);
} else if (res.ok) {
  console.log(`Updated app_settings/app_version to v${latestVersion}.`);
} else {
  throw new Error(`Failed to update app_version document (${res.status}): ${await res.text()}`);
}
