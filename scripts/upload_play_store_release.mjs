#!/usr/bin/env node
/**
 * Automated Google Play Store AAB Uploader (Android Publisher API v3)
 *
 * Uses zero external dependencies (pure Node.js crypto + fetch) to authenticate
 * with a Google Cloud Service Account linked to Google Play Console and upload
 * `build/app/outputs/bundle/release/app-release.aab` to the specified track.
 *
 * Setup:
 *   1. Place your Service Account JSON at `android/play-store-service-account.json`
 *      OR set `PLAY_STORE_SERVICE_ACCOUNT_PATH` / `PLAY_STORE_SERVICE_ACCOUNT_JSON` in `.env`.
 *   2. Run:
 *      node scripts/upload_play_store_release.mjs [internal|alpha|beta|production]
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

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

const PACKAGE_NAME = process.env.ANDROID_PACKAGE_NAME || 'com.alive.alivengandroidapp';
const TRACK = (process.argv[2] && !process.argv[2].startsWith('--'))
  ? process.argv[2]
  : (process.env.PLAY_STORE_TRACK || 'beta');
const CHECK_ONLY = process.argv.includes('--check');
const AAB_PATH = path.resolve(
  process.env.ANDROID_AAB_PATH || 'build/app/outputs/bundle/release/app-release.aab'
);

function getVersionName() {
  try {
    const content = fs.readFileSync('pubspec.yaml', 'utf8');
    const match = content.match(/^version:\s*([^\s+]+)/m);
    return match ? match[1] : '2.0.6';
  } catch {
    return '2.0.6';
  }
}

function loadServiceAccount() {
  if (process.env.PLAY_STORE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.PLAY_STORE_SERVICE_ACCOUNT_JSON);
  }
  const keyPath = path.resolve(
    process.env.PLAY_STORE_SERVICE_ACCOUNT_PATH || 'android/play-store-service-account.json'
  );
  if (!fs.existsSync(keyPath)) {
    throw new Error(
      `Service Account JSON not found at ${keyPath}.\n` +
        `Please download a Service Account JSON key from Google Cloud Console ` +
        `(linked to Google Play Console with Release Manager permissions) and save it at:\n` +
        `  android/play-store-service-account.json`
    );
  }
  return JSON.parse(fs.readFileSync(keyPath, 'utf8'));
}

async function getAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const claim = Buffer.from(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: sa.token_uri || 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })
  ).toString('base64url');

  const signer = crypto.createSign('RSA-SHA256');
  signer.update(`${header}.${claim}`);
  const signature = signer.sign(sa.private_key, 'base64url');
  const jwt = `${header}.${claim}.${signature}`;

  const res = await fetch(sa.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    throw new Error(`Failed to obtain Google OAuth token: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token;
}

async function main() {
  if (!CHECK_ONLY && !fs.existsSync(AAB_PATH)) {
    throw new Error(`AAB file not found at ${AAB_PATH}. Build the AAB first.`);
  }

  const sa = loadServiceAccount();
  console.log(`🔑 Authenticating with Google Play API as ${sa.client_email}...`);
  const token = await getAccessToken(sa);
  const baseUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}`;
  const uploadUrl = `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PACKAGE_NAME}`;

  // 1. Create a new Edit session
  console.log(`📝 Creating Play Store edit for ${PACKAGE_NAME}...`);
  const editRes = await fetch(`${baseUrl}/edits`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  if (!editRes.ok) {
    throw new Error(`Failed to create edit: ${editRes.status} ${await editRes.text()}`);
  }
  const edit = await editRes.json();
  const editId = edit.id;
  console.log(`✅ Edit created: ${editId}`);

  if (CHECK_ONLY) {
    const tracksRes = await fetch(`${baseUrl}/edits/${editId}/tracks`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (tracksRes.ok) {
      const tracksData = await tracksRes.json();
      console.log(`📊 Current Play Store Tracks:`, JSON.stringify(tracksData.tracks || [], null, 2));
    }
    await fetch(`${baseUrl}/edits/${editId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    console.log(`✅ Google Play Service Account verification succeeded!`);
    return;
  }

  // 2. Upload the AAB bundle
  const aabBuffer = fs.readFileSync(AAB_PATH);
  console.log(`📦 Uploading ${AAB_PATH} (${(aabBuffer.length / 1024 / 1024).toFixed(2)} MB)...`);
  const bundleRes = await fetch(`${uploadUrl}/edits/${editId}/bundles?uploadType=media`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/octet-stream',
    },
    body: aabBuffer,
  });
  if (!bundleRes.ok) {
    throw new Error(`Failed to upload AAB bundle: ${bundleRes.status} ${await bundleRes.text()}`);
  }
  const bundle = await bundleRes.json();
  const versionCode = bundle.versionCode;
  console.log(`✅ AAB uploaded! Version Code: ${versionCode}`);

  // 3. Assign the uploaded bundle to the target track
  const versionName = getVersionName();
  const releaseTitle = `${versionCode} (${versionName})`;
  console.log(`🚀 Assigning ${releaseTitle} to '${TRACK}' track...`);
  const trackRes = await fetch(`${baseUrl}/edits/${editId}/tracks/${TRACK}`, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      track: TRACK,
      releases: [
        {
          name: releaseTitle,
          versionCodes: [String(versionCode)],
          status: 'completed',
          releaseNotes: [
            {
              language: 'en-US',
              text:
                `What's New in v${versionName}:\n` +
                `• Smart First-Time Onboarding: Returning visitors skip straight to the app while new visitors enjoy the guided onboarding & commitment oath.\n` +
                `• Interactive Tracts & Dynamic Themes: Automatic PDF question/scripture extraction with 6 dynamic brand colour palettes.\n` +
                `• Admin Tenure Handover: Instant in-place officer email and name editing for seamless leadership transitions.\n` +
                `• Payment & UI Refinements: Synchronized Paystack configuration and responsive mobile card actions.`,
            },
          ],
        },
      ],
    }),
  });
  if (!trackRes.ok) {
    throw new Error(`Failed to update track '${TRACK}': ${trackRes.status} ${await trackRes.text()}`);
  }

  // 4. Commit the Edit
  console.log(`💾 Committing Play Store edit ${editId}...`);
  const commitRes = await fetch(`${baseUrl}/edits/${editId}:commit`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!commitRes.ok) {
    throw new Error(`Failed to commit edit: ${commitRes.status} ${await commitRes.text()}`);
  }

  console.log(`\n🎉 SUCCESS! Version Code ${versionCode} is now published to the '${TRACK}' track on Google Play!`);
}

main().catch((err) => {
  console.error('\n❌ Play Store Upload Error:', err.message);
  process.exit(1);
});

