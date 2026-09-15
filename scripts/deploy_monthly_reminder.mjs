/**
 * Deploy only the monthlyDonationReminder function.
 * Run once to create the function on Appwrite and activate the deployment.
 */
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const endpoint = getEnv('APPWRITE_ENDPOINT') || 'https://api.alivenigeria.org/v1';
const host = new URL(endpoint).hostname;

async function request(urlPath, method = 'GET', body = null, extraHeaders = {}) {
  const headers = {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
    ...extraHeaders,
  };
  if (body && typeof body === 'string' && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json';
  }

  const https = await import('https');
  return new Promise((resolve, reject) => {
    const req = https.default.request({
      hostname: host,
      path: '/v1' + urlPath,
      method,
      headers,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch (_) { resolve({ status: res.statusCode, data }); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

const fnId = 'monthly_donation_reminder';
const folderPath = 'appwrite_functions/monthlyDonationReminder';
const entrypoint = 'src/main.js';
const commands = 'npm install';

// 1. Create the function if needed
const check = await request(`/functions/${fnId}`);
if (check.status === 404) {
  console.log(`Creating function ${fnId}...`);
  const createRes = await request('/functions', 'POST', JSON.stringify({
    functionId: fnId,
    name: 'monthlyDonationReminder',
    runtime: 'node-20.0',
    execute: ['any'],
    events: [],
    schedule: '0 8 1 * *',
    timeout: 300,
    enabled: true,
    logging: true,
    entrypoint,
    commands,
    scopes: ['users.read', 'messages.write', 'databases.read', 'documents.read'],
  }));
  console.log('Create result:', createRes.status, createRes.data?.$id || createRes.data?.message);
  if (createRes.status !== 201 && createRes.status !== 200) {
    console.error('Failed to create function:', JSON.stringify(createRes.data));
    process.exit(1);
  }
} else {
  console.log(`Function ${fnId} already exists. Updating deployment only...`);
}

// 2. Set env vars
const envVars = {
  APPWRITE_ENDPOINT: endpoint,
  APPWRITE_PROJECT_ID: projectId,
  APPWRITE_API_KEY: apiKey,
  APPWRITE_DATABASE_ID: getEnv('APPWRITE_DATABASE_ID') || '6a089307002e54291a32',
};

const existingVarsRes = await request(`/functions/${fnId}/variables`);
const existingMap = new Map((existingVarsRes.data?.variables || []).map(v => [v.key, v.$id]));
for (const [key, value] of Object.entries(envVars)) {
  if (!value) continue;
  if (existingMap.has(key)) {
    await request(`/functions/${fnId}/variables/${existingMap.get(key)}`, 'PUT', JSON.stringify({ key, value }));
  } else {
    await request(`/functions/${fnId}/variables`, 'POST', JSON.stringify({ key, value }));
  }
  console.log(`Set var: ${key}`);
}

// 3. Package and upload
const tarFile = path.resolve(`.tmp_${fnId}.tar.gz`);
if (fs.existsSync(tarFile)) fs.unlinkSync(tarFile);
execSync(`tar -czf "${tarFile}" -C "${folderPath}" .`, { stdio: 'inherit' });

const fileBytes = fs.readFileSync(tarFile);
const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
let pre = `--${boundary}\r\nContent-Disposition: form-data; name="entrypoint"\r\n\r\n${entrypoint}\r\n`;
pre += `--${boundary}\r\nContent-Disposition: form-data; name="commands"\r\n\r\n${commands}\r\n`;
pre += `--${boundary}\r\nContent-Disposition: form-data; name="activate"\r\n\r\ntrue\r\n`;
pre += `--${boundary}\r\nContent-Disposition: form-data; name="code"; filename="code.tar.gz"\r\nContent-Type: application/gzip\r\n\r\n`;
const post = `\r\n--${boundary}--\r\n`;
const bodyBuffer = Buffer.concat([Buffer.from(pre), fileBytes, Buffer.from(post)]);

console.log(`Uploading ${bodyBuffer.length} bytes...`);
const uploadRes = await request(`/functions/${fnId}/deployments`, 'POST', bodyBuffer, {
  'Content-Type': `multipart/form-data; boundary=${boundary}`,
  'Content-Length': bodyBuffer.length,
});
console.log('Upload result:', uploadRes.status, uploadRes.data?.status || uploadRes.data?.message);
try { fs.unlinkSync(tarFile); } catch (_) {}

const deploymentId = uploadRes.data?.$id;
if (deploymentId && [200, 201, 202].includes(uploadRes.status)) {
  console.log('Waiting for build...');
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 4000));
    const s = await request(`/functions/${fnId}/deployments/${deploymentId}`);
    const st = s.data?.status;
    console.log(`  Build status: ${st}`);
    if (st === 'ready') {
      const act = await request(`/functions/${fnId}/deployments/${deploymentId}`, 'PATCH', '{}');
      console.log(`  Activated: ${act.status}`);
      break;
    }
    if (st === 'failed') { console.error('  Build FAILED!'); break; }
  }
}
console.log('Done.');
