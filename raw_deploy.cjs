const fs = require('fs');
const https = require('https');

// --- Load env (prefer APPWRITE_FUNCTION_API_KEY, fall back to APPWRITE_API_KEY) ---
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
if (!API_KEY) {
  console.error('NO API KEY');
  process.exit(1);
}

const url = new URL(ENDPOINT);
const HOST = url.hostname;
const PORT = url.port ? Number(url.port) : 443;
const PREFIX = url.pathname.replace(/\/$/, '') || '/v1';

// --- Build multipart ---
function buildMultipart(fields, filePath, fileName, boundary) {
  const chunks = [];
  const pushText = (s) => chunks.push(Buffer.from(s, 'utf8'));
  for (const [k,v] of Object.entries(fields)) {
    pushText('--' + boundary + '\r\nContent-Disposition: form-data; name="' + k + '"\r\n\r\n' + v + '\r\n');
  }
  const fbuf = fs.readFileSync(filePath);
  pushText('--' + boundary + '\r\nContent-Disposition: form-data; name="code"; filename="' + fileName + '"\r\nContent-Type: application/gzip\r\n\r\n');
  chunks.push(fbuf);
  pushText('\r\n--' + boundary + '--\r\n');
  return Buffer.concat(chunks);
}

function request(method, path, headers, body) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      host: HOST,
      port: PORT,
      path: path,
      method: method,
      headers: headers,
    }, (res) => {
      const data = [];
      res.on('data', (c) => data.push(c));
      res.on('end', () => {
        const txt = Buffer.concat(data).toString('utf8');
        let json = null;
        try { json = JSON.parse(txt); } catch (e) { /* not json */ }
        resolve({ status: res.statusCode, body: txt, json });
      });
    });
    req.on('error', (e) => reject(e));
    if (body) req.write(body);
    req.end();
  });
}

async function main() {
  const out = [];
  const boundary ='----AliveDeploy' + Date.now();
  const fields = { entrypoint: 'src/main.js', commands: 'npm install', activate: 'true' };
  const filePath = '.deploy_payloads/paystack_webhook.tar.gz';
  const payload = buildMultipart(fields, filePath, 'code.tar.gz', boundary);
  const headers = {
    'X-Appwrite-Project': PROJECT_ID,
    'X-Appwrite-Key': API_KEY,
    'Content-Type': 'multipart/form-data; boundary=' + boundary,
    'Content-Length': payload.length,
  };

  // 1. Create deployment
  let res = await request('POST', PREFIX + '/functions/paystack_webhook/deployments', headers, payload);
  out.push('CREATE ' + res.status + ': ' + res.body.slice(0, 500));
  let deploymentId = null;
  if (res.json && res.json.$id) deploymentId = res.json.$id;
  if (res.json && res.json.deploymentId) deploymentId = res.json.deploymentId;// newer shape

  // 2. Activate deployment (best-effort)
  if (deploymentId) {
    res = await request('PATCH', PREFIX + '/functions/paystack_webhook/deployments/' + deploymentId, {
      'X-Appwrite-Project': PROJECT_ID,
      'X-Appwrite-Key': API_KEY,
      'Content-Type': 'application/json',
    }, Buffer.from('{}', 'utf8'));
    out.push('ACTIVATE ' + res.status + ': ' + res.body.slice(0, 300));
    out.push('DEPLOYMENT_ID: ' + deploymentId);
  } else {
    out.push('NO DEPLOYMENT_ID PARSED');
  }

  fs.writeFileSync('raw_deploy_log.txt', out.join('\n'), 'utf8');
  console.log('done');
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});