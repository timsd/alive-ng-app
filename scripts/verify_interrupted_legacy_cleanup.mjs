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

async function isAbsent(action) {
  try {
    await action();
    return false;
  } catch (error) {
    return error?.code === 404 || error?.response?.code === 404;
  }
}

loadDotEnv();

const { appwriteProject, buckets, teams, topics } = await import(
  './appwrite_infrastructure_schema.mjs'
);

const client = new Client()
  .setEndpoint(requireEnv('APPWRITE_ENDPOINT'))
  .setProject(requireEnv('APPWRITE_PROJECT_ID'))
  .setKey(requireEnv('APPWRITE_API_KEY'));

const databases = new Databases(client);
const storage = new Storage(client);
const teamsService = new Teams(client);
const messaging = new Messaging(client);

const result = {
  databaseAbsent: await isAbsent(() =>
    databases.get({ databaseId: appwriteProject.databaseId }),
  ),
  bucketsPresent: [],
  teamsPresent: [],
  topicsPresent: [],
};

for (const bucket of buckets) {
  if (!(await isAbsent(() => storage.getBucket({ bucketId: bucket.id })))) {
    result.bucketsPresent.push(bucket.id);
  }
}

for (const team of teams) {
  if (!(await isAbsent(() => teamsService.get({ teamId: team.id })))) {
    result.teamsPresent.push(team.id);
  }
}

for (const topic of topics) {
  if (!(await isAbsent(() => messaging.getTopic({ topicId: topic.id })))) {
    result.topicsPresent.push(topic.id);
  }
}

console.log(JSON.stringify(result, null, 2));
