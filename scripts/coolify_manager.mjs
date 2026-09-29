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
  console.error('Missing COOLIFY config');
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${token}`,
  Accept: 'application/json',
  'Content-Type': 'application/json',
};

async function get(path) {
  const res = await fetch(`${base}/api/v1${path}`, { headers });
  const text = await res.text();
  try {
    return { status: res.status, data: JSON.parse(text) };
  } catch {
    return { status: res.status, raw: text };
  }
}

async function post(path, body) {
  const res = await fetch(`${base}/api/v1${path}`, {
    method: 'POST',
    headers,
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  try {
    return { status: res.status, data: JSON.parse(text) };
  } catch {
    return { status: res.status, raw: text };
  }
}

async function main() {
  const arg = process.argv[2] || 'status';
  console.log(`Querying Coolify for app ${uuid}...`);

  if (arg === 'app') {
    const app = await get(`/applications/${uuid}`);
    console.log('App info:', JSON.stringify(app.data, null, 2));
  } else if (arg === 'envs') {
    const envs = await get(`/applications/${uuid}/envs`);
    console.log('Envs:', JSON.stringify(envs.data, null, 2));
  } else if (arg === 'set-build-id') {
    const buildId = String(Date.now());
    const envs = await get(`/applications/${uuid}/envs`);
    const existing = (envs.data || []).find(e => e.key === 'BUILD_ID');
    if (existing) {
      console.log(`Updating existing BUILD_ID (${existing.uuid}) to ${buildId}...`);
      const res = await (await fetch(`${base}/api/v1/applications/${uuid}/envs`, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ key: 'BUILD_ID', value: buildId })
      })).json();
      console.log('Update result:', res);
    } else {
      console.log(`Creating BUILD_ID=${buildId}...`);
      const res = await post(`/applications/${uuid}/envs`, {
        key: 'BUILD_ID',
        value: buildId,
        is_buildtime: true,
        is_runtime: false,
        is_preview: false,
      });
      console.log('Create result:', res);
    }
  } else if (arg === 'deploy') {
    const force = process.argv.includes('--force') || process.argv.includes('force');
    const path = `/deploy?uuid=${uuid}` + (force ? '&force=true' : '');
    console.log(`Triggering deploy (force=${force}) at ${path}...`);
    const res = await post(path);
    console.log('Result:', JSON.stringify(res, null, 2));
    if (res.data?.deployments?.[0]?.deployment_uuid) {
      console.log(`Deployment UUID: ${res.data.deployments[0].deployment_uuid}`);
    }
  } else if (arg === 'deployments') {
    const deploys = await get(`/deployments`);
    console.log('Deployments:', JSON.stringify(deploys.data, null, 2));
  } else if (arg === 'logs') {
    const depUuid = process.argv[3];
    if (depUuid) {
      const dep = await get(`/deployments/${depUuid}`);
      console.log('Logs:\n', dep.data?.logs || '(no logs)');
    }
  } else if (arg === 'status') {
    // Check recent deployment status
    const app = await get(`/applications/${uuid}`);
    console.log(`App: ${app.data?.name} (Status: ${app.data?.status})`);
    console.log(`Git: ${app.data?.git_repository} @ ${app.data?.git_branch} (Commit: ${app.data?.git_commit_sha || 'HEAD'})`);
    console.log(`FQDN: ${app.data?.fqdn}`);
    
    // Check deployment if param passed
    const depUuid = process.argv[3];
    if (depUuid) {
      const dep = await get(`/deployments/${depUuid}`);
      console.log('Deployment info:', JSON.stringify(dep.data, null, 2));
    }
  }
}

main().catch(console.error);
