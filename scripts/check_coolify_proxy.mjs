// Read-only Coolify health check: version, servers, proxy status and resources.
import fs from 'fs';

const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8').split(/\r?\n/)
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
);
const base = env.COOLIFY_API_URL.replace(/\/$/, '');
const api = base.endsWith('/api/v1') ? base : `${base}/api/v1`;

async function get(path) {
  const res = await fetch(`${api}${path}`, {
    headers: { Authorization: `Bearer ${env.COOLIFY_API_TOKEN}`, Accept: 'application/json' },
  });
  const text = await res.text();
  let data = text;
  try { data = JSON.parse(text); } catch { /* keep text */ }
  return { status: res.status, data };
}

const version = await get('/version');
console.log('version:', version.status, version.data);

const servers = await get('/servers');
console.log('servers:', servers.status);
for (const s of Array.isArray(servers.data) ? servers.data : []) {
  console.log(JSON.stringify({
    name: s.name, uuid: s.uuid, ip: s.ip,
    reachable: s.is_reachable, usable: s.is_usable,
    proxy: s.proxy, settings_proxy_type: s.proxy?.type,
    proxy_status: s.proxy?.status,
  }, null, 2));
  const detail = await get(`/servers/${s.uuid}`);
  console.log('detail:', detail.status, JSON.stringify(detail.data?.proxy ?? detail.data, null, 2).slice(0, 1500));
}

const apps = await get('/applications');
for (const a of Array.isArray(apps.data) ? apps.data : []) {
  console.log(`app ${a.name}: status=${a.status} fqdn=${a.fqdn}`);
}

