import https from 'https';
import fs from 'fs';

/**
 * Verifies recent Paystack donations directly against the Paystack API so we can
 * tell whether a receipt was skipped because the transaction never completed on
 * Paystack's side, or because our own verification path never ran.
 *
 *   node scripts/check_paystack_status.mjs <reference> [<reference> ...]
 */

const envContent = fs.readFileSync('.env', 'utf8');
const secret = (envContent.match(/^PAYSTACK_SECRET_KEY=(.*)$/m) || [])[1].trim();

function verify(reference) {
  return new Promise((resolve, reject) => {
    https.get({
      hostname: 'api.paystack.co',
      path: `/transaction/verify/${encodeURIComponent(reference)}`,
      headers: { Authorization: `Bearer ${secret}` },
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
    }).on('error', reject);
  });
}

async function run() {
  const references = process.argv.slice(2);
  if (references.length === 0) {
    console.error('Usage: node scripts/check_paystack_status.mjs <reference> [...]');
    process.exit(1);
  }

  for (const ref of references) {
    const res = await verify(ref);
    const d = res.data && res.data.data;
    console.log(`\n${ref}`);
    console.log('  http:', res.status, 'api status:', res.data && res.data.status);
    if (d) {
      console.log('  paystack status:', d.status, '| amount:', d.amount, d.currency, '| paid_at:', d.paid_at);
      console.log('  customer:', d.customer && d.customer.email);
      console.log('  channel:', d.channel, '| gateway:', d.gateway_response);
    } else {
      console.log('  message:', res.data && res.data.message);
    }
  }
}

run().catch(console.error);
