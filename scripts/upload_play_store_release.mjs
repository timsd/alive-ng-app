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
const AUDIT_ONLY = process.argv.includes('--audit');
const UPDATE_LISTING_ONLY = process.argv.includes('--update-listing');
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
  if (!CHECK_ONLY && !AUDIT_ONLY && !UPDATE_LISTING_ONLY && !fs.existsSync(AAB_PATH)) {
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

  if (UPDATE_LISTING_ONLY) {
    console.log(`📝 Updating Store Listing (en-US) title and full description...`);
    const listingPayload = {
      language: 'en-US',
      title: 'ALIVE Nigeria (ALIVE-NG)',
      shortDescription:
        'Bible study, daily verses, prayer rooms, missions & community for ALIVE Nigeria',
      fullDescription:
        `ALIVE Nigeria (ALIVE-NG) is the official mobile app for ALIVE Nigeria Ministry — a vibrant community dedicated to spiritual growth, evangelism, and discipleship. Whether you're studying the Bible, leading an interactive tract study, joining a prayer room, or connecting with your chapter, ALIVE-NG puts your entire spiritual journey in your pocket.\n\n` +
        `📖 BIBLE STUDY & 9 TRANSLATIONS\n` +
        `• Read the Bible offline and online across 9 translations: NKJV, KJV, NIV, NLT, NASB, ASV, plus Yoruba (BM), Hausa (HAU), and Igbo (IGBOB)\n` +
        `• Receive a fresh daily verse with shareable scripture cards in English and Nigerian languages\n` +
        `• Follow structured study guides and interactive lessons\n` +
        `• Track your reading progress and streaks\n\n` +
        `🤝 DISCIPLESHIP & SOUL-WINNING TRACKER\n` +
        `• Interactive Evangelism Tracts with clickable Bible references and reflection prompts\n` +
        `• Manage prospects and contacts with one-tap phone call, SMS, and email follow-ups\n` +
        `• Track study sessions, spiritual decisions, and automatically dispatch reports to Chapter Coordinators and Directors\n\n` +
        `🙏 PRAYER & TESTIMONIES\n` +
        `• Join real-time audio prayer rooms\n` +
        `• Submit and track prayer requests\n` +
        `• Share testimonies of answered prayers\n` +
        `• Access the prayer strengthening feed for daily encouragement\n\n` +
        `🎯 MISSIONS & EVANGELISM\n` +
        `• Access interactive tracts and study lessons with dynamic colour themes\n` +
        `• Support and participate in nationwide missions, outreaches, and humanitarian projects\n` +
        `• Track your mission activities and download evangelism materials\n\n` +
        `🏛️ CHAPTERS & COMMUNITY\n` +
        `• Connect with your local ALIVE Nigeria chapter\n` +
        `• Real-time chat with community members\n` +
        `• Stay updated with announcements, events, and chapter reports\n\n` +
        `🎧 PODCASTS & MEDIA\n` +
        `• Listen to ALIVE Nigeria podcasts and teaching series\n` +
        `• Access video content, devotionals, and digital library resources\n\n` +
        `💰 DONATIONS & GIVING\n` +
        `• Support ministry projects through secure payments\n` +
        `• Track donation history, project progress, and instant receipts\n\n` +
        `🌍 MULTILINGUAL SUPPORT\n` +
        `• Full support for English, Yoruba, Igbo, and Hausa\n` +
        `• Dynamic language switching throughout the app\n\n` +
        `🛡️ HEALTH & WELLNESS\n` +
        `• Access health tips, medical mission updates, and wellness resources\n\n` +
        `ALIVE Nigeria (ALIVE-NG) is built for every member of the ALIVE Nigeria family — from new converts and disciple makers to chapter coordinators, directors, and trustees. Join us in transforming lives through the Gospel!\n\n` +
        `Website: https://alivenigeria.org\n` +
        `Portal: https://app.alivenigeria.org`,
    };

    const putListingRes = await fetch(`${baseUrl}/edits/${editId}/listings/en-US`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(listingPayload),
    });
    if (!putListingRes.ok) {
      throw new Error(`Failed to update listing: ${putListingRes.status} ${await putListingRes.text()}`);
    }
    console.log(`✅ Store Listing (en-US) updated to 'ALIVE Nigeria (ALIVE-NG)'!`);

    // Check sevenInchScreenshots and populate from tenInchScreenshots or store_assets
    const sevenRes = await fetch(`${baseUrl}/edits/${editId}/listings/en-US/sevenInchScreenshots`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const sevenData = sevenRes.ok ? await sevenRes.json() : { images: [] };
    if ((sevenData.images || []).length === 0) {
      console.log(`🖼️  Populating sevenInchScreenshots...`);
      const tenRes = await fetch(`${baseUrl}/edits/${editId}/listings/en-US/tenInchScreenshots`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const tenData = tenRes.ok ? await tenRes.json() : { images: [] };
      const tenImages = tenData.images || [];

      let uploadedCount = 0;
      if (tenImages.length > 0) {
        for (const img of tenImages) {
          if (!img.url) continue;
          const imgResp = await fetch(img.url);
          if (!imgResp.ok) continue;
          const contentType = imgResp.headers.get('content-type') || 'image/png';
          const buf = Buffer.from(await imgResp.arrayBuffer());
          const upRes = await fetch(
            `${uploadUrl}/edits/${editId}/listings/en-US/sevenInchScreenshots?uploadType=media`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': contentType,
              },
              body: buf,
            }
          );
          if (upRes.ok) {
            uploadedCount++;
            console.log(`  ✅ Copied tablet screenshot ${uploadedCount}/${tenImages.length} to sevenInchScreenshots`);
          } else {
            console.warn(`  ⚠️ Screenshot upload warning: ${upRes.status} ${await upRes.text()}`);
          }
        }
      }

      // Fallback to store_assets/*.jpg if needed
      if (uploadedCount === 0 && fs.existsSync('store_assets')) {
        const files = fs
          .readdirSync('store_assets')
          .filter((f) => /\.(jpg|jpeg|png)$/i.test(f) && !/icon|feature/i.test(f))
          .slice(0, 8);
        for (const file of files) {
          const filePath = path.join('store_assets', file);
          const buf = fs.readFileSync(filePath);
          const contentType = file.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
          const upRes = await fetch(
            `${uploadUrl}/edits/${editId}/listings/en-US/sevenInchScreenshots?uploadType=media`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${token}`,
                'Content-Type': contentType,
              },
              body: buf,
            }
          );
          if (upRes.ok) {
            uploadedCount++;
            console.log(`  ✅ Uploaded ${file} (${uploadedCount}/${files.length}) to sevenInchScreenshots`);
          }
        }
      }
    } else {
      console.log(`ℹ️  sevenInchScreenshots already has ${sevenData.images.length} images.`);
    }

    console.log(`💾 Committing Store Listing & Screenshot updates...`);
    const commitRes = await fetch(`${baseUrl}/edits/${editId}:commit`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!commitRes.ok) {
      throw new Error(`Failed to commit listing edit: ${commitRes.status} ${await commitRes.text()}`);
    }
    console.log(`🎉 Store Listing & 7-inch Tablet Screenshots committed to Google Play!`);
    return;
  }

  if (CHECK_ONLY || AUDIT_ONLY) {
    if (AUDIT_ONLY) {
      // 1. App Details
      const detailsRes = await fetch(`${baseUrl}/edits/${editId}/details`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      console.log(`\n📌 APP DETAILS:`, detailsRes.ok ? await detailsRes.json() : await detailsRes.text());

      // 2. Store Listings
      const listingsRes = await fetch(`${baseUrl}/edits/${editId}/listings`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      const listingsData = listingsRes.ok ? await listingsRes.json() : null;
      console.log(`\n📝 STORE LISTINGS:`, JSON.stringify(listingsData, null, 2));

      // 3. Images per listing language
      const langs = (listingsData?.listings || []).map((l) => l.language);
      if (langs.length === 0) langs.push('en-US');
      const imageTypes = [
        'icon',
        'featureGraphic',
        'phoneScreenshots',
        'sevenInchScreenshots',
        'tenInchScreenshots',
        'promoGraphic',
        'tvBanner',
      ];
      for (const lang of langs) {
        console.log(`\n🖼️  IMAGES FOR [${lang}]:`);
        for (const imgType of imageTypes) {
          const imgRes = await fetch(`${baseUrl}/edits/${editId}/listings/${lang}/${imgType}`, {
            headers: { Authorization: `Bearer ${token}` },
          });
          if (imgRes.ok) {
            const imgData = await imgRes.json();
            const count = (imgData.images || []).length;
            console.log(`  - ${imgType}: ${count} image(s)`);
          }
        }
      }

      // 4. Uploaded Bundles
      const bundlesRes = await fetch(`${baseUrl}/edits/${editId}/bundles`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (bundlesRes.ok) {
        const bundlesData = await bundlesRes.json();
        console.log(`\n📦 UPLOADED BUNDLES:`, JSON.stringify(bundlesData.bundles || [], null, 2));
      }
    }

    const tracksRes = await fetch(`${baseUrl}/edits/${editId}/tracks`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (tracksRes.ok) {
      const tracksData = await tracksRes.json();
      console.log(`\n📊 CURRENT PLAY STORE TRACKS:`, JSON.stringify(tracksData.tracks || [], null, 2));
    }
    await fetch(`${baseUrl}/edits/${editId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    console.log(`\n✅ Google Play audit completed (no changes made).`);
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
                `• Leadership Directory: Centralized directory for Board of Trustees, Directors, and Ministry Leadership with linked account bindings.\n` +
                `• Board of Directors Portal: Streamlined meeting resolutions, decisions, and governance tools.\n` +
                `• Secure Live Payments: Direct live Paystack integration for seamless donations and ministry support.\n` +
                `• ALIVE Meet & Scribe: Unified conference controls, automated minutes sync, and low-latency meeting collaboration.`,
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

