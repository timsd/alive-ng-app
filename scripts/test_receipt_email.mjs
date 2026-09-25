import https from 'https';
import fs from 'fs';

/**
 * End-to-end check of the donation receipt email path.
 *
 * Re-runs `verify_transaction` for an already-completed donation so the
 * deployed `paystack_payments` function performs its real receipt flow
 * (Resend call with the configured From + Reply-To). Because that flow also
 * adds the amount to the project's raised total, this script snapshots the
 * project counters first and restores them afterwards so the check is
 * side-effect free.
 *
 *   node scripts/test_receipt_email.mjs <completed-reference> <project-id>
 */

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const databaseId = getEnv('APPWRITE_DATABASE_ID') || '6a089307002e54291a32';

const reference = process.argv[2];
const projectDocId = process.argv[3];

if (!reference) {
  console.error('Usage: node scripts/test_receipt_email.mjs <completed-reference> [project-id]');
  process.exit(1);
}

function request(apiPath, method = 'GET', body = null, contentType = 'application/json') {
  return new Promise((resolve, reject) => {
    const headers = {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
    };
    if (body) headers['Content-Type'] = contentType;

    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: '/v1' + apiPath,
      method,
      headers,
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
    if (body) req.write(body);
    req.end();
  });
}

async function run() {
  let snapshot = null;

  if (projectDocId) {
    const before = await request(
      `/databases/${databaseId}/collections/projects/documents/${projectDocId}`,
    );
    const d = before.data || {};
    snapshot = {
      raised: typeof d.raised === 'number' ? d.raised : null,
      amount_raised: typeof d.amount_raised === 'number' ? d.amount_raised : null,
    };
    console.log('Project counters before:', snapshot);
  }

  console.log(`\nCalling paystack_payments verify_transaction for ${reference}...`);
  const exec = await request('/functions/paystack_payments/executions', 'POST', JSON.stringify({
    body: JSON.stringify({ action: 'verify_transaction', reference }),
    async: false,
  }));

  const executionId = exec.data && exec.data['$id'];
  if (!executionId) {
    console.log('No execution id. Response:', exec.data);
  } else {
    const detail = await request(`/functions/paystack_payments/executions/${executionId}`);
    console.log('status:', detail.data.status, 'code:', detail.data.responseStatusCode);
    console.log('logs:\n' + (detail.data.logs || '').trim());
    if (detail.data.errors) console.log('errors:', detail.data.errors.trim());
  }

  if (projectDocId && snapshot) {
    const patch = {};
    if (snapshot.raised !== null) patch.raised = snapshot.raised;
    if (snapshot.amount_raised !== null) patch.amount_raised = snapshot.amount_raised;
    if (Object.keys(patch).length > 0) {
      const restore = await request(
        `/databases/${databaseId}/collections/projects/documents/${projectDocId}`,
        'PATCH',
        JSON.stringify(patch),
      );
      console.log('Restored project counters:', restore.status, patch);
    }
  }
}

run().catch(console.error);
