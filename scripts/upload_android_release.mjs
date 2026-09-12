import fs from 'node:fs';
import path from 'node:path';
import { Client, Storage, Permission, Role } from 'node-appwrite';
import { InputFile } from 'node-appwrite/file';

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

function getAppVersion() {
  try {
    const content = fs.readFileSync('pubspec.yaml', 'utf8');
    const match = content.match(/^version:\s*([^\s+]+)/m);
    return match ? match[1] : '2.0.2';
  } catch {
    return '2.0.2';
  }
}

const releaseFileName = `alive-ng-app-v${getAppVersion()}.apk`;

async function uploadRelease() {
  if (!fs.existsSync(artifactPath)) {
    throw new Error(`Android release artifact was not found at: ${artifactPath}. Please build the APK first.`);
  }

  const stat = fs.statSync(artifactPath);
  const totalSize = stat.size;
  const CHUNK_SIZE = 5 * 1024 * 1024; // 5 MB per chunk
  const totalChunks = Math.ceil(totalSize / CHUNK_SIZE);

  console.log(`Uploading ${artifactPath} (${totalSize} bytes) as ${releaseFileName} in ${totalChunks} chunk(s)...`);

  const fd = fs.openSync(artifactPath, 'r');
  let start = 0;
  let chunkIndex = 0;
  let uploadResult = null;

  try {
    while (start < totalSize) {
      let end = start + CHUNK_SIZE;
      if (end > totalSize) end = totalSize;
      const chunkSize = end - start;

      const buffer = Buffer.alloc(chunkSize);
      fs.readSync(fd, buffer, 0, chunkSize, start);
      const blob = new Blob([buffer], { type: 'application/vnd.android.package-archive' });

      const formData = new FormData();
      formData.append('fileId', fileId);
      formData.append('file', blob, releaseFileName);
      if (chunkIndex === 0) {
        formData.append('permissions[]', 'read("any")');
      }

      const reqHeaders = {
        'Content-Range': `bytes ${start}-${end - 1}/${totalSize}`,
      };
      if (uploadResult && uploadResult.$id) {
        reqHeaders['x-appwrite-id'] = uploadResult.$id;
      }

      let res;
      let retries = 4;
      while (retries > 0) {
        res = await appwriteRequest(`/storage/buckets/${bucketId}/files`, {
          method: 'POST',
          headers: reqHeaders,
          body: formData,
        });
        if (res.ok) break;
        retries--;
        if (retries > 0) {
          console.warn(`Chunk ${chunkIndex + 1} got HTTP ${res.status}. Retrying in 4s (${retries} attempts left)...`);
          await new Promise((r) => setTimeout(r, 4000));
        }
      }

      if (!res.ok) {
        const errorText = await res.text();
        throw new Error(`Upload failed on chunk ${chunkIndex + 1}/${totalChunks} (HTTP ${res.status}): ${errorText}`);
      }

      uploadResult = await res.json();
      chunkIndex++;
      const progress = Math.round((end / totalSize) * 100);
      console.log(`Chunk ${chunkIndex}/${totalChunks} uploaded (${progress}%, ${end}/${totalSize} bytes)`);

      start = end;
    }
  } finally {
    fs.closeSync(fd);
  }

  // Ensure public read permissions are persisted on the uploaded file
  try {
    await appwriteRequest(`/storage/buckets/${bucketId}/files/${uploadResult.$id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ permissions: ['read("any")'] }),
    });
    console.log('Public read permissions confirmed on uploaded APK.');
  } catch (permErr) {
    console.warn('Notice on file permissions update:', permErr.message);
  }

  const downloadUrl = `${endpoint}/storage/buckets/${bucketId}/files/${uploadResult.$id}/download?project=${encodeURIComponent(projectId)}`;

  console.log(`\n========================================`);
  console.log(`SUCCESS: Uploaded ${uploadResult.name} (${uploadResult.sizeOriginal || totalSize} bytes)`);
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
  if (err.cause) console.error('CAUSE:', err.cause);
  if (err.response) console.error('RESPONSE:', err.response);
  process.exit(1);
});
