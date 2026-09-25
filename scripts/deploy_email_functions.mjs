import fs from 'fs';
import path from 'path';
import https from 'https';
import { execSync } from 'child_process';

/**
 * Focused deployment for the transactional-email functions.
 *
 *   node scripts/deploy_email_functions.mjs [--only=send_email,paystack_payments]
 *
 * Why a separate script: `deploy_appwrite_functions.mjs` redeploys every
 * function in appwrite.config.json (slow + unnecessary). This one only touches
 * the functions involved in email delivery, and also repairs the
 * `send_email` trigger event (`users.*.create`) that powers the automatic
 * welcome email.
 */

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const endpoint = getEnv('APPWRITE_ENDPOINT') || 'https://api.alivenigeria.org/v1';
const host = new URL(endpoint).hostname;

const TARGETS = [
  { id: 'send_email', path: 'appwrite_functions/sendEmail', events: ['users.*.create'] },
  { id: 'paystack_payments', path: 'appwrite_functions/paystackPayments', events: [] },
  { id: 'paystack_webhook', path: 'appwrite_functions/paystackWebhook', events: [] },
  { id: 'delete_account', path: 'appwrite_functions/deleteAccount', events: [] },
];

function request(apiPath, method = 'GET', body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const defaultHeaders = {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      ...headers,
    };
    if (body && typeof body === 'string' && !defaultHeaders['Content-Type']) {
      defaultHeaders['Content-Type'] = 'application/json';
    }

    const req = https.request({
      hostname: host,
      path: '/v1' + apiPath,
      method,
      headers: defaultHeaders,
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function ensureFunctionEvents(fn) {
  const current = await request(`/functions/${fn.id}`);
  if (current.status !== 200) {
    console.error(`Could not read ${fn.id}: ${current.status}`);
    return;
  }

  const existing = current.data.events || [];
  const same = JSON.stringify([...existing].sort()) === JSON.stringify([...fn.events].sort());
  if (same) return;

  const res = await request(`/functions/${fn.id}`, 'PUT', JSON.stringify({
    name: current.data.name,
    runtime: current.data.runtime,
    execute: current.data.execute,
    events: fn.events,
    schedule: current.data.schedule || '',
    timeout: current.data.timeout,
    enabled: current.data.enabled,
    logging: current.data.logging,
    entrypoint: current.data.entrypoint,
    commands: current.data.commands,
    scopes: current.data.scopes,
  }));
  console.log(`Updated ${fn.id} events -> ${JSON.stringify(fn.events)} (status ${res.status})`);
}

async function deployFunction(fn) {
  const tarFile = path.resolve(`.tmp_${fn.id}.tar.gz`);
  if (fs.existsSync(tarFile)) fs.unlinkSync(tarFile);
  execSync(`tar -czf "${tarFile}" -C "${fn.path}" .`, { stdio: 'inherit' });

  const fileBytes = fs.readFileSync(tarFile);
  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);

  let pre = '';
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="entrypoint"\r\n\r\nsrc/main.js\r\n`;
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="commands"\r\n\r\nnpm install\r\n`;
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="activate"\r\n\r\ntrue\r\n`;
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="code"; filename="code.tar.gz"\r\nContent-Type: application/gzip\r\n\r\n`;
  const post = `\r\n--${boundary}--\r\n`;

  const bodyBuffer = Buffer.concat([
    Buffer.from(pre, 'utf8'),
    fileBytes,
    Buffer.from(post, 'utf8'),
  ]);

  console.log(`Uploading ${fn.id} deployment (${bodyBuffer.length} bytes)...`);
  const res = await request(`/functions/${fn.id}/deployments`, 'POST', bodyBuffer, {
    'Content-Type': `multipart/form-data; boundary=${boundary}`,
    'Content-Length': bodyBuffer.length,
  });

  try { fs.unlinkSync(tarFile); } catch (_) {}

  const deploymentId = res.data && res.data['$id'];
  console.log(`Deploy ${fn.id}: status ${res.status}, deployment ${deploymentId || 'n/a'}`);

  if (!deploymentId) return;

  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    const check = await request(`/functions/${fn.id}/deployments/${deploymentId}`);
    const st = check.data && check.data.status;
    console.log(`  ${fn.id} build status: ${st}`);
    if (st === 'ready') {
      const activate = await request(`/functions/${fn.id}/deployments/${deploymentId}`, 'PATCH', '');
      console.log(`  ${fn.id} activated: ${activate.status}`);
      return;
    }
    if (st === 'failed') {
      console.error(`  ${fn.id} build FAILED`);
      return;
    }
  }
}

async function run() {
  const onlyArg = process.argv.find((a) => a.startsWith('--only='));
  const only = onlyArg ? onlyArg.split('=')[1].split(',').map((s) => s.trim()) : null;
  const targets = only ? TARGETS.filter((t) => only.includes(t.id)) : TARGETS;

  for (const fn of targets) {
    console.log(`\n================ ${fn.id} ================`);
    await ensureFunctionEvents(fn);
    await deployFunction(fn);
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
