#!/usr/bin/env node
/**
 * Synchronizes Paystack keys across:
 * 1. Appwrite app_settings collection (for dynamic mobile/runtime retrieval)
 * 2. Appwrite Cloud Functions (paystack_payments & paystack_webhook environment variables)
 * 3. Coolify FLUTTER_BUILD_ARGS (for Flutter Web build-time injection)
 *
 * Usage:
 *   node scripts/sync_payment_keys.mjs [PUBLIC_KEY] [SECRET_KEY]
 *
 * If arguments are omitted, it reads PAYSTACK_PUBLIC_KEY and PAYSTACK_SECRET_KEY
 * from process.env or .env.
 */

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Client, Databases, Functions, Query, ID } from 'node-appwrite';

// Patch Client for Node 26 Undici compatibility
const _origPrepare = Client.prototype?.prepareRequest;
if (_origPrepare) {
  Client.prototype.prepareRequest = function (...args) {
    const res = _origPrepare.apply(this, args);
    if (res && res.options) {
      delete res.options.dispatcher;
      delete res.options.agent;
    }
    return res;
  };
}

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
loadDotEnv();

const argPk = process.argv[2]?.trim();
const argSk = process.argv[3]?.trim();

const publicKey = (argPk && argPk.startsWith('pk_')) ? argPk : process.env.PAYSTACK_PUBLIC_KEY?.trim();
const secretKey = (argSk && argSk.startsWith('sk_')) ? argSk : process.env.PAYSTACK_SECRET_KEY?.trim();

if (!publicKey && !secretKey) {
  console.log(`
Usage:
  node scripts/sync_payment_keys.mjs <pk_live_...> <sk_live_...>

Or set PAYSTACK_PUBLIC_KEY and/or PAYSTACK_SECRET_KEY in your environment.
`);
  process.exit(1);
}

const endpoint = process.env.APPWRITE_ENDPOINT;
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;
const databaseId = process.env.APPWRITE_DATABASE_ID || '6a089307002e54291a32';
const appSettingsTable = 'app_settings';

console.log('--- Paystack Key Synchronization ---');
if (publicKey) console.log(`Public Key: ${publicKey.slice(0, 12)}...${publicKey.slice(-4)}`);
if (secretKey) console.log(`Secret Key: ${secretKey.slice(0, 12)}...${secretKey.slice(-4)}`);

async function updateAppSettings(key, value) {
  const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
  const db = new Databases(client);

  try {
    const existing = await db.listDocuments(databaseId, appSettingsTable, [
      Query.equal('key', key),
      Query.limit(1),
    ]);

    if (existing.documents.length > 0) {
      const doc = existing.documents[0];
      await db.updateDocument(databaseId, appSettingsTable, doc.$id, {
        value: value,
      });
      console.log(`[Appwrite DB] Updated '${key}' in ${appSettingsTable}`);
    } else {
      await db.createDocument(databaseId, appSettingsTable, ID.unique(), {
        key: key,
        value: value,
      });
      console.log(`[Appwrite DB] Created '${key}' in ${appSettingsTable}`);
    }
  } catch (err) {
    console.warn(`[Appwrite DB] Warning updating '${key}': ${err.message}`);
  }
}

async function updateFunctionVariable(functionId, key, value, isSecret = false) {
  const client = new Client().setEndpoint(endpoint).setProject(projectId).setKey(apiKey);
  const fn = new Functions(client);

  try {
    const vars = await fn.listVariables(functionId);
    const existing = vars.variables.find((v) => v.key === key);

    if (existing) {
      await fn.updateVariable(functionId, existing.$id, key, value);
      console.log(`[Appwrite Function] Updated variable '${key}' for '${functionId}'`);
    } else {
      await fn.createVariable(functionId, key, value);
      console.log(`[Appwrite Function] Created variable '${key}' for '${functionId}'`);
    }
  } catch (err) {
    console.warn(`[Appwrite Function] Warning updating '${key}' on '${functionId}': ${err.message}`);
  }
}

