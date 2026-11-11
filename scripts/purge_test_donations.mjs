import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
  }
}
const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};
const dbId = process.env.APPWRITE_DATABASE_ID;

const testIds = ['6af170e45d81890b4012', '6af365da7a5082d6d2a8'];

for (const id of testIds) {
  const url = `${endpoint}/v1/tablesdb/${dbId}/tables/donation_records/rows/${id}`;
  const res = await fetch(url, { method: 'DELETE', headers });
  if (res.ok || res.status === 404) {
    console.log(`✅ Test donation row ${id} removed successfully (status ${res.status}).`);
  } else {
    console.error(`❌ Failed to remove ${id}: ${res.status} ${await res.text()}`);
  }
}

