// Prints a function's configuration: scopes, events, schedule and variable
// names (never values). Diagnoses "no available server", which is what a
// function's own API key reports when the scope it needs is missing.
//
//   node scripts/inspect_function.mjs <functionId>
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
if (!functionId) {
  console.error('usage: node scripts/inspect_function.mjs <functionId>');
  process.exit(1);
}

const res = await fetch(`${endpoint}/v1/functions/${functionId}`, { headers });
const j = await res.json();
if (!res.ok) {
  console.error(`${res.status}: ${JSON.stringify(j).slice(0, 300)}`);
  process.exit(1);
}

console.log(`name:            ${j.name} (${j.$id})`);
console.log(`runtime:         ${j.runtime}`);
console.log(`enabled:         ${j.enabled}   live: ${j.live}`);
console.log(`entrypoint:      ${j.entrypoint}`);
console.log(`commands:        ${j.commands}`);
console.log(`timeout:         ${j.timeout}s`);
console.log(`schedule:        ${j.schedule || '(none)'}`);
console.log(`events:          ${(j.events || []).join(', ') || '(none)'}`);
console.log(`scopes:          ${(j.scopes || []).join(', ') || '(none)'}`);
console.log(`execute:         ${(j.execute || []).join(', ') || '(none)'}`);
console.log(`var names:       ${(j.vars || []).map((v) => v.key).join(', ') || '(none)'}`);
