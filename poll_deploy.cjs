const fs = require('fs');
const https = require('https');

const raw = fs.readFileSync('.env', 'utf8');
const vars = {};
for (const line of raw.split(/\r?\n/)) {
  const trimmed = line.trim();
  if (!trimmed || !trimmed.includes('=')) continue;
  const isCommented = trimmed.startsWith('#');
  const clean =isCommented ? trimmed.slice(1).trim() : trimmed;
  if (!clean || !clean.includes('=')) continue;
  const idx = clean.indexOf('=');
  const key = clean.slice(0, idx).trim();
  const val = clean.slice(idx + 1).trim().replace(/^["']|["']$/g, '');
  if (key && val) vars[key] = val;
}

const ENDPOINT = vars.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1';
const PROJECT_ID = vars.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
const API_KEY = vars.APPWRITE_FUNCTION_API_KEY || vars.APPWRITE_API_KEY;
const url = new URL(ENDPOINT);
const HOST = url.hostname;
const PORT = url.port ? Number(url.port) : 443;
const PREFIX = url.pathname.replace(/\/$/, '') || '/v1';

function request(method, path, headers) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host: HOST, port: PORT, path: path, method: method, headers: headers }, (res) => {
      const data = [];
      res.on('data', (c) => data.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(data).toString('utf8') }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  const headers = { 'X-Appwrite-Project': PROJECT_ID, 'X-Appwrite-Key': API_KEY };
  const out = [];
  for (let i = 0; i < 8; i++) {
    const res = await request('GET', PREFIX + '/functions/paystack_webhook/deployments', headers);
    let json = null;
    try { json = JSON.parse(res.body); } catch (e) {}
    const deployments = (json && json.deployments) || [];
    const first = deployments[0] || {};
    out.push('POLL' + i + ' HTTP' + res.status + ' status=' + (first.status || 'none') + ' id=' + (first.$id || '') + ' activate=' + (first.activate || ''));
    if (first.status === 'ready') break;
    await new Promise((r) => setTimeout(r, 15000));
  }
  fs.writeFileSync('deploy_poll_log.txt', out.join('\n'), 'utf8');
  console.log('done');
}

main().catch((e) => { console.error('FATAL', e); process.exit(1); });