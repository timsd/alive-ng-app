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
  console.log('Functions Status:', res.status);
  if (!res.data.functions) {
    console.log('Response:', res.data);
    return;
  }

  console.log('Total Functions:', res.data.total);
  for (const f of res.data.functions) {
    console.log(`\n- ID: ${f.$id} | Name: ${f.name} | Runtime: ${f.runtime} | Active: ${f.deployment || 'none'}`);
    const depRes = await apiGet(`/functions/${f.$id}/deployments`);
    if (depRes.data.deployments && depRes.data.deployments.length > 0) {
      for (const d of depRes.data.deployments) {
        console.log(`    ↳ Deployment ${d.$id}: status=${d.status}, size=${d.buildSize || d.sourceSize} bytes`);
      }
    } else {
      console.log('    ↳ No deployments found.');
    }
  }
}

run().catch(console.error);
