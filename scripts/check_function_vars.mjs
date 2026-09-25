import https from 'https';
import fs from 'fs';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';

function apiGet(path) {
  return new Promise((resolve, reject) => {
    https.get({
      hostname: 'api.alivenigeria.org',
      path: '/v1' + path,
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
      }
    }, (res) => {
      let b = '';
      res.on('data', c => b += c);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(b) });
        } catch (_) {
          resolve({ status: res.statusCode, data: b });
        }
      });
    }).on('error', reject);
  });
}

async function run() {
  const res = await apiGet('/functions');
  for (const f of res.data.functions) {
    const id = f['$id'];
    console.log(`\n=== Function: ${id} (${f.name}) ===`);
    console.log(`  runtime: ${f.runtime}`);
    console.log(`  execute: ${JSON.stringify(f.execute)}`);
    console.log(`  events:  ${JSON.stringify(f.events || [])}`);
    console.log(`  schedule: ${f.schedule || '(none)'}`);
    console.log(`  active deployment: ${f.deploymentId || f.deployment || '(none)'}`);

    const vars = await apiGet(`/functions/${id}/variables`);
    const variables = (vars.data && vars.data.variables) || [];
    for (const v of variables) {
      console.log(`  ${v.key} = ${v.secret ? '[SECRET]' : v.value}`);
    }

    // Sanity checks specific to transactional email delivery.
    if (id === 'send_email' || id === 'paystack_payments' || id === 'paystack_webhook') {
      const keys = variables.map((v) => v.key);
      if (!keys.includes('RESEND_API_KEY')) {
        console.log('  ⚠ RESEND_API_KEY missing — outbound email will be skipped/rejected.');
      }
      const sender = variables.find((v) => v.key === 'RECEIPT_SENDER_EMAIL' || v.key === 'SENDER_EMAIL');
      if (sender && !/@app\.alivenigeria\.org>?$/.test(sender.value)) {
        console.log(`  ⚠ ${sender.key} does not use the verified app.alivenigeria.org domain.`);
      }
      if (!keys.includes('REPLY_TO_EMAIL')) {
        console.log('  ⚠ REPLY_TO_EMAIL missing — falling back to the built-in default reply-to.');
      }
    }

    if (id === 'send_email' && !(f.events || []).includes('users.*.create')) {
      console.log('  ⚠ users.*.create trigger missing — automatic welcome emails will not fire.');
    }
  }
}

run().catch(console.error);
