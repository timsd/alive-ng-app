import https from 'https';
import fs from 'fs';

/**
 * Probes whether the local standard API key carries the `users.write` scope
 * (needed for server-side account deletion) without touching a real account:
 * `DELETE /users/<nonexistent>` returns 404 when the scope is present and
 * 401/403 "missing scope" when it is not.
 *
 *   node scripts/probe_users_scope.mjs
 */

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';

function request(method, apiPath, body = null) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: '/v1' + apiPath,
      method,
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        ...(body ? { 'Content-Type': 'application/json' } : {}),
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
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  console.log('DELETE /users/nonexistent_smoke_test_user (scope probe):');
  const probe = await request('DELETE', '/users/nonexistent_smoke_test_user');
  console.log(' status:', probe.status);
  console.log(' body:', JSON.stringify(probe.data));

  if (probe.status === 404) {
    console.log('=> key HAS users.write/users.delete scope.');
  } else if (probe.status === 401 || probe.status === 403) {
    console.log('=> key is MISSING the users.write/users.delete scope.');
  } else {
    console.log('=> unexpected response, inspect manually.');
  }
}

run().catch(console.error);
