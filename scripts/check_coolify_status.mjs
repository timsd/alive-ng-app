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
  console.log(JSON.stringify(deps.slice(0, 5), null, 2));
} else {
  console.log(await depRes.text());
}

