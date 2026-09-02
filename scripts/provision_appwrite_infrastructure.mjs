import * as appwriteSdk from 'node-appwrite';

const {
  Client,
  Databases,
  Messaging,
  Storage,
  TablesDB,
  Teams,
  Webhooks,
} = appwriteSdk;
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

const {
  appwriteProject,
  buckets,
  publicReadTableIds,
  tables,
  teams,
  topics,
  webhooks,
} = await import('./appwrite_infrastructure_schema.mjs');

const dryRun = process.argv.includes('--dry-run');
const useLegacyDatabases = process.argv.includes('--legacy-databases');
const onlyProviders = process.argv.includes('--only-providers');
const skipMessaging = process.argv.includes('--skip-messaging');
const permissionsOnly = process.argv.includes('--permissions-only');
const onlyTableArg = process.argv.find((arg) => arg.startsWith('--only-table='));
const onlyTableId = onlyTableArg?.split('=').slice(1).join('=');
const onlyBucketArg = process.argv.find((arg) =>
  arg.startsWith('--only-bucket='),
);
const onlyBucketId = onlyBucketArg?.split('=').slice(1).join('=');
const apiKey = process.env.APPWRITE_API_KEY;
const provisionDelayMs = Number(process.env.APPWRITE_PROVISION_DELAY_MS || 250);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function log(message) {
  console.log(message);
}

function isMissing(error) {
  return error?.code === 404 || error?.response?.code === 404;
}

function isConflict(error) {
  return error?.code === 409 || error?.response?.code === 409;
}

function isRouteNotFound(error) {
  const message = error?.message || error?.response?.message || '';
  return isMissing(error) && message.includes('Route not found');
}

function isCapacityLimit(error) {
  const message = error?.message || error?.response?.message || '';
  return message.includes('maximum number or size of attributes') ||
    message.includes('maximum number or size of columns');
}

function isTransientNetworkError(error) {
  const code = error?.cause?.code || error?.code || '';
  const message = [
    error?.message,
    error?.cause?.message,
    error?.response?.message,
  ].filter(Boolean).join(' ');

  return [
    'UND_ERR_CONNECT_TIMEOUT',
    'UND_ERR_HEADERS_TIMEOUT',
    'ECONNRESET',
    'ECONNREFUSED',
    'ETIMEDOUT',
    'EAI_AGAIN',
  ].includes(code) ||
    message.includes('fetch failed') ||
    message.includes('Connect Timeout') ||
    message.includes('Connection lost');
}

async function withRetry(label, action, attempts = 3) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await action();
    } catch (error) {
      if (!isTransientNetworkError(error) || attempt === attempts) {
        throw error;
      }

      const waitMs = provisionDelayMs * attempt * 8;
      console.warn(`Transient Appwrite error during ${label}; retry ${attempt}/${attempts - 1} in ${waitMs}ms`);
      await sleep(waitMs);
    }
  }
}

function cleanParams(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item !== undefined),
  );
}

async function assertTablesDBAvailable() {
  if (dryRun || useLegacyDatabases) return;

  const response = await fetch(`${appwriteProject.endpoint}/tablesdb`, {
    headers: {
      'X-Appwrite-Project': appwriteProject.projectId,
      'X-Appwrite-Key': apiKey,
    },
  });

  if (response.status === 404) {
    throw new Error(
      'TablesDB routes are not available on this Appwrite server. ' +
        'Upgrade Appwrite to a TablesDB-capable version before running ' +
        'npm run appwrite:provision, or explicitly use ' +
        'npm run appwrite:provision:legacy for legacy Databases.',
    );
  }

  if (response.status === 401 || response.status === 403) {
    throw new Error(
      `TablesDB route check returned ${response.status}. Confirm APPWRITE_API_KEY has ` +
        'databases/tables/columns/indexes/rows scopes.',
    );
  }
}

