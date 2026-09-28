// Reports how Coolify is configured to build this app: from the Dockerfile on
// the instance, or by pulling a prebuilt image from GHCR.
//
// This matters because the Oracle instance is 2 OCPU and also runs Appwrite,
// MariaDB, Redis and nginx. Building the Flutter bundle there saturates the CPU
// and nginx stops completing TLS handshakes, which is what caused the earlier
// 504s. Building in GitHub Actions and pulling the image avoids that entirely.
//
//   node scripts/check_coolify_packager.mjs
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
}

const base = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const token = process.env.COOLIFY_API_TOKEN;
if (!base || !token) {
  console.log('Missing COOLIFY_API_URL or COOLIFY_API_TOKEN in .env');
  process.exit(1);
}
const headers = { Authorization: `Bearer ${token}`, Accept: 'application/json' };

const appRes = await fetch(`${base}/api/v1/applications/${process.env.COOLIFY_SERVICE_UUID}`, { headers });
if (!appRes.ok) {
  console.log(`ERROR ${appRes.status}: ${(await appRes.text()).slice(0, 300)}`);
  process.exit(1);
}
const app = await appRes.json();

console.log(`application: ${app.name} (${app.uuid})\n`);
console.log(`  build_pack        : ${app.build_pack ?? '(unset -> Dockerfile)'}`);
console.log(`  docker_image      : ${app.docker_image || '(none)'}`);
console.log(`  dockerfile        : ${app.dockerfile || '(none)'}`);
console.log(`  github_app_id     : ${app.github_app_id ?? '(none)'}`);
console.log(`  github_repository : ${app.github_repository ?? '(none)'}`);
console.log(`  github_branch     : ${app.github_branch ?? '(none)'}`);
console.log(`  watch paths       : ${app.watch_paths || '(none)'}`);

const buildingOnInstance =
  !app.github_app_id && !app.docker_image && app.build_pack !== 'nixpacks-static';
console.log('');
if (buildingOnInstance) {
  console.log('  VERDICT: builds on the Oracle instance from source.');
  console.log('  That is the configuration that caused the CPU saturation and 504s.');
  console.log('  To fix: connect a GitHub repository + point Packager at the GHCR image,');
  console.log('  or build locally and set docker_image to the ghcr tag.');
} else {
  console.log('  VERDICT: does NOT build Flutter on the instance (image or repo is set).');
  console.log('  Check the Build tab in the UI to confirm the image actually resolves.');
}
