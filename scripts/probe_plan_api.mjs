/**
 * One-off diagnostic: what does the Paystack plan API accept?
 *  - is `amount` in kobo or naira?
 *  - must it be an integer?
 *  - is USD plan creation possible at all?
 * Run: node scripts/probe_plan_api.mjs
 */
import fs from 'node:fs';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};
const secret = getEnv('PAYSTACK_SECRET_KEY');

async function createPlan(label, body) {
  const resp = await fetch('https://api.paystack.co/plan', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${secret}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const json = await resp.json();
  console.log(`${label}\n   -> ${json.status ? 'OK plan_code=' + json.data.plan_code + ' amount=' + json.data.amount : 'FAIL ' + json.message}`);
  return json;
}

await createPlan('A) amount=1000000 (kobo) NGN', {
  name: `PROBE A ${Date.now()}`,
  interval: 'monthly',
  amount: 1000000,
  currency: 'NGN',
});

await createPlan('B) amount=10000 (kobo) NGN', {
  name: `PROBE B ${Date.now()}`,
  interval: 'monthly',
  amount: 10000,
  currency: 'NGN',
});

await createPlan('C) amount=1000 (NGN, not kobo)', {
  name: `PROBE C ${Date.now()}`,
  interval: 'monthly',
  amount: 1000,
  currency: 'NGN',
});

await createPlan('D) amount=1000 as string', {
  name: `PROBE D ${Date.now()}`,
  interval: 'monthly',
  amount: '1000',
  currency: 'NGN',
});

await createPlan('E) USD plan', {
  name: `PROBE E ${Date.now()}`,
  interval: 'monthly',
  amount: 1000,
  currency: 'USD',
});

await createPlan('F) below minimum (amount=50)', {
  name: `PROBE F ${Date.now()}`,
  interval: 'monthly',
  amount: 50,
  currency: 'NGN',
});