function clientFromEnv() {
  if (!apiKey && !dryRun) {
    throw new Error(
      'Missing APPWRITE_API_KEY. Re-run with APPWRITE_API_KEY set, or use --dry-run.',
    );
  }

  return new Client()
    .setEndpoint(appwriteProject.endpoint)
    .setProject(appwriteProject.projectId)
    .setKey(apiKey || 'dry-run');
}

async function ensureDatabase(tablesDB, databases) {
  if (dryRun) {
    log(`[dry-run] database ${appwriteProject.databaseId}`);
    return;
  }

  const service = useLegacyDatabases ? databases : tablesDB;
  try {
    await service.get({ databaseId: appwriteProject.databaseId });
    log(`OK database ${appwriteProject.databaseId}`);
  } catch (error) {
    if (!isMissing(error)) throw error;
    await service.create({
      databaseId: appwriteProject.databaseId,
      name: 'ALIVE Main Database',
    });
    log(`Created database ${appwriteProject.databaseId}`);
  }
}

async function ensureTable(tablesDB, databases, table) {
  const service = useLegacyDatabases ? databases : tablesDB;
  const get = useLegacyDatabases ? service.getCollection.bind(service) : service.getTable.bind(service);
  const create = useLegacyDatabases ? service.createCollection.bind(service) : service.createTable.bind(service);

  if (dryRun) {
    log(`[dry-run] table ${table.id} (${table.name})`);
  } else {
    try {
      await get({
        databaseId: appwriteProject.databaseId,
        [useLegacyDatabases ? 'collectionId' : 'tableId']: table.id,
      });
      log(`OK table ${table.id}`);
    } catch (error) {
      if (!isMissing(error)) throw error;
      await create({
        databaseId: appwriteProject.databaseId,
        [useLegacyDatabases ? 'collectionId' : 'tableId']: table.id,
        name: table.name,
      });
      log(`Created table ${table.id}`);
      await sleep(provisionDelayMs);
    }
  }

  if (publicReadTableIds.has(table.id)) {
    const desiredPermission = 'read("any")';
    if (dryRun) {
      log(`  [dry-run] ensure permission ${desiredPermission}`);
    } else {
      const resource = await get({
        databaseId: appwriteProject.databaseId,
        [useLegacyDatabases ? 'collectionId' : 'tableId']: table.id,
      });
      const currentPermissions = resource?.$permissions || [];
      if (!currentPermissions.includes(desiredPermission)) {
        const update = useLegacyDatabases
          ? service.updateCollection.bind(service)
          : service.updateTable.bind(service);
        await update({
          databaseId: appwriteProject.databaseId,
          [useLegacyDatabases ? 'collectionId' : 'tableId']: table.id,
          name: resource.name || table.name,
          permissions: [...currentPermissions, desiredPermission],
        });
        log(`  Added public read permission ${table.id}`);
      }
    }
  }

  if (permissionsOnly) return;

  for (const column of table.columns) {
    await ensureColumn(tablesDB, databases, table.id, column);
  }

  for (const index of table.indexes || []) {
    await ensureIndex(tablesDB, databases, table.id, index);
  }
}

async function ensureColumn(tablesDB, databases, tableId, column) {
  const idKey = useLegacyDatabases ? 'collectionId' : 'tableId';
  const service = useLegacyDatabases ? databases : tablesDB;
  const get = useLegacyDatabases ? service.getAttribute.bind(service) : service.getColumn.bind(service);

  if (dryRun) {
    log(`  [dry-run] column ${tableId}.${column.key} (${column.type})`);
    return;
  }

  try {
    await get({
      databaseId: appwriteProject.databaseId,
      [idKey]: tableId,
      [useLegacyDatabases ? 'key' : 'key']: column.key,
    });
    return;
  } catch (error) {
    if (!isMissing(error)) throw error;
  }

  const base = {
    databaseId: appwriteProject.databaseId,
    [idKey]: tableId,
    key: column.key,
    required: column.required ?? false,
    array: column.array ?? false,
  };

  try {
    if (useLegacyDatabases) {
      await createLegacyAttribute(databases, base, column);
    } else {
      await createTableColumn(tablesDB, base, column);
    }
    log(`  Created column ${tableId}.${column.key}`);
    await sleep(provisionDelayMs);
  } catch (error) {
    if (isConflict(error)) return;
    if (isCapacityLimit(error)) {
      console.warn(`  Skipped column ${tableId}.${column.key}: collection attribute capacity reached`);
      return;
    }
    console.error(`Failed column ${tableId}.${column.key} (${column.type})`);
    throw error;
  }
}

