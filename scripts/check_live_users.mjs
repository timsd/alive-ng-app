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
    const value = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
    process.env[key] = value;
  }
}

loadDotEnv();

const { appwriteProject } = await import('./appwrite_infrastructure_schema.mjs');
const endpoint = (appwriteProject.endpoint || '').replace(/\/$/, '');
const projectId = appwriteProject.projectId;
const databaseId = appwriteProject.databaseId;
const apiKey = process.env.APPWRITE_API_KEY;

const headers = {
  'X-Appwrite-Project': projectId,
  'X-Appwrite-Key': apiKey,
  'Content-Type': 'application/json',
};

const authRes = await fetch(`${endpoint}/users?limit=25`, { headers });
const authUsers = await authRes.json();
console.log('--- AUTH USERS (' + (authUsers.total || 0) + ') ---');
for (const u of authUsers.users || []) {
  console.log(`ID: ${u.$id} | Email: ${u.email} | Name: ${u.name} | Labels: ${JSON.stringify(u.labels)}`);
}

const dbRes = await fetch(`${endpoint}/databases/${databaseId}/collections/Users/documents?limit=25`, { headers });
const dbDocs = await dbRes.json();
console.log('--- DB USERS ROWS (' + (dbDocs.total || 0) + ') ---');
for (const d of dbDocs.documents || []) {
  console.log(`RowID: ${d.$id} | Email: ${d.email} | Role: ${d.role} | is_approved: ${d.is_approved} | status: ${d.approval_status} | permissions: ${JSON.stringify(d.$permissions)}`);
}
