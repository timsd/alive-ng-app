/**
 * Finds the most recently delivered Resend message whose subject matches a
 * query, and prints the visible text of its HTML body.
 *
 * Used to confirm a receipt template change actually shipped, rather than
 * trusting that the function "returned 200".
 *
 *   node scripts/check_receipt_email.mjs "Donation Receipt"
 */
import https from 'https';
import fs from 'fs';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};
const apiKey = getEnv('RESEND_API_KEY');
const query = process.argv[2] || 'Donation Receipt';

function api(path) {
  return new Promise((resolve, reject) => {
    https.get(
      { hostname: 'api.resend.com', path, headers: { Authorization: `Bearer ${apiKey}` } },
      (res) => {
        let d = '';
        res.on('data', (c) => (d += c));
        res.on('end', () => {
          try { resolve(JSON.parse(d)); } catch { resolve({}); }
        });
      },
    ).on('error', reject);
  });
}

const listed = await api('/emails?limit=25');
const messages = listed?.data || [];
const match = messages.find((m) => (m.subject || '').toLowerCase().includes(query.toLowerCase()));

if (!match) {
  console.log(`No recent message with subject containing "${query}".`);
  console.log('Recent subjects:');
  for (const m of messages) console.log(`  - ${m.subject}`);
  process.exit(0);
}

const full = await api(`/emails/${match.id}`);
const html = full?.html || '';
// Strip tags so the wording is actually readable in the output.
const text = html
  .replace(/<style[\s\S]*?<\/style>/gi, ' ')
  .replace(/<[^>]+>/g, ' ')
  .replace(/&mdash;/g, '—')
  .replace(/&nbsp;/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

console.log(`id:      ${full.id}`);
console.log(`from:    ${full.from}`);
console.log(`to:      ${(full.to || []).join(', ')}`);
console.log(`subject: ${full.subject}`);
console.log(`event:   ${full.last_event}`);
console.log('--- visible body text ---');
console.log(text);
console.log('--- branding check ---');
console.log(`contains "Ministries": ${/ministries/i.test(text)}`);
console.log(`contains "ALIVE Nigeria": ${text.includes('ALIVE Nigeria')}`);