async function createTableColumn(tablesDB, base, column) {
  if (column.type === 'varchar') {
    try {
      return await tablesDB.createVarcharColumn(cleanParams({ ...base, size: column.size || 255, default: column.default }));
    } catch (error) {
      if (!isRouteNotFound(error)) throw error;
      return tablesDB.createStringColumn(cleanParams({ ...base, size: column.size || 255, default: column.default }));
    }
  }
  if (column.type === 'text') {
    try {
      return await tablesDB.createTextColumn(cleanParams({ ...base, default: column.default }));
    } catch (error) {
      if (!isRouteNotFound(error)) throw error;
      return tablesDB.createStringColumn(cleanParams({ ...base, size: column.size || 10000, default: column.default }));
    }
  }
  if (column.type === 'mediumtext') {
    try {
      return await tablesDB.createMediumtextColumn(cleanParams({ ...base, default: column.default }));
    } catch (error) {
      if (!isRouteNotFound(error)) throw error;
      return tablesDB.createStringColumn(cleanParams({ ...base, size: column.size || 60000, default: column.default }));
    }
  }
  if (column.type === 'integer') return tablesDB.createIntegerColumn(cleanParams({ ...base, default: column.default }));
  if (column.type === 'float') return tablesDB.createFloatColumn(cleanParams({ ...base, default: column.default }));
  if (column.type === 'boolean') return tablesDB.createBooleanColumn(cleanParams({ ...base, default: column.default }));
  if (column.type === 'datetime') return tablesDB.createDatetimeColumn(cleanParams({ ...base, default: column.default }));
  throw new Error(`Unsupported column type: ${column.type}`);
}

async function createLegacyAttribute(databases, base, column) {
  const legacy = { ...base, collectionId: base.collectionId };
  delete legacy.tableId;
  if (column.type === 'varchar') {
    return databases.createStringAttribute(cleanParams({ ...legacy, size: column.size || 255, default: column.default }));
  }
  if (column.type === 'text') {
    return databases.createStringAttribute(cleanParams({ ...legacy, size: column.size || 10000, default: column.default }));
  }
  if (column.type === 'mediumtext') {
    return databases.createStringAttribute(cleanParams({ ...legacy, size: column.size || 60000, default: column.default }));
  }
  if (column.type === 'integer') return databases.createIntegerAttribute(cleanParams({ ...legacy, default: column.default }));
  if (column.type === 'float') return databases.createFloatAttribute(cleanParams({ ...legacy, default: column.default }));
  if (column.type === 'boolean') return databases.createBooleanAttribute(cleanParams({ ...legacy, default: column.default }));
  if (column.type === 'datetime') return databases.createDatetimeAttribute(cleanParams({ ...legacy, default: column.default }));
  throw new Error(`Unsupported attribute type: ${column.type}`);
}

async function ensureIndex(tablesDB, databases, tableId, index) {
  const service = useLegacyDatabases ? databases : tablesDB;
  const get = useLegacyDatabases ? service.getIndex.bind(service) : service.getIndex.bind(service);
  const create = useLegacyDatabases ? service.createIndex.bind(service) : service.createIndex.bind(service);
  const idKey = useLegacyDatabases ? 'collectionId' : 'tableId';

  if (dryRun) {
    log(`  [dry-run] index ${tableId}.${index.key}`);
    return;
  }

  try {
    await get({
      databaseId: appwriteProject.databaseId,
      [idKey]: tableId,
      key: index.key,
    });
    return;
  } catch (error) {
    if (!isMissing(error)) throw error;
  }

  try {
    await create(cleanParams({
      databaseId: appwriteProject.databaseId,
      [idKey]: tableId,
      key: index.key,
      type: index.type,
      columns: index.columns,
      attributes: index.columns,
      orders: index.orders,
    }));
    log(`  Created index ${tableId}.${index.key}`);
    await sleep(provisionDelayMs);
  } catch (error) {
    if (isConflict(error)) return;
    console.error(`Failed index ${tableId}.${index.key}`);
    throw error;
  }
}

