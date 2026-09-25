import https from 'https';
import fs from 'fs';

/**
 * Confirms (a) which domains are verified in Resend for sending, and
 * (b) that a message sent with our production payload carries the expected
 * Reply-To header.
 *
 *   node scripts/verify_email_delivery.mjs
 */

const envContent = fs.readFileSync('.env', 'utf8');
const apiKey = (envContent.match(/^RESEND_API_KEY=(.*)$/m) || [])[1].trim();

function resend(apiPath, method = 'GET', payload = null) {
  return new Promise((resolve, reject) => {
    const body = payload ? JSON.stringify(payload) : null;
    const req = https.request({
      hostname: 'api.resend.com',
      path: apiPath,
      method,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'User-Agent': 'alive-ng-app-verify',
        ...(body ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } : {}),
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
    if (body) req.write(body);
    req.end();
  });
}

async function run() {
  const domains = await resend('/domains');
  console.log('Verified sending domains:');
  for (const d of (domains.data.data || [])) {
    console.log(`  ${d.name} -> status=${d.status} sending=${d.capabilities && d.capabilities.sending}`);
  }

  const from = 'ALIVE Nigeria App <receipts@app.alivenigeria.org>';
  const replyTo = 'app@alivenigeria.org';
  const send = await resend('/emails', 'POST', {
    from,
    to: ['delivered@resend.dev'],
    reply_to: replyTo,
    subject: 'ALIVE Nigeria reply-to verification',
    html: '<p>Verifying Reply-To configuration.</p>',
  });
  console.log('\nSend status:', send.status, JSON.stringify(send.data));

  const id = send.data && send.data.id;
  if (!id) return;

  await new Promise((r) => setTimeout(r, 2000));
  const detail = await resend(`/emails/${id}`);
  console.log('\nMessage detail:', detail.status);
  console.log(JSON.stringify(detail.data, null, 2));
}

run().catch(console.error);
