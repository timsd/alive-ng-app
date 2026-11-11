import fs from 'fs';
const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8').split(/\r?\n/)
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
);
const base = env.COOLIFY_API_URL.replace(/\/$/, '');
const api = base.endsWith('/api/v1') ? base : `${base}/api/v1`;
const r = await fetch(`${api}/servers/eivyekqe4x846mp0mohe5g1j`, {
  headers: { Authorization: `Bearer ${env.COOLIFY_API_TOKEN}`, Accept: 'application/json' },
});
const d = await r.json();
console.log('proxy keys:', Object.keys(d.proxy || {}));
console.log('settings:', JSON.stringify(d.settings ?? {}, null, 1).slice(0, 1800));
const cfg = d.proxy?.last_saved_proxy_configuration || '';
console.log(cfg.split('\n').slice(40).join('\n'));

for (const u of [
  'https://app.alivenigeria.org', 'https://api.alivenigeria.org/v1/health',
  'https://glitchtip.alivenigeria.org', 'https://fundmax.com.ng',
  'https://usemonpa.com', 'https://api.usemonpa.com', 'https://livekit.alivenigeria.org',
]) {
  try {
    const x = await fetch(u, { redirect: 'manual', signal: AbortSignal.timeout(10000) });
    console.log(u, x.status);
  } catch (e) {
    console.log(u, 'ERR', e.cause?.code || e.message);
  }
}

