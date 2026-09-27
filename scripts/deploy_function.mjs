// Deploys bind_office_on_signup via the REST API.
//
// Why not `appwrite push`: the CLI reads each function's rules to diff for
// changes, and the project's API key has no `rules.read` scope, so every push
// aborts with "missing scopes (["rules.read"])". The REST path only needs
// functions.write, so this does the same job the CLI would.
//
//   node scripts/deploy_function.mjs <functionId> [functionDir]
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import os from 'node:os';
import { mkdtempSync, rmSync } from 'node:fs';
import crypto from 'node:crypto';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
}

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const project = process.env.APPWRITE_PROJECT_ID;
const key = process.env.APPWRITE_API_KEY;

if (!endpoint || !project || !key) {
  console.error('APPWRITE_ENDPOINT / PROJECT_ID / API_KEY are not all set');
  process.exit(1);
}

const functionId = process.argv[2];
const dir = resolve(process.cwd(), process.argv[3] || `appwrite_functions/${functionId}`);
if (!functionId) {
  console.error('usage: node scripts/deploy_function.mjs <functionId> [functionDir]');
  process.exit(1);
}

const authHeaders = {
  'X-Appwrite-Project': project,
  'X-Appwrite-Key': key,
};

const json = async (method, path, body) => {
  const res = await fetch(`${endpoint}/v1${path}`, {
    method,
    headers: { ...authHeaders, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const t = await res.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  if (res.status >= 300) throw new Error(`${method} ${path} -> ${res.status}: ${t.slice(0, 300)}`);
  return j;
};

const tmp = mkdtempSync(resolve(os.tmpdir(), 'appwrite-deploy-'));
let tarball;
try {
  tarball = resolve(tmp, 'src.tar.gz');
  console.log(`packing ${dir} ...`);
  execFileSync('tar', ['-czf', tarball, '-C', dir, '.'], { stdio: 'inherit' });

  // 1. Upload the source bundle.
  const bytes = readFileSync(tarball);
  console.log(`uploading ${bytes.length} bytes ...`);
  // Appwrite posts the source to /functions/{id}/deployments as multipart form
  // data with the tarball in a `code` field. Going through the SDK keeps the
  // field names and path in step with the installed version instead of us
  // guessing them.
  // In the 1.8+ SDK there is no separate createUpload step: the tarball goes
  // straight into the `code` field and the SDK posts it as multipart form data
  // to /functions/{id}/deployments.
  //
  // It must be a `File` instance -- chunkedUpload looks for `value instanceof
  // File` and throws "File not found in payload" for a Buffer or Blob.
  // Appwrite takes the source as multipart form data on
  // POST /functions/{id}/deployments, with the tarball in a `code` field and
  // entrypoint/commands/activate alongside it.
  //
  // This is hand-rolled rather than done through the Functions service because
  // the installed SDK routes its upload through node-fetch-native-with-agent,
  // which throws "invalid onError method" on Node 26. Native fetch works.
  console.log('starting build ...');
  const form = new FormData();
  form.append('code', new File([bytes], 'src.tar.gz', { type: 'application/gzip' }));
  form.append('entrypoint', 'src/main.js');
  form.append('commands', 'npm install');
  form.append('activate', 'true');

  // The function's execution timeout has to cover its internal retries, and
  // the deployment route does not accept it, so set it on the function.
  // Default 60s: bindOfficeOnSignup retries a user lookup with backoff.
  const desiredTimeout = process.env.DEPLOY_TIMEOUT || '60';
  const currentFn = await json('GET', `/functions/${functionId}`);
  if (String(currentFn.timeout) !== desiredTimeout) {
    // Appwrite updates a function with PUT, not PATCH, and PUT requires the
    // full configuration -- sending only `timeout` fails with
    // 'Param "name" is not optional'. So echo the current config back with the
    // one field changed.
    const upd = await fetch(`${endpoint}/v1/functions/${functionId}`, {
      method: 'PUT',
      headers: { ...authHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: currentFn.name,
        runtime: currentFn.runtime,
        execute: currentFn.execute,
        events: currentFn.events,
        schedule: currentFn.schedule,
        timeout: Number(desiredTimeout),
        enabled: currentFn.enabled,
        logging: currentFn.logging,
        entrypoint: currentFn.entrypoint,
        commands: currentFn.commands,
        scopes: currentFn.scopes,
        buildSpecification: currentFn.buildSpecification,
        runtimeSpecification: currentFn.runtimeSpecification,
        deploymentRetention: currentFn.deploymentRetention,
      }),
    });
    const updText = await upd.text();
    console.log(`timeout ${currentFn.timeout}s -> ${desiredTimeout}s => ${upd.status} ${updText.slice(0, 200)}`);
  }

  const buildRes = await fetch(`${endpoint}/v1/functions/${functionId}/deployments`, {
    method: 'POST',
    headers: { ...authHeaders },
    body: form,
  });
  const buildText = await buildRes.text();
  if (!buildRes.ok) throw new Error(`deploy -> ${buildRes.status}: ${buildText.slice(0, 400)}`);
  const build = JSON.parse(buildText);
  console.log(`deployment: ${build.$id} (${build.status})`);

  // Poll until the function's latest deployment settles.
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const f = await json('GET', `/functions/${functionId}`);
    const status = f.latestDeploymentStatus;
    console.log(`  ${(i + 1) * 5}s  latest=${status}`);
    if (['ready', 'failed'].includes(status)) {
      console.log(status === 'ready' ? '\nDEPLOYED' : '\nBUILD FAILED');
      if (status === 'failed') {
        const dep = await json(
          'GET',
          `/functions/${functionId}/deployments/${f.latestDeploymentId}`,
        ).catch(() => null);
        for (const b of (dep?.buildLogs || []).slice(-40)) console.log(`  build | ${b}`);
      }
      process.exit(status === 'ready' ? 0 : 1);
    }
  }
  console.log('\ntimed out waiting for the build');
  process.exit(1);
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
