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
  'Content-Type': 'application/json',
};
const dbId = process.env.APPWRITE_DATABASE_ID;

if (!endpoint || !process.env.APPWRITE_PROJECT_ID || !process.env.APPWRITE_API_KEY || !dbId) {
  console.error('❌ Missing Appwrite credentials in .env');
  process.exit(1);
}

async function purgeTable(tableId) {
  let deleted = 0;
  while (true) {
    const listUrl = `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows?queries[0]=${encodeURIComponent(JSON.stringify({ method: 'limit', values: [100] }))}`;
    const res = await fetch(listUrl, { headers });
    if (!res.ok) {
      throw new Error(`Failed to list ${tableId}: ${res.status} ${await res.text()}`);
    }
    const data = await res.json();
    const rows = data.rows || data.documents || [];
    if (rows.length === 0) break;

    for (const row of rows) {
      const id = row.$id;
      const delUrl = `${endpoint}/v1/tablesdb/${dbId}/tables/${tableId}/rows/${id}`;
      const delRes = await fetch(delUrl, { method: 'DELETE', headers });
      if (!delRes.ok && delRes.status !== 404) {
        throw new Error(`Failed to delete ${tableId}/${id}: ${delRes.status} ${await delRes.text()}`);
      }
      deleted++;
    }
  }
  console.log(`✅ Purged ${deleted} rows from ${tableId}.`);
}

async function resetProjectAmounts() {
  const listUrl = `${endpoint}/v1/tablesdb/${dbId}/tables/projects/rows?queries[0]=${encodeURIComponent(JSON.stringify({ method: 'limit', values: [100] }))}`;
  const res = await fetch(listUrl, { headers });
  if (!res.ok) {
    console.warn(`⚠️ Could not list projects: ${res.status}`);
    return;
  }
  const data = await res.json();
  const rows = data.rows || data.documents || [];
  let resetCount = 0;
  for (const row of rows) {
    if ((Number(row.current_amount) || 0) !== 0) {
      const updUrl = `${endpoint}/v1/tablesdb/${dbId}/tables/projects/rows/${row.$id}`;
      const updRes = await fetch(updUrl, {
        method: 'PATCH',
        headers,
        body: JSON.stringify({ data: { current_amount: 0 } }),
      });
      if (updRes.ok) resetCount++;
    }
  }
  console.log(`✅ Reset current_amount=0 on ${resetCount} projects.`);
}

await purgeTable('donation_records');
await purgeTable('payment_logs');
await purgeTable('gift_submissions');
await resetProjectAmounts();
console.log('🎉 Financial records securely purged. Ready for clean test & live tracking.');
