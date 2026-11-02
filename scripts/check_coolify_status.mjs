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

const headers = { Authorization: `Bearer ${token}`, Accept: 'application/json' };

let depId = process.argv[2];
if (!depId) {
  // Fetch latest deployment for this application
  const appDepsRes = await fetch(`${base}/api/v1/applications/${uuid}/deployments`, { headers });
  if (appDepsRes.ok) {
    const list = await appDepsRes.json();
    if (list && list.length > 0) {
      depId = list[0].deployment_uuid || list[0].id;
    }
  }
}

if (!depId) {
  console.log('No deployment id found');
  process.exit(1);
}

const singleRes = await fetch(`${base}/api/v1/deployments/${depId}`, { headers });
if (singleRes.ok) {
  const single = await singleRes.json();
  console.log('Single deployment check:', {
    id: single.id,
    commit: single.commit?.slice(0, 8),
    status: single.status,
    finished_at: single.finished_at,
    created_at: single.created_at,
    updated_at: single.updated_at
  });
  if (single.logs) {
    try {
      const logs = JSON.parse(single.logs);
      const count = parseInt(process.env.LOG_COUNT || '40', 10);
      console.log(`--- Last ${count} log entries ---`);
      logs.slice(-count).forEach(l => console.log(l.output));
    } catch(e) {
      console.log('Logs slice:', single.logs.slice(-300));
    }
  }
} else {
  console.log('Deployments by id failed with status:', singleRes.status);
}

