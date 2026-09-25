import https from 'https';
import fs from 'fs';

const envContent = fs.readFileSync('.env', 'utf8');
const m = envContent.match(/^RESEND_API_KEY=(.*)$/m);
const apiKey = m ? m[1].trim() : '';

const req = https.request({
  hostname: 'api.resend.com',
  path: '/domains',
  method: 'GET',
  headers: {
    'Authorization': `Bearer ${apiKey}`,
    'User-Agent': 'node-client'
  }
}, res => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => console.log('Resend domains:', res.statusCode, d));
});
req.on('error', console.error);
req.end();
