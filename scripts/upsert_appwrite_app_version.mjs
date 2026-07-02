import { Client, Databases } from 'node-appwrite';
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

function pubspecVersion() {
  const pubspecPath = resolve(process.cwd(), 'pubspec.yaml');
  if (!existsSync(pubspecPath)) return '1.0.0';

  const content = readFileSync(pubspecPath, 'utf8');
  const match = content.match(/^version:\s*([^\s+]+)/m);
  return match?.[1] || '1.0.0';
}

function requireEnv(name, fallback) {
  const value = process.env[name] || fallback;
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

loadDotEnv();

const originalWarn = console.warn.bind(console);
console.warn = (...args) => {
  const message = args.join(' ');
  if (
    process.env.APPWRITE_VERBOSE_WARNINGS !== 'true' &&
    message.includes('current SDK is built for Appwrite')
  ) {
    return;
  }
  originalWarn(...args);
};

const endpoint = requireEnv(
  'APPWRITE_ENDPOINT',
  'https://api.alivenigeria.org/v1',
);
const projectId = requireEnv('APPWRITE_PROJECT_ID', '6a3bef53002f5090dedf');
const databaseId = requireEnv('APPWRITE_DATABASE_ID', '6a089307002e54291a32');
const apiKey = requireEnv('APPWRITE_API_KEY');

const latestVersion = process.env.APP_VERSION_LATEST || pubspecVersion();
const forceUpdate = (process.env.APP_VERSION_FORCE_UPDATE || 'false') === 'true';
const updateUrl =
  process.env.APP_VERSION_UPDATE_URL || 'https://app.alivenigeria.org';
const now = new Date().toISOString();

const appVersionPayload = {
  latest_version: latestVersion,
  force_update: forceUpdate,
  update_url: updateUrl,
};

const document = {
  key: 'app_version',
  setting_key: 'app_version',
  value: JSON.stringify(appVersionPayload),
  type: 'json',
  category: 'system',
  description: 'Controls ALIVE-NG app update prompts on web and iOS.',
  is_public: true,
  updated_at: now,
};

const client = new Client()
  .setEndpoint(endpoint)
  .setProject(projectId)
  .setKey(apiKey);

const databases = new Databases(client);

try {
  await databases.updateDocument(
    databaseId,
    'app_settings',
    'app_version',
    document,
  );
  console.log(`Updated app_settings/app_version to ${latestVersion}.`);
} catch (error) {
  if (error?.code !== 404 && error?.response?.code !== 404) {
    throw error;
  }

  await databases.createDocument(
    databaseId,
    'app_settings',
    'app_version',
    document,
  );
  console.log(`Created app_settings/app_version as ${latestVersion}.`);
}
