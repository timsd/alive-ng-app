import https from 'https';
import fs from 'fs';

/**
 * End-to-end smoke test for the payment + account functions:
 *
 *  1. get_exchange_rate              (live FX)
 *  2. initialize_transaction  NGN    (one-time, dynamic)
 *  3. initialize_transaction  USD    (one-time, USD->NGN conversion path)
 *  4. initialize_subscription NGN    (dynamic monthly plan)
 *  5. initialize_subscription USD    (dynamic monthly plan + conversion)
 *  6. list_subscriptions             (recurring giving list)
 *  7. delete_account without a session -> must be rejected (401)
 *  8. send_email with cc/reply_to    (must reach Resend with 200)
 *
 *   node scripts/smoke_test_payments.mjs [donor@example.com]
 */

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const donor = process.argv[2] || 'dammyolodude@gmail.com';

function execute(functionId, payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ body: JSON.stringify(payload), async: false });
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: `/v1/functions/${functionId}/executions`,
      method: 'POST',
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', async () => {
        try {
          const parsed = JSON.parse(data);
          const id = parsed['$id'];
          if (!id) return resolve({ http: res.statusCode, detail: parsed });

          let detail = parsed;
          // Appwrite only keeps a `responseBody` in the stored execution
          // RECORD for 200s. A 4xx body IS returned to the caller on the
          // original synchronous POST, but the polled record comes back with
          // an empty body -- so the create response is authoritative and the
          // poll is used only for logs.
          const createdBody = parsed.responseBody;
          for (let i = 0; i < 10; i++) {
            detail = await getExecution(functionId, id);
            if (detail.status === 'completed' || detail.status === 'failed') break;
            await new Promise((r) => setTimeout(r, 1500));
          }
          if (!detail.responseBody && createdBody) {
            detail = { ...detail, responseBody: createdBody };
          }
          resolve({ http: res.statusCode, detail });
        } catch (_) {
          resolve({ http: res.statusCode, detail: data });
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function getExecution(functionId, executionId) {
  return new Promise((resolve, reject) => {
    https.get({
      hostname: 'api.alivenigeria.org',
      path: `/v1/functions/${functionId}/executions/${executionId}`,
      headers: { 'X-Appwrite-Project': projectId, 'X-Appwrite-Key': apiKey },
    }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); } catch (_) { resolve({}); }
      });
    }).on('error', reject);
  });
}


/**
 * @param {string} label
 * @param {any} result
 * @param {number} [expectStatus] Status the function is EXPECTED to return.
 *   Defaults to 200. Negative cases (e.g. a below-minimum recurring gift that
 *   must be refused) pass 400 so the guard itself is smoke tested.
 */
function summarise(label, result, expectStatus = 200) {
  const d = result.detail || {};
  let payload;
  try {
    payload = typeof d.responseBody === 'string' && d.responseBody
      ? JSON.parse(d.responseBody)
      : null;
  } catch (_) {
    payload = d.responseBody || null;
  }

  const status = d.responseStatusCode ?? result.http;
  let ok = status === expectStatus;
  if (ok) {
    // A 200 must carry a usable payload; a 4xx must actually explain itself.
    if (expectStatus === 200) {
      ok = !payload || (!payload.error && payload.ok !== false);
    } else {
      ok = !!payload && !!payload.error;
    }
  }

  console.log(`\n[${ok ? 'PASS' : 'FAIL'}] ${label}`);
  console.log(`  http=${d.responseStatusCode ?? result.http} status=${d.status ?? 'n/a'}`);
  if (payload) {
    const brief = {
      ...(payload.authorization_url ? { authorization_url: '<present>' } : {}),
      ...(payload.plan_code ? { plan_code: payload.plan_code } : {}),
      ...(payload.success !== undefined ? { success: payload.success } : {}),
      ...(payload.status !== undefined ? { status: payload.status } : {}),
      ...(payload.ok !== undefined ? { ok: payload.ok } : {}),
      ...(payload.count !== undefined ? { count: payload.count } : {}),
      ...(payload.rate !== undefined ? { rate: payload.rate, source: payload.source } : {}),
      ...(payload.error ? { error: payload.error } : {}),
      ...(payload.message ? { message: payload.message } : {}),
    };
    console.log('  payload:', JSON.stringify(brief));
  }
  if (d.errors) console.log('  errors:', d.errors.trim());
  if (d.logs) console.log('  logs:', d.logs.trim().split('\n').slice(-3).join(' | '));
  return ok;
}

const stamp = Date.now().toString(36).toUpperCase();
const checks = [];

async function run() {
  console.log(`Smoke testing as donor: ${donor}`);

  checks.push(summarise('get_exchange_rate', await execute('paystack_payments', {
    action: 'get_exchange_rate',
  })));

  checks.push(summarise('initialize_transaction NGN', await execute('paystack_payments', {
    action: 'initialize_transaction',
    amount: 10000,
    currency: 'NGN',
    email: donor,
    reference: `SMOKE-NGN1-${stamp}`,
  })));

  checks.push(summarise('initialize_transaction USD', await execute('paystack_payments', {
    action: 'initialize_transaction',
    amount: 500,
    currency: 'USD',
    email: donor,
    reference: `SMOKE-USD1-${stamp}`,
  })));

  // Paystack plan amounts are in kobo with a hard floor of N100 (10000 kobo),
  // so 5000 (=N50) is deliberately below the minimum. Verified live via
  // scripts/probe_plan_api.mjs.
  checks.push(summarise('initialize_subscription NGN (dynamic plan)', await execute('paystack_payments', {
    action: 'initialize_subscription',
    amount: 20000, // N200/month
    currency: 'NGN',
    email: donor,
    reference: `SMOKE-SUB-NGN-${stamp}`,
  })));

  // $5/mo converts to ~N6,600 at the live rate: well above the plan floor.
  checks.push(summarise('initialize_subscription USD (dynamic plan + conversion)', await execute('paystack_payments', {
    action: 'initialize_subscription',
    amount: 500,
    currency: 'USD',
    email: donor,
    reference: `SMOKE-SUB-USD-${stamp}`,
  })));

  // Negative check: below Paystack's N100/month floor must be refused with a
  // clear message rather than a raw Paystack error.
  const tinySub = await execute('paystack_payments', {
    action: 'initialize_subscription',
    amount: 5000, // N50 < N100 floor
    currency: 'NGN',
    email: donor,
    reference: `SMOKE-SUB-TINY-${stamp}`,
  });
  checks.push(summarise('initialize_subscription below minimum is refused', tinySub, 400));

  checks.push(summarise('list_subscriptions', await execute('paystack_payments', {
    action: 'list_subscriptions',
    email: donor,
  })));

  const noAuth = await execute('delete_account', { user_id: 'smoke-test-user' });
  const refused = !!(noAuth.detail && noAuth.detail.responseStatusCode === 401);
  checks.push(refused);
  console.log(`\n[${refused ? 'PASS' : 'FAIL'}] delete_account rejects unauthenticated call`);
  console.log('  http=', noAuth.detail && noAuth.detail.responseStatusCode);

  checks.push(summarise('send_email (cc + reply_to support mailbox)', await execute('send_email', {
    to: donor,
    subject: 'ALIVE Nigeria smoke test',
    html: '<p>Smoke test — copy and reply should reach app@alivenigeria.org.</p>',
  })));

  const passed = checks.filter(Boolean).length;
  console.log('\n==============================================');
  console.log(`${passed}/${checks.length} checks passed`);
  console.log('==============================================');
  if (passed !== checks.length) process.exitCode = 1;
}

run().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});

