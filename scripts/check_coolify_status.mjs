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

// First try specific deployment id if passed, or default to eqr8mtu34gysv0vwihfwn2nr or latest
const depId = process.argv[2] || 'eqr8mtu34gysv0vwihfwn2nr';
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
      console.log('--- Last 15 log entries ---');
      logs.slice(-15).forEach(l => console.log(l.output));
    } catch(e) {
      console.log('Logs slice:', single.logs.slice(-300));
    }
  }
} else {
  console.log('Deployments by id failed with status:', singleRes.status);
}

