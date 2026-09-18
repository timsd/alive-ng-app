#!/usr/bin/env node

/**
 * coolify_update_appwrite_env.mjs
 *
 * Automates finding the Appwrite service in Coolify and updating
 * critical environment variables like _APP_DOMAIN.
 *
 * Prerequisites:
 *   1. Create a Coolify API Token:
 *      - Log into your Coolify dashboard
 *      - Go to Security → API Tokens
 *      - Create a new token with "write" permission
 *      - Copy the token
 *
 *   2. Set environment variables (or add to .env):
 *      COOLIFY_API_URL=https://your-coolify.example.com
 *      COOLIFY_API_TOKEN=your-api-token
 *
 * Usage:
 *   node scripts/coolify_update_appwrite_env.mjs
 *   node scripts/coolify_update_appwrite_env.mjs --dry-run     (preview only)
 *   node scripts/coolify_update_appwrite_env.mjs --redeploy     (redeploy after update)
 */

import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// ── Load .env ────────────────────────────────────────────────────────────
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

// ── Configuration ────────────────────────────────────────────────────────
const COOLIFY_API_URL = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const COOLIFY_API_TOKEN = process.env.COOLIFY_API_TOKEN || '';
const DRY_RUN = process.argv.includes('--dry-run');
const REDEPLOY = process.argv.includes('--redeploy');

// The env vars we want to ensure are set correctly on the Appwrite service
const REQUIRED_APPWRITE_ENV = {
  '_APP_DOMAIN': 'api.alivenigeria.org',
  '_APP_DOMAIN_TARGET': 'api.alivenigeria.org',
  '_APP_ENV': 'production',
  '_APP_OPTIONS_FORCE_HTTPS': 'enabled',
  '_APP_SMTP_HOST': 'smtp.resend.com',
  '_APP_SMTP_PORT': '587',
  '_APP_SMTP_USERNAME': 'resend',
  '_APP_SMTP_PASSWORD': process.env.RESEND_API_KEY || '',
  '_APP_SMTP_SECURE': 'tls',
  '_APP_SYSTEM_EMAIL_NAME': 'ALIVE NG App',
  '_APP_SYSTEM_EMAIL_ADDRESS': 'app@alivenigeria.org',
  '_APP_SYSTEM_RESPONSE_EMAIL': 'app@alivenigeria.org',
  '_APP_SYSTEM_TEAM_EMAIL': 'app@alivenigeria.org',
};

// ── Helpers ──────────────────────────────────────────────────────────────
function log(emoji, msg) {
  console.log(`${emoji}  ${msg}`);
}

function fatal(msg) {
  console.error(`\n❌  ${msg}\n`);
  process.exit(1);
}

