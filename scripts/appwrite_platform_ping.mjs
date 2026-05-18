const endpoint =
  process.env.APPWRITE_ENDPOINT ||
  'http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID || '6a088e5f0003764bde50';
const webOrigin = process.env.APPWRITE_WEB_ORIGIN || 'https://app.alivenigeria.org';

async function ping(path, headers = {}) {
  const response = await fetch(`${endpoint}${path}`, {
    headers: {
      'X-Appwrite-Project': projectId,
      ...headers,
    },
  });
  const text = await response.text();
  return {
    path,
    status: response.status,
    allowOrigin: response.headers.get('access-control-allow-origin'),
    server: response.headers.get('server'),
    body: text.slice(0, 180),
  };
}

const checks = [
  ping('/account', { Origin: webOrigin }),
  ping('/account', {
    'X-SDK-Name': 'Flutter',
    'X-SDK-Language': 'dart',
    'X-SDK-Platform': 'client',
  }),
];

for (const result of await Promise.all(checks)) {
  console.log(JSON.stringify(result, null, 2));
}

console.log(
  '\nA 401 on /account is OK for this ping: it means Appwrite is reachable, ' +
    'the project header was accepted, and no user session was supplied.',
);
