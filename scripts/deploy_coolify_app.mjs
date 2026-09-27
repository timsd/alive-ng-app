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

// Coolify exposes several deploy entry points depending on version. Try them in
// order and stop at the first that is accepted.
const attempts = [
  ['POST', `/deploy?uuid=${uuid}`],
  ['POST', `/applications/${uuid}/deploy`],
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
