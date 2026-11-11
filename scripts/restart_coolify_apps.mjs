// Restart selected Coolify applications one at a time and wait for healthy.
// Usage: node scripts/restart_coolify_apps.mjs "ALIVE Flutter Web" "LiveKit Egress"
import fs from 'fs';

const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8').split(/\r?\n/)
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
);
const base = env.COOLIFY_API_URL.replace(/\/$/, '');
const api = base.endsWith('/api/v1') ? base : `${base}/api/v1`;
const headers = { Authorization: `Bearer ${env.COOLIFY_API_TOKEN}`, Accept: 'application/json' };
const call = async (method, path) => {
  const r = await fetch(`${api}${path}`, { method, headers });
  const t = await r.text();
  try { return { status: r.status, data: JSON.parse(t) }; } catch { return { status: r.status, data: t }; }
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const wanted = process.argv.slice(2);
const apps = (await call('GET', '/applications')).data;
for (const name of wanted) {
  const app = apps.find((a) => a.name === name);
  if (!app) { console.log(`! not found: ${name}`); continue; }
  const r = await call('GET', `/applications/${app.uuid}/restart`);
  const res = r.status === 405 || r.status === 404
    ? await call('POST', `/applications/${app.uuid}/restart`) : r;
  console.log(`restart ${name}: HTTP ${res.status}`, typeof res.data === 'object' ? JSON.stringify(res.data) : '');
  let status = '';
  for (let i = 0; i < 40; i++) {
    await sleep(6000);
    const cur = (await call('GET', `/applications/${app.uuid}`)).data;
    status = cur.status;
    if (String(status).includes('healthy') && !String(status).includes('unhealthy')) break;
  }
  console.log(`  -> ${name}: ${status}`);
}