async function coolifyFetch(path, options = {}) {
  const url = `${COOLIFY_API_URL}/api/v1${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Authorization': `Bearer ${COOLIFY_API_TOKEN}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...options.headers,
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Coolify API ${res.status} ${res.statusText} on ${path}: ${text}`);
  }
  return res.json();
}

// ── Step 1: List all services and find the Appwrite one ──────────────────
async function findAppwriteService() {
  log('🔍', 'Listing all Coolify services...');

  const services = await coolifyFetch('/services');

  if (!Array.isArray(services)) {
    fatal('Unexpected response from /services endpoint. Are you on Coolify v4?');
  }

  log('📋', `Found ${services.length} service(s) in Coolify.`);

  // Try to identify the Appwrite service by name, description, or compose content
  const candidates = services.filter((svc) => {
    const name = (svc.name || '').toLowerCase();
    const desc = (svc.description || '').toLowerCase();
    const compose = (svc.docker_compose_raw || '').toLowerCase();

    return (
      name.includes('appwrite') ||
      desc.includes('appwrite') ||
      compose.includes('_app_domain') ||
      compose.includes('appwrite/appwrite')
    );
  });

  if (candidates.length === 0) {
    log('📋', 'All services found:');
    services.forEach((svc, i) => {
      log('  ', `${i + 1}. [${svc.uuid}] "${svc.name}" (status: ${svc.status || 'unknown'})`);
    });
    fatal(
      'Could not find an Appwrite service. Check the list above and update the script filter if needed.'
    );
  }

  if (candidates.length > 1) {
    log('⚠️', `Found ${candidates.length} Appwrite-related services:`);
    candidates.forEach((svc, i) => {
      log('  ', `${i + 1}. [${svc.uuid}] "${svc.name}" (status: ${svc.status || 'unknown'})`);
    });
    log('📌', 'Using the first match. If this is wrong, specify COOLIFY_SERVICE_UUID in .env.');
  }

  // Allow explicit override via env var
  const explicitUuid = process.env.COOLIFY_SERVICE_UUID;
  if (explicitUuid) {
    const explicit = services.find((s) => s.uuid === explicitUuid);
    if (!explicit) fatal(`Service UUID ${explicitUuid} (from COOLIFY_SERVICE_UUID) not found.`);
    log('🎯', `Using explicitly specified service: "${explicit.name}" [${explicit.uuid}]`);
    return explicit;
  }

  const selected = candidates[0];
  log('🎯', `Selected Appwrite service: "${selected.name}" [${selected.uuid}]`);
  return selected;
}

// ── Step 2: Get service details and current env vars ─────────────────────
async function getServiceEnvVars(serviceUuid) {
  log('📖', `Fetching environment variables for service ${serviceUuid}...`);

  try {
    const envs = await coolifyFetch(`/services/${serviceUuid}/envs`);
    return Array.isArray(envs) ? envs : [];
  } catch (err) {
    log('⚠️', `Could not fetch envs via dedicated endpoint: ${err.message}`);
    log('📖', 'Attempting to read from service details...');

    const service = await coolifyFetch(`/services/${serviceUuid}`);
    if (service.environment_variables && Array.isArray(service.environment_variables)) {
      return service.environment_variables;
    }
    return [];
  }
}

// ── Step 3: Upsert environment variables ─────────────────────────────────
async function upsertEnvVars(serviceUuid, currentEnvs) {
  log('🔧', 'Checking environment variables...');

  const updates = [];
  const alreadyCorrect = [];

  for (const [key, desiredValue] of Object.entries(REQUIRED_APPWRITE_ENV)) {
    const existing = currentEnvs.find(
      (e) => e.key === key || e.name === key
    );
    const currentValue = existing ? (existing.value || existing.real_value || '') : null;

    if (currentValue === desiredValue) {
      alreadyCorrect.push(key);
      log('✅', `${key} = "${desiredValue}" (already correct)`);
    } else {
      updates.push({ key, value: desiredValue, oldValue: currentValue });
      log(
        '🔄',
        `${key}: "${currentValue || '(not set)'}" → "${desiredValue}"${DRY_RUN ? ' [DRY RUN]' : ''}`
      );
    }
  }

  if (updates.length === 0) {
    log('🎉', 'All environment variables are already correct! No changes needed.');
    return false;
  }

  if (DRY_RUN) {
    log('🏁', `DRY RUN: Would update ${updates.length} variable(s). Run without --dry-run to apply.`);
    return false;
  }

  // Apply updates
  for (const { key, value } of updates) {
    try {
      // Try creating/updating via the env endpoint
      await coolifyFetch(`/services/${serviceUuid}/envs`, {
        method: 'POST',
        body: JSON.stringify({
          key,
          value,
          is_preview: false,
        }),
      });
      log('✅', `Updated ${key} successfully.`);
    } catch (err) {
      // If POST fails, try PATCH
      try {
        await coolifyFetch(`/services/${serviceUuid}/envs`, {
          method: 'PATCH',
          body: JSON.stringify({
            key,
            value,
            is_preview: false,
          }),
        });
        log('✅', `Updated ${key} via PATCH.`);
      } catch (patchErr) {
        log('❌', `Failed to update ${key}: ${patchErr.message}`);
        log('💡', `Manually set ${key}=${value} in Coolify UI → Services → Appwrite → Environment Variables`);
      }
    }
  }

  return true;
}

// ── Step 4: Redeploy the service ─────────────────────────────────────────
async function redeployService(serviceUuid) {
  if (!REDEPLOY) {
    log('💡', 'Run with --redeploy flag to automatically redeploy the service after updating env vars.');
    return;
  }

  log('🚀', `Redeploying service ${serviceUuid}...`);

  try {
    await coolifyFetch(`/services/${serviceUuid}/restart`, {
      method: 'POST',
    });
    log('✅', 'Service redeploy initiated. It may take a few minutes to complete.');
  } catch (err) {
    log('⚠️', `Redeploy request failed: ${err.message}`);
    log('💡', 'Please manually redeploy the Appwrite service from the Coolify dashboard.');
  }
}

// ── Main ─────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║  Coolify → Appwrite _APP_DOMAIN Environment Updater    ║');
  console.log('╚══════════════════════════════════════════════════════════╝\n');

  // Validate required config
  if (!COOLIFY_API_URL) {
    fatal(
      'COOLIFY_API_URL is not set.\n' +
      'Set it in your .env file or as an environment variable.\n' +
      'Example: COOLIFY_API_URL=https://coolify.yourdomain.com'
    );
  }
  if (!COOLIFY_API_TOKEN) {
    fatal(
      'COOLIFY_API_TOKEN is not set.\n\n' +
      'To create one:\n' +
      '  1. Log into Coolify at ' + COOLIFY_API_URL + '\n' +
      '  2. Go to Security → API Tokens\n' +
      '  3. Click "New Token", give it a name like "alive-deploy"\n' +
      '  4. Ensure it has "write" permission\n' +
      '  5. Copy the token and add to .env:\n' +
      '     COOLIFY_API_TOKEN=<your-token>\n'
    );
  }

  if (DRY_RUN) log('🏗️', 'Running in DRY RUN mode — no changes will be made.\n');

  try {
    const service = await findAppwriteService();
    const currentEnvs = await getServiceEnvVars(service.uuid);
    const changed = await upsertEnvVars(service.uuid, currentEnvs);

    if (changed) {
      await redeployService(service.uuid);
    }

    console.log('\n───────────────────────────────────────────');
    log('🏁', 'Done!');
    if (changed && !REDEPLOY) {
      log('⚠️', 'Remember: You must redeploy the Appwrite service for env changes to take effect.');
      log('💡', 'Either redeploy from Coolify dashboard or re-run with: --redeploy');
    }
    console.log('');
  } catch (err) {
    console.error('');
    fatal(`${err.message}\n\nStack: ${err.stack}`);
  }
}

main();
