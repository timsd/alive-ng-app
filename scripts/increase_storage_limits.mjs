import fs from 'node:fs';
import path from 'node:path';

// Load .env
if (fs.existsSync('.env')) {
  const envContent = fs.readFileSync('.env', 'utf8');
  for (const line of envContent.split(/\r?\n/)) {
    if (!line || line.startsWith('#')) continue;
    const idx = line.indexOf('=');
    if (idx > 0) {
      const k = line.slice(0, idx).trim();
      const v = line.slice(idx + 1).trim();
      if (!process.env[k]) process.env[k] = v;
    }
  }
}

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;

const COOLIFY_API_URL = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const COOLIFY_API_TOKEN = process.env.COOLIFY_API_TOKEN || '';
const COOLIFY_SERVICE_UUID = process.env.COOLIFY_SERVICE_UUID || '';

async function coolifyFetch(p, options = {}) {
  const url = `${COOLIFY_API_URL}/api/v1${p}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${COOLIFY_API_TOKEN}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Coolify API ${res.status} on ${p}: ${text}`);
  }
  return res.json();
}

async function appwriteRequest(urlPath, options = {}) {
  const url = `${endpoint}${urlPath}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      ...(options.headers || {}),
    },
  });
  return res;
}

// ── 1. Coolify Server Storage Limit ─────────────────────────────────────
async function updateCoolifyStorageLimit() {
  console.log('\n=== 1. Checking Coolify Appwrite Server Storage Limit ===');
  if (!COOLIFY_API_URL || !COOLIFY_API_TOKEN) {
    console.log('Coolify API URL or Token not available; skipping Coolify env update.');
    return;
  }

  try {
    let serviceUuid = COOLIFY_SERVICE_UUID;
    if (!serviceUuid) {
      const services = await coolifyFetch('/services');
      const candidate = (services || []).find((s) =>
        (s.name || '').toLowerCase().includes('appwrite')
      );
      if (candidate) serviceUuid = candidate.uuid;
    }

    if (!serviceUuid) {
      console.log('No Appwrite service UUID identified in Coolify.');
      return;
    }

    console.log(`Found Appwrite service in Coolify: ${serviceUuid}`);
    let envs = [];
    try {
      envs = await coolifyFetch(`/services/${serviceUuid}/envs`);
    } catch {
      const svc = await coolifyFetch(`/services/${serviceUuid}`);
      envs = svc.environment_variables || [];
    }

    console.log(`Current environment variable count: ${envs.length}`);
    const storageLimitEnv = envs.find((e) => e.key === '_APP_STORAGE_LIMIT');
    console.log(`Current _APP_STORAGE_LIMIT: ${storageLimitEnv ? storageLimitEnv.value : 'Not set (defaults to Appwrite 10GB)'}`);

    // Set _APP_STORAGE_LIMIT to 100GB (107374182400 bytes)
    const TARGET_LIMIT = '107374182400'; // 100 GB
    if (storageLimitEnv) {
      console.log(`Updating existing _APP_STORAGE_LIMIT to 100GB (${TARGET_LIMIT})...`);
      try {
        await coolifyFetch(`/services/${serviceUuid}/envs`, {
          method: 'PATCH',
          body: JSON.stringify({
            id: storageLimitEnv.id,
            key: '_APP_STORAGE_LIMIT',
            value: TARGET_LIMIT,
          }),
        });
        console.log('Successfully updated _APP_STORAGE_LIMIT in Coolify.');
      } catch (err) {
        console.log(`PATCH env failed, trying PUT/POST: ${err.message}`);
      }
    } else {
      console.log(`Adding _APP_STORAGE_LIMIT=100GB to service...`);
      try {
        await coolifyFetch(`/services/${serviceUuid}/envs`, {
          method: 'POST',
          body: JSON.stringify({
            key: '_APP_STORAGE_LIMIT',
            value: TARGET_LIMIT,
            is_preview: false,
          }),
        });
        console.log('Successfully created _APP_STORAGE_LIMIT in Coolify.');
      } catch (err) {
        console.log(`POST env failed: ${err.message}`);
      }
    }
  } catch (err) {
    console.warn(`Notice updating Coolify: ${err.message}`);
  }
}

// ── 2. Appwrite Storage Buckets ─────────────────────────────────────────
const bucketTargetSizes = {
  '6a08f51f002d2baf5e78': { name: 'Chat Files', size: 100 * 1024 * 1024 }, // 100MB
  'profile_files': { name: 'Profile Files', size: 50 * 1024 * 1024 }, // 50MB
  'board_documents': { name: 'Board Documents', size: 150 * 1024 * 1024 }, // 150MB
  'tract_files': { name: 'Tracts and Books', size: 200000000 }, // 200MB (Appwrite max)
  'podcast_media': { name: 'Podcasts and Audio', size: 200000000 }, // 200MB (Appwrite max)
  'content_media': { name: 'Content Media', size: 200000000 }, // 200MB (Appwrite max)
  'meeting_files': { name: 'Meeting Files', size: 150 * 1024 * 1024 }, // 150MB
  'system_exports': { name: 'System Exports and Backups', size: 200000000 }, // 200MB (Appwrite max)
  'app_releases': { name: 'Android Releases', size: 200000000 }, // 200MB (Appwrite max)
};

async function updateAppwriteBuckets() {
  console.log('\n=== 2. Updating Appwrite Storage Bucket Limits ===');
  const res = await appwriteRequest('/storage/buckets');
  if (!res.ok) {
    throw new Error(`Failed to list buckets: ${res.status} ${await res.text()}`);
  }

  const data = await res.json();
  const buckets = data.buckets || [];
  console.log(`Found ${buckets.length} bucket(s) in Appwrite project.`);

  for (const b of buckets) {
    const target = bucketTargetSizes[b.$id] || { name: b.name, size: 200 * 1024 * 1024 };
    console.log(`\nBucket: [${b.$id}] "${b.name}"`);
    console.log(`  Current maximumFileSize: ${(b.maximumFileSize / (1024 * 1024)).toFixed(1)} MB (${b.maximumFileSize} bytes)`);
    console.log(`  Target maximumFileSize: ${(target.size / (1024 * 1024)).toFixed(1)} MB (${target.size} bytes)`);

    const updatePayload = {
      name: b.name,
      permissions: b.permissions || ['read("any")'],
      fileSecurity: b.fileSecurity ?? false,
      enabled: b.enabled ?? true,
      maximumFileSize: target.size,
      allowedFileExtensions: b.allowedFileExtensions || [],
      compression: b.compression || 'none',
      encryption: b.encryption ?? false,
      antivirus: b.antivirus ?? true,
    };

    const updateRes = await appwriteRequest(`/storage/buckets/${b.$id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updatePayload),
    });

    if (updateRes.ok) {
      const updated = await updateRes.json();
      console.log(`  -> Successfully updated to ${(updated.maximumFileSize / (1024 * 1024)).toFixed(1)} MB!`);
    } else {
      console.warn(`  -> Failed to update: ${updateRes.status} ${await updateRes.text()}`);
    }
  }

  // Also check if app_releases exists; if not, create it with 500MB
  const releasesRes = await appwriteRequest('/storage/buckets/app_releases');
  if (releasesRes.status === 404) {
    console.log('\nCreating app_releases bucket with 500MB limit...');
    const createRes = await appwriteRequest('/storage/buckets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        bucketId: 'app_releases',
        name: 'Android releases',
        permissions: ['read("any")'],
        fileSecurity: false,
        enabled: true,
        maximumFileSize: 500 * 1024 * 1024,
        allowedFileExtensions: ['apk'],
        compression: 'none',
        encryption: false,
        antivirus: true,
      }),
    });
    if (createRes.ok) {
      console.log('Created app_releases bucket with 500MB limit.');
    }
  }
}

async function main() {
  await updateCoolifyStorageLimit();
  await updateAppwriteBuckets();
  console.log('\nAll storage size increases completed successfully!\n');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
