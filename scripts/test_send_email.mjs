import https from 'https';
import fs from 'fs';

/**
 * Smoke-tests the deployed `send_email` function (both the generic payload and
 * the account-deletion notification shape) and prints the function logs so the
 * Resend response is visible.
 *
 *   node scripts/test_send_email.mjs someone@example.com
 */

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const recipient = process.argv[2];

if (!recipient) {
  console.error('Usage: node scripts/test_send_email.mjs <recipient@example.com>');
  process.exit(1);
}

function request(apiPath, method, body) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: '/v1' + apiPath,
      method,
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function execute(payload, label) {
  console.log(`\n--- ${label} ---`);
  const res = await request('/functions/send_email/executions', 'POST', {
    body: JSON.stringify(payload),
    async: false,
  });
  console.log('HTTP', res.status);

  const executionId = res.data && res.data['$id'];
  if (!executionId) {
    console.log('Response:', res.data);
    return;
  }

  const detail = await request(`/functions/send_email/executions/${executionId}`, 'GET');
  console.log('status:', detail.data.status, 'code:', detail.data.responseStatusCode);
  console.log('responseBody:', detail.data.responseBody);
  console.log('logs:', (detail.data.logs || '').trim());
  if (detail.data.errors) console.log('errors:', detail.data.errors.trim());
}

async function run() {
  await execute({
    to: recipient,
    subject: 'ALIVE Nigeria receipt email test',
    html: '<p>Generic transactional path (reply-to should be app@alivenigeria.org).</p>',
  }, 'Generic sendCustomEmail payload');

  await execute({
    action: 'send_welcome',
    email: recipient,
    name: 'Timothy',
  }, 'Welcome email payload');
}

run().catch(console.error);
