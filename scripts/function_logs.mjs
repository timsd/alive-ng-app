// Prints the recent executions of a function, with logs, so a non-binding can
// be diagnosed. Complements test_office_binding.mjs, which can only say "it did
// not bind" and leaves the reason in the function's own logs.
//
//   node scripts/function_logs.mjs <functionId> [count]
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

const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
};

const functionId = process.argv[2];
const count = process.argv[3] || '5';
if (!functionId) {
  console.error('usage: node scripts/function_logs.mjs <functionId> [count]');
  process.exit(1);
}

const queryStr = encodeURIComponent('orderDesc("$createdAt")');
const res = await fetch(
  `${endpoint}/v1/functions/${functionId}/executions?queries[]=${queryStr}&limit=${count}`,
  { headers },
);
const j = await res.json();
if (!res.ok) {
  console.error(`${res.status}: ${JSON.stringify(j).slice(0, 400)}`);
  process.exit(1);
}

console.log(`executions: ${j.total}`);
// Logs come back under one of several shapes depending on the version and
// whether the execution list or the single-execution route was used, so
// normalise rather than assume an array.
const normalizeLogs = (raw) => {
  if (!raw) return [];
  if (Array.isArray(raw)) {
    return raw.map((l) =>
      typeof l === 'string' ? l : `[${l.type || 'log'}] ${l.message ?? JSON.stringify(l)}`,
    );
  }
  if (typeof raw === 'object') {
    // 1.8 groups logs by type: { log: [...], error: [...], ... }
    return Object.entries(raw).flatMap(([type, items]) =>
      (Array.isArray(items) ? items : [items]).map((l) =>
        typeof l === 'string' ? `[${type}] ${l}` : `[${type}] ${l?.message ?? JSON.stringify(l)}`,
      ),
    );
  }
  return [String(raw)];
};

for (const e of j.executions || []) {
  console.log(`\n=== ${e.$id}  ${e.status} (HTTP ${e.responseStatusCode})  created: ${e.$createdAt}  duration: ${e.duration || 0}s`);
  console.log(`    response: ${e.responseBody || 'empty'}`);
  console.log(`    error: ${e.errors || e.error || 'none'}`);
  const logs = normalizeLogs(e.logs ?? e.logsBody);
  if (logs.length) console.log(logs.join('\n'));
}
