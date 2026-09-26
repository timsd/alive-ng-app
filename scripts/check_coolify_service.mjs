/**
 * Inspects the ALIVE Coolify service: which repository/branch it watches, its
 * build pack, its GitHub webhook state, and recent deployments.
 *
 * READ-ONLY. It only ever looks at the single service UUID held in .env, so it
 * cannot touch the other ALIVE-family projects on the same host.
 *
 *   node scripts/check_coolify_service.mjs
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}
loadDotEnv();

const base = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const token = process.env.COOLIFY_API_TOKEN;
const uuid = process.env.COOLIFY_SERVICE_UUID;

if (!base || !token || !uuid) {
  throw new Error('Missing COOLIFY_API_URL / COOLIFY_API_TOKEN / COOLIFY_SERVICE_UUID');
}

async function coolify(path) {
  const res = await fetch(`${base}/api/v1${path}`, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`${path} -> HTTP ${res.status} ${text.slice(0, 200)}`);
  }
  return JSON.parse(text);
}

// The UUID in .env may be stale. List what this Coolify actually hosts so the
// ALIVE application can be identified by name, and so the similarly-named
// Zavo/Monpa projects are visibly left alone.
const all = await coolify('/applications?perPage=100');
const list = all ?? [];
console.log(`=== applications on this Coolify (${list.length}) ===`);
for (const a of list) {
  console.log(
    `  ${String(a.uuid).slice(0, 8)}  ${String(a.name).padEnd(28)} ` +
      `${a.git_repository ?? ''}${a.git_branch ? ' @' + a.git_branch : ''}`,
  );
}

const app = list.find((a) => a.uuid === uuid);
if (!app) {
  console.log(
    `\nThe service UUID in .env (${uuid}) is not an application on this ` +
      'Coolify. It is stale; set COOLIFY_SERVICE_UUID to the ALIVE entry above.',
  );
  process.exit(0);
}

console.log('\n=== ALIVE service ===');
console.log(`name        : ${app.name}`);
console.log(`uuid        : ${app.uuid}`);
console.log(`repository  : ${app.git_repository ?? '(none)'}`);
console.log(`branch      : ${app.git_branch ?? '(none)'}`);
console.log(`build pack  : ${app.build_pack}`);
console.log(`fqdn        : ${app.fqdn ?? '(none)'}`);
console.log(`webhook id  : ${app.git_webhook ?? '(none)'}`);

console.log('\n=== build variables of interest ===');
for (const v of app.build_variables ?? []) {
  if (/FLUTTER|APPWRITE|BUILD_ARG|NODE_ENV/i.test(v.name)) {
    const value = v.is_build_time === false ? v.value : `${v.value}`;
    console.log(`  ${v.name} = ${String(value).slice(0, 160)}`);
  }
}

console.log('\n=== recent deployments ===');
const deployments = await coolify(`/applications/${uuid}/deployments?perPage=5`);
for (const d of deployments ?? []) {
  console.log(
    `  ${d.created_at}  ${d.status}  commit=${(d.commit ?? '').slice(0, 8)}`,
  );
}
