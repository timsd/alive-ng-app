import https from 'https';
import fs from 'fs';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';

const options = {
  hostname: 'api.alivenigeria.org',
  path: '/v1/functions',
  method: 'GET',
  headers: {
    'X-Appwrite-Project': projectId,
    'X-Appwrite-Key': apiKey,
  }
};

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => {
    console.log('Functions Status:', res.statusCode);
    try {
      const json = JSON.parse(body);
      if (json.functions) {
        console.log('Total Functions:', json.total);
        for (const f of json.functions) {
          console.log(`- ID: ${f.$id} | Name: ${f.name} | Runtime: ${f.runtime} | Deployment: ${f.deployment || 'none'}`);
        }
      } else {
        console.log('Body:', body);
      }
    } catch (e) {
      console.log('Error parsing JSON:', e.message, body);
    }
  });
});

req.on('error', (err) => console.error('Req error:', err));
req.end();
