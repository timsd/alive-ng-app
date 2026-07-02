import { Client, Functions } from 'node-appwrite';
import { InputFile } from 'node-appwrite/file';
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { rmSync } from 'node:fs';

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

function requireEnv(name, fallback) {
  const value = process.env[name] || fallback;
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function optionalEnv(name) {
  const value = process.env[name];
  return value && value.trim() ? value.trim() : null;
}

function variableIdFor(key) {
  const normalized = key.toLowerCase().replace(/[^a-z0-9_]/g, '_');
  if (normalized.length <= 36) return normalized;

  const head = normalized.slice(0, 27);
  let hash = 0;
  for (const char of normalized) {
    hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  }
  return `${head}_${hash.toString(36)}`.slice(0, 36);
}

async function upsertVariable(functions, functionId, variable) {
  const existingVariables = await functions.listVariables({
    functionId,
    total: false,
  });
  const existingByKey = existingVariables.variables?.find(
    (item) => item.key === variable.key,
  );
  if (existingByKey) {
    await functions.updateVariable({
      functionId,
      variableId: existingByKey.$id,
      key: variable.key,
      value: variable.value,
      secret: variable.secret,
    });
    console.log(`Updated ${functionId} variable ${variable.key}.`);
    return;
  }

  try {
    await functions.updateVariable({
      functionId,
      variableId: variable.id,
      key: variable.key,
      value: variable.value,
      secret: variable.secret,
    });
    console.log(`Updated ${functionId} variable ${variable.key}.`);
  } catch (error) {
    if (error?.code !== 404 && error?.response?.code !== 404) {
      throw error;
    }

    await functions.createVariable({
      functionId,
      variableId: variable.id,
      key: variable.key,
      value: variable.value,
      secret: variable.secret,
    });
    console.log(`Created ${functionId} variable ${variable.key}.`);
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

const endpoint = requireEnv(
  'APPWRITE_ENDPOINT',
  'https://api.alivenigeria.org/v1',
);
const projectId = requireEnv('APPWRITE_PROJECT_ID', '6a3bef53002f5090dedf');
const databaseId = requireEnv('APPWRITE_DATABASE_ID', '6a089307002e54291a32');
const apiKey = requireEnv('APPWRITE_API_KEY');
const shouldDeploy = process.argv.includes('--deploy');

function envVariable(key, options = {}) {
  const value = options.required ? requireEnv(key) : optionalEnv(key);
  if (!value) return null;

  return {
    id: variableIdFor(key),
    key,
    value,
    secret: options.secret ?? true,
  };
}

function literalVariable(key, value, options = {}) {
  if (!value) return null;

  return {
    id: variableIdFor(key),
    key,
    value,
    secret: options.secret ?? false,
  };
}

const functionConfigs = [
  {
    id: '6a08e9010035dc8c1e51',
    name: 'createLiveKitToken',
    path: 'appwrite_functions/createLiveKitToken',
    variables: [
      envVariable('LIVEKIT_API_KEY', { required: true, secret: true }),
      envVariable('LIVEKIT_API_SECRET', { required: true, secret: true }),
      envVariable('LIVEKIT_SECRET', { secret: true }),
    ],
    create: {
      runtime: 'node-20.0',
      execute: ['users'],
      scopes: ['users.read'],
    },
  },
  {
    id: 'paystack_payments',
    name: 'paystackPayments',
    path: 'appwrite_functions/paystackPayments',
    variables: [
      envVariable('PAYSTACK_SECRET_KEY', { required: true, secret: true }),
      literalVariable('APPWRITE_ENDPOINT', endpoint),
      literalVariable('APPWRITE_PROJECT_ID', projectId),
      literalVariable('APPWRITE_DATABASE_ID', databaseId),
      envVariable('APPWRITE_API_KEY', { required: true, secret: true }),
      envVariable('APPWRITE_FUNCTION_API_KEY', { secret: true }),
      envVariable('APPWRITE_FUNCTION_API_ENDPOINT', { secret: false }),
      envVariable('APPWRITE_FUNCTION_PROJECT_ID', { secret: false }),
      literalVariable('APPWRITE_PAYMENT_LOGS_COLLECTION_ID', 'payment_logs'),
    ],
    create: {
      runtime: 'node-20.0',
      execute: ['any'],
      scopes: ['databases.read', 'databases.write'],
    },
  },
  {
    id: 'paystack_webhook',
    name: 'paystackWebhook',
    path: 'appwrite_functions/paystackWebhook',
    variables: [
      envVariable('PAYSTACK_SECRET_KEY', { required: true, secret: true }),
      literalVariable('APPWRITE_ENDPOINT', endpoint),
      literalVariable('APPWRITE_PROJECT_ID', projectId),
      literalVariable('APPWRITE_DATABASE_ID', databaseId),
      envVariable('APPWRITE_API_KEY', { required: true, secret: true }),
      envVariable('APPWRITE_FUNCTION_API_KEY', { secret: true }),
      envVariable('APPWRITE_FUNCTION_API_ENDPOINT', { secret: false }),
      envVariable('APPWRITE_FUNCTION_PROJECT_ID', { secret: false }),
      literalVariable('APPWRITE_DONATION_RECORDS_COLLECTION_ID', 'donation_records'),
      literalVariable('APPWRITE_PROJECTS_COLLECTION_ID', 'projects'),
      literalVariable('APPWRITE_PAYMENT_LOGS_COLLECTION_ID', 'payment_logs'),
    ],
    create: {
      runtime: 'node-20.0',
      execute: ['any'],
      scopes: ['databases.read', 'databases.write'],
    },
  },
  {
    id: process.env.APPWRITE_SEND_EMAIL_FUNCTION_ID || 'send_email',
    name: 'sendEmail',
    path: 'appwrite_functions/sendEmail',
    variables: [
      envVariable('RESEND_API_KEY', { required: true, secret: true }),
      envVariable('RECEIPT_SENDER_EMAIL', { secret: false }),
      envVariable('SENDER_EMAIL', { secret: false }),
    ],
    create: {
      runtime: 'node-20.0',
      execute: ['users'],
      scopes: [],
    },
  },
];

const client = new Client()
  .setEndpoint(endpoint)
  .setProject(projectId)
  .setKey(apiKey);

const functions = new Functions(client);

async function ensureFunction(config) {
  try {
    return await functions.get({ functionId: config.id });
  } catch (error) {
    if (error?.code !== 404 && error?.response?.code !== 404) {
      throw error;
    }
  }

  await functions.create({
    functionId: config.id,
    name: config.name,
    runtime: config.create.runtime,
    execute: config.create.execute,
    events: [],
    schedule: '',
    timeout: 15,
    enabled: true,
    logging: true,
    entrypoint: 'src/main.js',
    commands: 'npm install',
    scopes: config.create.scopes,
  });

  console.log(`Created Appwrite function ${config.id}.`);
}

function createFunctionArchive(config) {
  const archivePath = resolve(`.tmp-${config.id}-function.tar.gz`);
  rmSync(archivePath, { force: true });

  const result = spawnSync(
    'tar',
    ['-czf', archivePath, '-C', config.path, '.'],
    { cwd: process.cwd(), encoding: 'utf8' },
  );

  if (result.status !== 0) {
    throw new Error(
      `Could not create ${config.id} archive: ${result.stderr || result.stdout}`,
    );
  }

  return archivePath;
}

async function deployFunction(config) {
  const archivePath = createFunctionArchive(config);

  try {
    const deployment = await functions.createDeployment({
      functionId: config.id,
      code: InputFile.fromPath(archivePath, `${config.id}.tar.gz`),
      activate: true,
      entrypoint: 'src/main.js',
      commands: 'npm install',
    });

    console.log(`Uploaded ${config.id} deployment ${deployment.$id}.`);
  } finally {
    rmSync(archivePath, { force: true });
  }
}

for (const config of functionConfigs) {
  await ensureFunction(config);

  const variables = config.variables.filter(Boolean);
  for (const variable of variables) {
    await upsertVariable(functions, config.id, variable);
  }

  if (shouldDeploy) {
    await deployFunction(config);
  }

  console.log(
    `${config.id} variables synced (${variables.map((variable) => variable.key).join(', ')}).`,
  );
}
