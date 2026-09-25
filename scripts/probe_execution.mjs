/**
 * Reads a raw Appwrite function execution and prints every field, so we can
 * tell whether a non-2xx response really persists its body.
 *
 *   node scripts/probe_execution.mjs <functionId> <bodyJsonFile>
 *
 * The body comes from a FILE on purpose: passing JSON inline through PowerShell
 * mangles the quotes into garbage before node ever sees it.
 */
import https from 'https';
import fs from 'fs';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};
const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';

const functionId = process.argv[2];
const payload = process.argv[3]
  ? fs.readFileSync(process.argv[3], 'utf8')
  : '{}';

function post(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path,
      method: 'POST',
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    }, (res) => {
      let out = '';
      res.on('data', (c) => (out += c));
      res.on('end', () => resolve({ status: res.statusCode, out }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path) {
  return new Promise((resolve, reject) => {
    https.get({
      hostname: 'api.alivenigeria.org',
      path,
      headers: { 'X-Appwrite-Project': projectId, 'X-Appwrite-Key': apiKey },
    }, (res) => {
      let out = '';
      res.on('data', (c) => (out += c));
      res.on('end', () => resolve({ status: res.statusCode, out }));
    }).on('error', reject);
  });
}

async function main() {
  const created = await post(`/v1/functions/${functionId}/executions`, {
    body: payload,
    async: false,
  });
  console.log('--- RAW SYNC HTTP RESPONSE ---');
  console.log(`http=${created.status}`);
  console.log(created.out);
  console.log('--- EXECUTION RECORD ---');

  const parsed = JSON.parse(created.out);
  const id = parsed.$id;
  for (let i = 0; i < 10; i++) {
    const cur = JSON.parse((await get(`/v1/functions/${functionId}/executions/${id}`)).out);
    if (cur.status === 'completed' || cur.status === 'failed') {
      console.log('--- FULL EXECUTION ---');
      console.log(JSON.stringify({
        status: cur.status,
        responseStatusCode: cur.responseStatusCode,
        responseBody: cur.responseBody,
        errors: cur.errors,
        logs: cur.logs,
      }, null, 2));
      return;
    }
    await new Promise((r) => setTimeout(r, 1500));
  }
  console.log('timed out');
}

await main();
