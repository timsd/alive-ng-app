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

    const [key, ...valueParts] = line.split('=');
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

async function upsertVariable(functions, functionId, variable) {
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
  'http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1',
);
const projectId = requireEnv('APPWRITE_PROJECT_ID', '6a088e5f0003764bde50');
const apiKey = requireEnv('APPWRITE_API_KEY');
const sendEmailFunctionId =
  process.env.APPWRITE_SEND_EMAIL_FUNCTION_ID || 'send_email';
const shouldDeploy = process.argv.includes('--deploy');

const resendApiKey = requireEnv('RESEND_API_KEY');
const receiptSenderEmail = optionalEnv('RECEIPT_SENDER_EMAIL');
const senderEmail = optionalEnv('SENDER_EMAIL');

const variables = [
  {
    id: 'resend_api_key',
    key: 'RESEND_API_KEY',
    value: resendApiKey,
    secret: true,
  },
];

if (receiptSenderEmail) {
  variables.push({
    id: 'receipt_sender_email',
    key: 'RECEIPT_SENDER_EMAIL',
    value: receiptSenderEmail,
    secret: false,
  });
}

if (senderEmail) {
  variables.push({
    id: 'sender_email',
    key: 'SENDER_EMAIL',
    value: senderEmail,
    secret: false,
  });
}

const client = new Client()
  .setEndpoint(endpoint)
  .setProject(projectId)
  .setKey(apiKey);

const functions = new Functions(client);

async function ensureSendEmailFunction() {
  try {
    return await functions.get({ functionId: sendEmailFunctionId });
  } catch (error) {
    if (error?.code !== 404 && error?.response?.code !== 404) {
      throw error;
    }
  }

  await functions.create({
    functionId: sendEmailFunctionId,
    name: 'sendEmail',
    runtime: 'node-20.0',
    execute: ['users'],
    events: [],
    schedule: '',
    timeout: 15,
    enabled: true,
    logging: true,
    entrypoint: 'src/main.js',
    commands: 'npm install',
    scopes: [],
  });

  console.log(`Created Appwrite function ${sendEmailFunctionId}.`);
}

function createFunctionArchive() {
  const archivePath = resolve('.tmp-send-email-function.tar.gz');
  rmSync(archivePath, { force: true });

  const result = spawnSync(
    'tar',
    ['-czf', archivePath, '-C', 'appwrite_functions/sendEmail', '.'],
    { cwd: process.cwd(), encoding: 'utf8' },
  );

  if (result.status !== 0) {
    throw new Error(
      `Could not create send_email archive: ${result.stderr || result.stdout}`,
    );
  }

  return archivePath;
}

async function deploySendEmailFunction() {
  const archivePath = createFunctionArchive();

  try {
    const deployment = await functions.createDeployment({
      functionId: sendEmailFunctionId,
      code: InputFile.fromPath(archivePath, 'sendEmail.tar.gz'),
      activate: true,
      entrypoint: 'src/main.js',
      commands: 'npm install',
    });

    console.log(`Uploaded send_email deployment ${deployment.$id}.`);
  } finally {
    rmSync(archivePath, { force: true });
  }
}

await ensureSendEmailFunction();

for (const variable of variables) {
  await upsertVariable(functions, sendEmailFunctionId, variable);
}

if (shouldDeploy) {
  await deploySendEmailFunction();
}

console.log(
  `send_email variables synced (${variables.map((variable) => variable.key).join(', ')}).`,
);
