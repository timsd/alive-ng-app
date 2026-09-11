import fs from 'node:fs';
import path from 'node:path';

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

const bucketId = 'app_releases';
const fileId = 'alive_ng_android_release';
const localArtifact = path.resolve('build/app/outputs/flutter-apk/app-release.apk');
const artifactPath = process.env.ANDROID_RELEASE_ARTIFACT ?? localArtifact;

for (const name of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY']) {
  if (!process.env[name]) {
    throw new Error(`${name} must be available through .env or the environment.`);
  }
}

const endpoint = process.env.APPWRITE_ENDPOINT.replace(/\/$/, '');
const projectId = process.env.APPWRITE_PROJECT_ID;
const apiKey = process.env.APPWRITE_API_KEY;

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
};

async function appwriteRequest(urlPath, options = {}) {
  const url = `${endpoint}${urlPath}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers || {}),
    },
  });
  return res;
}

async function ensureReleaseBucket() {
  const bucketPayload = {
    name: 'Android releases',
    permissions: ['read("any")'],
    fileSecurity: false,
    enabled: true,
    maximumFileSize: 200000000,
    allowedFileExtensions: ['apk'],
    compression: 'none',
    encryption: false,
    antivirus: true,
  };

  const getRes = await appwriteRequest(`/storage/buckets/${bucketId}`);
  if (getRes.status === 404) {
    const createRes = await appwriteRequest('/storage/buckets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ bucketId, ...bucketPayload }),
    });
    if (!createRes.ok) {
      throw new Error(`Failed to create bucket: ${createRes.status} ${await createRes.text()}`);
    }
    console.log(`Created release bucket ${bucketId}.`);
  } else if (getRes.ok) {
    const updateRes = await appwriteRequest(`/storage/buckets/${bucketId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(bucketPayload),
    });
    if (!updateRes.ok) {
      console.warn(`Warning updating bucket: ${updateRes.status}`);
    }
    console.log(`Release bucket ${bucketId} is ready.`);
  }
}

async function deleteExistingRelease() {
  console.log(`Checking and deleting previous release ${fileId}...`);
  const delRes = await appwriteRequest(`/storage/buckets/${bucketId}/files/${fileId}`, {
    method: 'DELETE',
  });
  if (delRes.ok) {
    console.log(`PREVIOUS_UPLOAD_DELETED: Existing release ${fileId} deleted successfully.`);
  } else if (delRes.status === 404) {
    console.log(`No existing release ${fileId} found (already deleted).`);
  } else {
    console.warn(`Delete returned status ${delRes.status}: ${await delRes.text()}`);
  }
}

async function uploadRelease() {
  if (!fs.existsSync(artifactPath)) {
    throw new Error(`Android release artifact was not found at: ${artifactPath}. Please build the APK first.`);
  }

  const stat = fs.statSync(artifactPath);
  console.log(`Reading APK artifact from ${artifactPath} (${stat.size} bytes)...`);

  const fileBuffer = fs.readFileSync(artifactPath);
  const blob = new Blob([fileBuffer], { type: 'application/vnd.android.package-archive' });

  const formData = new FormData();
  formData.append('fileId', fileId);
  formData.append('file', blob, 'ALIVE-Nigeria-App-v2.0.1.apk');
  formData.append('permissions[]', 'read("any")');

  console.log('Uploading ALIVE-NG-App.apk to Appwrite Storage...');
  const uploadRes = await appwriteRequest(`/storage/buckets/${bucketId}/files`, {
    method: 'POST',
    body: formData,
  });

  if (!uploadRes.ok) {
    throw new Error(`Upload failed (${uploadRes.status}): ${await uploadRes.text()}`);
  }

  const data = await uploadRes.json();
  const downloadUrl = `${endpoint}/storage/buckets/${bucketId}/files/${data.$id}/download?project=${encodeURIComponent(projectId)}`;

  console.log(`\n========================================`);
  console.log(`SUCCESS: Uploaded ${data.name} (${stat.size} bytes)`);
  console.log(`ANDROID_APK_URL=${downloadUrl}`);
  console.log(`========================================\n`);
}

async function main() {
  await ensureReleaseBucket();
  await deleteExistingRelease();

  if (process.argv.includes('--delete-only')) {
    console.log('Finished delete-only action.');
    return;
  }

  await uploadRelease();
}

main().catch((err) => {
  console.error('\nERROR:', err.message);
  process.exit(1);
});
