// Triggers a Coolify deploy for the ALIVE Flutter Web application.
//
// The Git webhook is not enabled on that service, so pushes to master do not
// build anything. This asks Coolify to deploy the current commit instead, so
// the web app can ship without touching the Coolify UI.
//
//   node scripts/deploy_coolify_app.mjs
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
const uuid = process.env.COOLIFY_SERVICE_UUID;

if (!base || !token || !uuid) {
  throw new Error('Missing COOLIFY_API_URL / COOLIFY_API_TOKEN / COOLIFY_SERVICE_UUID');
}

const call = async (method, path, body) => {
  const res = await fetch(`${base}/api/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  return { status: res.status, text };
};

const force = process.argv.includes('--force') || process.argv.includes('--no-cache') || false;

// 1. Guard against concurrent builds: Wait for any running build to finish before dispatching a new one
try {
  const activeCheck = await call('GET', '/deployments');
  if (activeCheck.status === 200) {
    const list = JSON.parse(activeCheck.text);
    if (Array.isArray(list) && list.length > 0) {
      console.log(`⏳ A build is already in progress on Coolify (#${list[0].id} - ${list[0].commit?.slice(0, 8)}). Waiting for it to finish...`);
      let waitCount = 0;
      while (waitCount < 30) {
        await new Promise((r) => setTimeout(r, 10000));
        waitCount++;
        const poll = await call('GET', '/deployments');
        if (poll.status === 200) {
          const activeList = JSON.parse(poll.text);
          if (!Array.isArray(activeList) || activeList.length === 0) {
            console.log('✅ Previous build completed. Proceeding with deployment...');
            break;
          }
          console.log(`... still waiting for build #${activeList[0].id} (${waitCount * 10}s elapsed)`);
        }
      }
    }
  }
} catch (guardErr) {
  console.log('Build concurrency check note:', guardErr.message);
}

// Coolify exposes several deploy entry points depending on version. Try them in
// order and stop at the first that is accepted.
const attempts = [
  ['POST', `/deploy?uuid=${uuid}${force ? '&force=true' : ''}`],
  ['POST', `/applications/${uuid}/deploy${force ? '?force=true' : ''}`],
  ['GET', `/applications/${uuid}`],
];

for (const [method, path] of attempts) {
  const r = await call(method, path);
  console.log(`${method} ${path} -> ${r.status} ${r.text.slice(0, 220)}`);
  if (r.status >= 200 && r.status < 300 && !path.startsWith('/applications/')) {
    console.log('\nDeploy accepted. Poll the Coolify UI or re-run this script.');
    process.exit(0);
  }
}
