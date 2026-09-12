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
loadDotEnv();

const COOLIFY_API_URL = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const COOLIFY_API_TOKEN = process.env.COOLIFY_API_TOKEN || '';

if (!COOLIFY_API_URL || !COOLIFY_API_TOKEN) {
  console.error('Missing COOLIFY_API_URL or COOLIFY_API_TOKEN in .env');
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

async function main() {
  console.log(`Connecting to Coolify at ${COOLIFY_API_URL}...`);

  // 1. List services
  try {
    const services = await coolifyFetch('/services');
    console.log(`\n=== SERVICES (${services.length}) ===`);
    for (const s of services) {
      console.log(`- [${s.uuid}] ${s.name} (status: ${s.status})`);
      if (s.name?.toLowerCase().includes('livekit') || s.name?.toLowerCase().includes('egress')) {
        console.log(`  Details:`, JSON.stringify(s, null, 2));
      }
    }
  } catch (err) {
    console.error('Error fetching services:', err.message);
  }

  // 2. List applications
  try {
    const apps = await coolifyFetch('/applications');
    console.log(`\n=== APPLICATIONS (${apps.length}) ===`);
    for (const a of apps) {
      console.log(`- [${a.uuid}] ${a.name} (${a.fqdn || 'no domain'}) (status: ${a.status})`);
      if (a.name?.toLowerCase().includes('livekit') || a.name?.toLowerCase().includes('egress') || a.uuid === 'w10k2ha1u9yuln6yvskt3hlg') {
        console.log(`  Match found: [${a.uuid}] ${a.name}`);
        console.log(`  Status: ${a.status}`);
        console.log(`  Description: ${a.description}`);
      }
    }
  } catch (err) {
    console.error('Error fetching applications:', err.message);
  }

  // 3. Inspect uuid w10k2ha1u9yuln6yvskt3hlg directly
  console.log('\n=== DIRECT INSPECTION OF w10k2ha1u9yuln6yvskt3hlg (Egress) ===');
  try {
    const app = await coolifyFetch('/applications/w10k2ha1u9yuln6yvskt3hlg');
    console.log('App name:', app.name);
    console.log('App status:', app.status);
    console.log('App image:', app.docker_registry_image_name || app.image);
    console.log('Build pack:', app.build_pack);
    console.log('Custom docker run options:', app.custom_docker_run_options);
    console.log('Ports mappings:', app.ports_mappings);
    console.log('Environment variables:');
    if (app.environment_variables && app.environment_variables.length > 0) {
      for (const ev of app.environment_variables) {
        console.log(`  ${ev.key} = ${ev.is_secret ? '***' : ev.value}`);
      }
    } else {
      console.log('  (none)');
    }
  } catch (e) {
    console.log('App fetch error:', e.message);
  }

  // 4. Inspect LiveKit Server application & all databases
  console.log('\n=== DIRECT INSPECTION OF j7mkltqv629t12szz5oc65oj (LiveKit App) ===');
  try {
    const lkApp = await coolifyFetch('/applications/j7mkltqv629t12szz5oc65oj');
    console.log('LiveKit App env:');
    if (lkApp.environment_variables) {
      for (const ev of lkApp.environment_variables) {
        console.log(`  ${ev.key} = ${ev.is_secret ? '***' : ev.value}`);
      }
    }
  } catch (e) {
    console.log('LiveKit app fetch error:', e.message);
  }

  console.log('\n=== LIST ALL DATABASES IN COOLIFY ===');
  try {
    const databases = await coolifyFetch('/databases');
    console.log(`Found ${databases.length} database(s):`);
    for (const db of databases) {
      console.log(`- [${db.uuid}] ${db.name} (${db.type || db.database_type}) status: ${db.status}`);
    }
  } catch (e) {
    console.log('Databases fetch error:', e.message);
  }

  console.log('\n=== INSPECT ALIVE-REDIS (uz5irsmnydbo32s5rrfect82) ===');
  try {
    const redisDb = await coolifyFetch('/databases/uz5irsmnydbo32s5rrfect82');
    console.log('alive-redis details:');
    console.log({
      name: redisDb.name,
      status: redisDb.status,
      internal_db_url: redisDb.internal_db_url,
      public_port: redisDb.public_port,
      is_public: redisDb.is_public,
      ports_mappings: redisDb.ports_mappings,
    });
  } catch (e) {
    console.log('alive-redis fetch error:', e.message);
  }
}

main().catch(console.error);
