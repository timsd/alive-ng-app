import { Client, Databases, Messaging, Storage, Teams } from 'node-appwrite';
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

function requireEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function isMissing(error) {
  return error?.code === 404 || error?.response?.code === 404;
}

async function ignoreMissing(label, action) {
  try {
    await action();
    console.log(`Deleted ${label}.`);
  } catch (error) {
    if (isMissing(error)) {
      console.log(`Already absent ${label}.`);
      return;
    }
    throw error;
  }
}

loadDotEnv();

const { appwriteProject, buckets, teams, topics } = await import(
  './appwrite_infrastructure_schema.mjs'
);

const confirmFlag = '--confirm-delete-interrupted-legacy';
const allowProductionFlag = '--allow-active-production-project';

if (!hasFlag(confirmFlag)) {
  throw new Error(
    `Refusing to delete Appwrite resources without ${confirmFlag}. ` +
      'Run scripts/verify_interrupted_legacy_cleanup.mjs first and review the output.',
  );
}

if (
  appwriteProject.projectId === '6a3bef53002f5090dedf' &&
  !hasFlag(allowProductionFlag)
) {
  throw new Error(
    'Refusing to delete resources from the active production Appwrite project. ' +
      `If this is truly an interrupted legacy project cleanup, pass ${allowProductionFlag}.`,
  );
}

const client = new Client()
  .setEndpoint(requireEnv('APPWRITE_ENDPOINT'))
  .setProject(requireEnv('APPWRITE_PROJECT_ID'))
  .setKey(requireEnv('APPWRITE_API_KEY'));

const databases = new Databases(client);
const storage = new Storage(client);
const teamsService = new Teams(client);
const messaging = new Messaging(client);

console.log(`Cleaning interrupted legacy resources in ${appwriteProject.projectId}.`);

await ignoreMissing(`database ${appwriteProject.databaseId}`, () =>
  databases.delete({ databaseId: appwriteProject.databaseId }),
);

for (const bucket of buckets) {
  await ignoreMissing(`bucket ${bucket.id}`, () =>
    storage.deleteBucket({ bucketId: bucket.id }),
  );
}

for (const team of teams) {
  await ignoreMissing(`team ${team.id}`, () =>
    teamsService.delete({ teamId: team.id }),
  );
}

for (const topic of topics) {
  await ignoreMissing(`topic ${topic.id}`, () =>
    messaging.deleteTopic({ topicId: topic.id }),
  );
}

console.log('Interrupted legacy resource cleanup complete.');