async function ensureBuckets(storage) {
  for (const bucket of buckets) {
    if (onlyBucketId && bucket.id !== onlyBucketId) continue;
    const params = {
      bucketId: bucket.id,
      name: bucket.name,
      enabled: true,
      fileSecurity: false,
      maximumFileSize: bucket.maximumFileSize,
      allowedFileExtensions: bucket.allowedFileExtensions,
      compression: 'gzip',
      encryption: true,
      antivirus: true,
    };

    if (dryRun) {
      log(`[dry-run] bucket ${bucket.id} (${bucket.name})`);
      continue;
    }

    try {
      await storage.getBucket({ bucketId: bucket.id });
      await storage.updateBucket(params);
      log(`OK bucket ${bucket.id}`);
    } catch (error) {
      if (!isMissing(error)) throw error;
      await storage.createBucket(params);
      log(`Created bucket ${bucket.id}`);
      await sleep(provisionDelayMs);
    }
  }
}

async function ensureTeams(teamsService) {
  for (const team of teams) {
    if (dryRun) {
      log(`[dry-run] team ${team.id} (${team.name})`);
      continue;
    }

    try {
      await teamsService.get({ teamId: team.id });
      await teamsService.updateName({ teamId: team.id, name: team.name });
      log(`OK team ${team.id}`);
    } catch (error) {
      if (!isMissing(error)) throw error;
      await teamsService.create({ teamId: team.id, name: team.name });
      log(`Created team ${team.id}`);
      await sleep(provisionDelayMs);
    }
  }
}

async function ensureTopics(messaging) {
  for (const topic of topics) {
    if (dryRun) {
      log(`[dry-run] topic ${topic.id} (${topic.name})`);
      continue;
    }

    try {
      await messaging.getTopic({ topicId: topic.id });
      await messaging.updateTopic({ topicId: topic.id, name: topic.name });
      log(`OK topic ${topic.id}`);
    } catch (error) {
      if (!isMissing(error)) throw error;
      await messaging.createTopic({ topicId: topic.id, name: topic.name });
      log(`Created topic ${topic.id}`);
      await sleep(provisionDelayMs);
    }
  }
}

function optionalEnv(name) {
  const value = process.env[name];
  return value && value.trim() ? value.trim() : undefined;
}

function readFcmServiceAccountJSON() {
  const inlineJSON = optionalEnv('APPWRITE_FCM_SERVICE_ACCOUNT_JSON');
  if (inlineJSON) return inlineJSON;

  const serviceAccountPath = optionalEnv('APPWRITE_FCM_SERVICE_ACCOUNT_PATH');
  if (!serviceAccountPath) return undefined;

  return readFileSync(resolve(process.cwd(), serviceAccountPath), 'utf8');
}

async function ensureMessagingProviders(messaging) {
  const fcmProviderId = optionalEnv('APPWRITE_FCM_PROVIDER_ID');
  if (!fcmProviderId) {
    log('[skip] FCM provider: missing APPWRITE_FCM_PROVIDER_ID');
    return;
  }

  if (dryRun) {
    log(`[dry-run] FCM provider ${fcmProviderId}`);
    return;
  }

  try {
    await messaging.getProvider({ providerId: fcmProviderId });
    log(`OK FCM provider ${fcmProviderId}`);
    return;
  } catch (error) {
    if (!isMissing(error)) throw error;
  }

  const serviceAccountJSON = readFcmServiceAccountJSON();
  if (!serviceAccountJSON) {
    log(
      `[skip] FCM provider ${fcmProviderId}: missing APPWRITE_FCM_SERVICE_ACCOUNT_JSON or APPWRITE_FCM_SERVICE_ACCOUNT_PATH`,
    );
    return;
  }

  await messaging.createFcmProvider({
    providerId: fcmProviderId,
    name: 'ALIVE FCM',
    serviceAccountJSON,
    enabled: true,
  });
  log(`Created FCM provider ${fcmProviderId}`);
}

