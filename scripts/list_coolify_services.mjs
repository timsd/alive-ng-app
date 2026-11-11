// List Coolify services (docker-compose stacks such as Appwrite, GlitchTip).
import fs from 'fs';
const env = Object.fromEntries(
  fs.readFileSync('.env', 'utf8').split(/\r?\n/)
    .filter((l) => l && !l.startsWith('#') && l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
);
const base = env.COOLIFY_API_URL.replace(/\/$/, '');
const api = base.endsWith('/api/v1') ? base : `${base}/api/v1`;
const r = await fetch(`${api}/services`, {
  headers: { Authorization: `Bearer ${env.COOLIFY_API_TOKEN}`, Accept: 'application/json' },
});
const d = await r.json();
for (const s of d) console.log(`${s.name} | ${s.uuid} | ${s.status}`);

