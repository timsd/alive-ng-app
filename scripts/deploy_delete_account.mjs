/**
 * Deploys the deleteAccount function and gives it the variables it needs to
 * send the account-closed confirmation email.
 *
 * The function had no email code at all, and no RESEND_API_KEY, so a member
 * deleting their account received no confirmation. This adds both the code (in
 * appwrite_functions/deleteAccount) and the credentials (here).
 *
 * Existing function variables are updated in place rather than recreated, so
 * nothing already configured is lost.
 *
 *   node scripts/deploy_delete_account.mjs
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

const fnId = 'delete_account';
const folderPath = 'appwrite_functions/deleteAccount';
const entrypoint = 'src/main.js';
const commands = 'npm install';

const check = await request(`/functions/${fnId}`);
if (check.status === 404) {
  console.log(`Creating function ${fnId}...`);
  const createRes = await request('/functions', 'POST', JSON.stringify({
    functionId: fnId,
    name: 'deleteAccount',
    runtime: 'node-20.0',
    execute: ['users'],
    events: [],
    schedule: '',
    timeout: 300,
    enabled: true,
    logging: true,
    entrypoint,
    commands,
    scopes: ['users.write'],
  }));
  console.log('Create result:', createRes.status, createRes.data?.$id || createRes.data?.message);
  if (![200, 201].includes(createRes.status)) {
    console.error('Failed to create function:', JSON.stringify(createRes.data));
    process.exit(1);
  }
} else {
  console.log(`Function ${fnId} already exists. Updating deployment only...`);
}

// Variables. RESEND_API_KEY / SENDER_EMAIL / REPLY_TO_EMAIL are what make the
// confirmation email work; the APPWRITE_* ones were already set.
//
// This must run on every deploy, not only when the function is created: the
// function already existed and had none of the email variables, so the
// confirmation could not send.
const envVars = {
  APPWRITE_ENDPOINT: endpoint,
  APPWRITE_PROJECT_ID: projectId,
  APPWRITE_FUNCTION_API_KEY: getEnv('APPWRITE_FUNCTION_API_KEY') || apiKey,
  APPWRITE_FUNCTION_API_ENDPOINT: endpoint,
  APPWRITE_FUNCTION_PROJECT_ID: projectId,
  RESEND_API_KEY: getEnv('RESEND_API_KEY'),
  SENDER_EMAIL: getEnv('SENDER_EMAIL') || 'ALIVE Nigeria App <msg@app.alivenigeria.org>',
  REPLY_TO_EMAIL: getEnv('REPLY_TO_EMAIL') || 'app@alivenigeria.org',
};

const missing = Object.entries(envVars).filter(([, v]) => !v);
if (missing.length) {
  console.error(`Missing in .env: ${missing.map(([k]) => k).join(', ')}`);
  process.exit(1);
}

const existingVarsRes = await request(`/functions/${fnId}/variables`);
const existingMap = new Map((existingVarsRes.data?.variables || []).map(v => [v.key, v.$id]));
for (const [key, value] of Object.entries(envVars)) {
  const r = existingMap.has(key)
    ? await request(`/functions/${fnId}/variables/${existingMap.get(key)}`, 'PUT', JSON.stringify({ key, value }))
    : await request(`/functions/${fnId}/variables`, 'POST', JSON.stringify({ key, value }));
  // Checked, because a silently rejected variable looks exactly like a
  // successful one until the email fails to send months later.
  if (r.status >= 300) {
    console.error(`Failed to set ${key} (${r.status}): ${JSON.stringify(r.data)}`);
    process.exit(1);
  }
  console.log(`Set var: ${key} [${r.status}]`);
}

// Package and upload.
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