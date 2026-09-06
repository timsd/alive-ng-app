import fs from 'node:fs';
import path from 'node:path';
import * as appwriteSdk from 'node-appwrite';

const { Client, Storage, ID, InputFile, Permission, Role } = appwriteSdk;
const bucketId = 'app_releases';
const fileId = 'alive_ng_android_release';
const localArtifact = path.resolve('build/app/outputs/flutter-apk/app-release.apk');
const externalArtifact = 'E:\\alive-ng-release-artifacts\\app-release.apk';
const artifactPath = process.env.ANDROID_RELEASE_ARTIFACT
  ?? (fs.existsSync(localArtifact) ? localArtifact : externalArtifact);

for (const name of ['APPWRITE_ENDPOINT', 'APPWRITE_PROJECT_ID', 'APPWRITE_API_KEY']) {
  if (!process.env[name]) {
    throw new Error(`${name} must be available through .env or the environment.`);
  }
}

if (!fs.existsSync(artifactPath)) {
  throw new Error(`Android release artifact was not found: ${artifactPath}`);
}

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT)
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);
const storage = new Storage(client);
const publicPermissions = [Permission.read(Role.any())];

async function ensureReleaseBucket() {
  try {
    await storage.getBucket({ bucketId });
    await storage.updateBucket({
      bucketId,
      name: 'Android releases',
      permissions: publicPermissions,
      fileSecurity: false,
      enabled: true,
      maximumFileSize: 200000000,
      allowedFileExtensions: ['apk'],
      compression: 'none',
      encryption: false,
      antivirus: true,
    });
    console.log(`Release bucket ${bucketId} is ready.`);
  } catch (error) {
    if (error.code !== 404) throw error;
    await storage.createBucket({
      bucketId,
      name: 'Android releases',
      permissions: publicPermissions,
      fileSecurity: false,
      enabled: true,
      maximumFileSize: 200000000,
      allowedFileExtensions: ['apk'],
      compression: 'none',
      encryption: false,
      antivirus: true,
    });
    console.log(`Created release bucket ${bucketId}.`);
  }
}

await ensureReleaseBucket();
try {
  await storage.deleteFile({ bucketId, fileId });
  console.log('Replacing existing Android release.');
} catch (error) {
  if (error.code !== 404) throw error;
}
const stat = fs.statSync(artifactPath);
const file = await storage.createFile({
  bucketId,
  fileId,
  file: InputFile.fromPath(artifactPath, path.basename(artifactPath)),
  permissions: publicPermissions,
});
const endpoint = process.env.APPWRITE_ENDPOINT.replace(/\/$/, '');
const url = `${endpoint}/storage/buckets/${bucketId}/files/${file.$id}/download?project=${encodeURIComponent(process.env.APPWRITE_PROJECT_ID)}`;
console.log(`Uploaded ${file.name} (${stat.size} bytes).`);
console.log(`ANDROID_APK_URL=${url}`);
