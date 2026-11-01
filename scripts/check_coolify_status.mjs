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

const depRes = await fetch(`${base}/api/v1/deployments`, { headers });
console.log('Deployments list status:', depRes.status);
if (depRes.ok) {
  const deps = await depRes.json();
  const latest = deps?.[0];
  if (latest) {
    console.log('Latest deployment:', {
      id: latest.id,
      commit: latest.commit?.slice(0, 8),
      status: latest.status,
      finished_at: latest.finished_at,
      created_at: latest.created_at,
      updated_at: latest.updated_at
    });
    if (latest.logs) {
      try {
        const logs = JSON.parse(latest.logs);
        console.log('--- Last 10 log entries ---');
        logs.slice(-10).forEach(l => console.log(l.output));
      } catch(e) {
        console.log('Logs slice:', latest.logs.slice(-300));
      }
    }
  } else {
    console.log('No deployments found in active queue.');
  }
} else {
  console.log(await depRes.text());
}

