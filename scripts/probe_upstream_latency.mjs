// Localises a 504: which tier is slow?
//   Coolify panel  -> the deploy manager itself
//   app.alivenigeria.org -> the Flutter web app (nginx + container)
//   api.alivenigeria.org -> Appwrite behind nginx
// A 504 is nginx failing to get a reply from its upstream, so timing each
// tier separately says whether the problem is nginx/the container, Appwrite,
// or the Coolify proxy in front of both.
//
//   node scripts/probe_upstream_latency.mjs
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
}

const TARGETS = [
  ['coolify panel ', (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '') + '/api/v1/health'],
  ['app (static)  ', 'https://app.alivenigeria.org/'],
  ['app (index.js)', 'https://app.alivenigeria.org/main.dart.js'],
  ['appwrite      ', 'https://api.alivenigeria.org/v1/health'],
];

const RUNS = 5;
const TIMEOUT_MS = 15000;

async function probe(url) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), TIMEOUT_MS);
  const t0 = Date.now();
  try {
    const res = await fetch(url, {
      signal: ac.signal,
      headers: { 'X-Appwrite-Key': process.env.APPWRITE_API_KEY || '' },
    });
    // Drain the body so the measurement covers the whole exchange.
    await res.text();
    return { ms: Date.now() - t0, status: res.status };
  } catch (e) {
    return { ms: Date.now() - t0, status: 0, err: e.name };
  } finally {
    clearTimeout(timer);
  }
}

const stats = new Map(TARGETS.map(([n]) => [n, []]));

for (let i = 0; i < RUNS; i++) {
  for (const [name, url] of TARGETS) {
    if (!url || url.endsWith('/health') === false && name.startsWith('coolify') && !url) continue;
    const r = await probe(url);
    stats.get(name).push(r);
    process.stdout.write(
      `run ${i + 1}  ${name}  ${String(r.status).padStart(3)}  ${String(r.ms).padStart(6)}ms${r.err ? '  ' + r.err : ''}\n`,
    );
  }
  if (i < RUNS - 1) await new Promise((r) => setTimeout(r, 1500));
}

console.log('\n--- summary over ' + RUNS + ' runs ---');
for (const [name, results] of stats) {
  if (!results.length) continue;
  const ok = results.filter((r) => r.status > 0);
  const times = ok.map((r) => r.ms).sort((a, b) => a - b);
  const failed = results.length - ok.length;
  const med = times.length ? times[Math.floor(times.length / 2)] : '-';
  const worst = times.length ? times[times.length - 1] : '-';
  const codes = [...new Set(results.map((r) => r.status))].join(',');
  console.log(
    `${name}  ok=${ok.length}/${results.length}  codes=${codes}  median=${med}ms  worst=${worst}ms` +
      (failed ? `  FAILED=${failed}` : ''),
  );
}