async function updateCoolify(pk) {
  const base = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
  const token = process.env.COOLIFY_API_TOKEN;
  const uuid = process.env.COOLIFY_SERVICE_UUID;

  if (!base || !token || !uuid) {
    console.log('[Coolify] Skipping: COOLIFY_API_URL, COOLIFY_API_TOKEN or COOLIFY_SERVICE_UUID not set.');
    return;
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };

  try {
    const appUrl = `${base}/api/v1/applications/${uuid}`;
    const envs = await (await fetch(`${appUrl}/envs`, { headers })).json();
    const current = (envs ?? []).find((v) => v.key === 'FLUTTER_BUILD_ARGS');

    if (!current) {
      console.log('[Coolify] FLUTTER_BUILD_ARGS not found in Coolify.');
      return;
    }

    let val = current.value || '';
    if (val.includes('--dart-define=PAYSTACK_PUBLIC_KEY=')) {
      val = val.replace(
        /--dart-define=PAYSTACK_PUBLIC_KEY=[^\s]+/,
        `--dart-define=PAYSTACK_PUBLIC_KEY=${pk}`,
      );
    } else {
      val = `${val.trim()} --dart-define=PAYSTACK_PUBLIC_KEY=${pk}`;
    }

    for (const [method, url, body] of [
      ['PATCH', `${appUrl}/envs`, { key: 'FLUTTER_BUILD_ARGS', value: val }],
      ['PATCH', `${appUrl}/envs/${current.uuid}`, { value: val }],
      [
        'PUT',
        `${appUrl}/envs/${current.uuid}`,
        {
          key: 'FLUTTER_BUILD_ARGS',
          value: val,
          is_build_time: true,
          is_runtime: true,
          is_preview: false,
        },
      ],
      [
        'PUT',
        `${appUrl}/envs`,
        [
          {
            uuid: current.uuid,
            key: 'FLUTTER_BUILD_ARGS',
            value: val,
            is_build_time: true,
            is_runtime: true,
            is_preview: false,
          },
        ],
      ],
    ]) {
      const res = await fetch(url, {
        method,
        headers,
        body: JSON.stringify(body),
      });
      if (res.ok) {
        console.log(`[Coolify] Updated FLUTTER_BUILD_ARGS with new PAYSTACK_PUBLIC_KEY (${method} ${url.replace(base, '')})`);
        return;
      }
    }
    console.warn('[Coolify] Could not update FLUTTER_BUILD_ARGS across supported routes');
  } catch (err) {
    console.warn(`[Coolify] Error updating Coolify: ${err.message}`);
  }
}

async function main() {
  if (publicKey) {
    await updateAppSettings('paystack_public_key', publicKey);
    await updateFunctionVariable('paystack_payments', 'PAYSTACK_PUBLIC_KEY', publicKey, false);
    await updateCoolify(publicKey);
  }

  if (secretKey) {
    await updateAppSettings('paystack_secret_key', secretKey);
    await updateFunctionVariable('paystack_payments', 'PAYSTACK_SECRET_KEY', secretKey, true);
    await updateFunctionVariable('paystack_webhook', 'PAYSTACK_SECRET_KEY', secretKey, true);
  }

  console.log('\n--- Build Instructions for APK / AAB ---');
  console.log('Mobile apps automatically fetch the active public key from Appwrite app_settings at runtime.');
  console.log('For zero-latency startup on fresh installs, build with:');
  if (publicKey) {
    console.log(`  flutter build apk --release --dart-define=PAYSTACK_PUBLIC_KEY=${publicKey}`);
    console.log(`  flutter build appbundle --release --dart-define=PAYSTACK_PUBLIC_KEY=${publicKey}`);
  } else {
    console.log(`  flutter build apk --release --dart-define=PAYSTACK_PUBLIC_KEY=<your_public_key>`);
    console.log(`  flutter build appbundle --release --dart-define=PAYSTACK_PUBLIC_KEY=<your_public_key>`);
  }
  console.log('Synchronization complete!\n');
}

main().catch(console.error);