async function ensureWebhooks(webhooksService) {
  if (!webhooksService) {
    log('[skip] webhooks: unsupported by this Appwrite server/SDK version.');
    return;
  }

  for (const webhook of webhooks) {
    const url = process.env[webhook.urlEnv];
    if (!url) {
      log(`[skip] webhook ${webhook.id}: missing ${webhook.urlEnv}`);
      continue;
    }

    const params = {
      webhookId: webhook.id,
      name: webhook.name,
      url,
      events: webhook.events,
      enabled: true,
      tls: url.startsWith('https://'),
      secret: process.env.APPWRITE_WEBHOOK_SECRET,
    };

    if (dryRun) {
      log(`[dry-run] webhook ${webhook.id} -> ${url}`);
      continue;
    }

    try {
      await webhooksService.get({ webhookId: webhook.id });
      await webhooksService.update(params);
      log(`OK webhook ${webhook.id}`);
    } catch (error) {
      if (!isMissing(error)) throw error;
      await webhooksService.create(params);
      log(`Created webhook ${webhook.id}`);
      await sleep(provisionDelayMs);
    }
  }
}

async function main() {
  const client = clientFromEnv();
  const tablesDB = TablesDB ? new TablesDB(client) : null;
  const databases = new Databases(client);
  const storage = new Storage(client);
  const teamsService = new Teams(client);
  const messaging = new Messaging(client);
  const webhooksService = Webhooks ? new Webhooks(client) : null;

  log(`Provisioning Appwrite project ${appwriteProject.projectId}`);
  log(`Endpoint: ${appwriteProject.endpoint}`);
  log(`Mode: ${dryRun ? 'dry-run' : 'apply'} ${useLegacyDatabases ? '(legacy Databases)' : '(TablesDB)'}`);

  await assertTablesDBAvailable();
  await ensureDatabase(tablesDB, databases);

  if (permissionsOnly) {
    for (const table of tables) {
      if (!publicReadTableIds.has(table.id)) continue;
      await withRetry(`permissions ${table.id}`, () =>
        ensureTable(tablesDB, databases, table),
      );
    }
    log('Appwrite public read permissions complete.');
    return;
  }

  await ensureBuckets(storage);
  if (onlyBucketId) {
    log('Appwrite bucket provisioning complete.');
    return;
  }
  await ensureTeams(teamsService);
  if (skipMessaging) {
    log('[skip] messaging: requested --skip-messaging');
  } else {
    await ensureTopics(messaging);
    await ensureMessagingProviders(messaging);
  }

  if (onlyProviders) {
    log('Appwrite messaging provider verification complete.');
    return;
  }

  for (const table of tables) {
    if (onlyTableId && table.id !== onlyTableId) continue;
    await withRetry(`table ${table.id}`, () => ensureTable(tablesDB, databases, table));
  }

  await withRetry('webhook provisioning', () => ensureWebhooks(webhooksService));
  log('Appwrite infrastructure provisioning complete.');
}

main().catch((error) => {
  console.error(error?.message || error);
  if (error?.cause?.code || error?.cause?.message) {
    console.error(
      `Cause: ${[error.cause.code, error.cause.message].filter(Boolean).join(' - ')}`,
    );
  }
  if (process.env.APPWRITE_VERBOSE_ERRORS === 'true' && error?.stack) {
    console.error(error.stack);
  }
  process.exitCode = 1;
});
