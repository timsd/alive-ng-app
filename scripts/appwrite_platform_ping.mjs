const endpoint =
  process.env.APPWRITE_ENDPOINT ||
  'http://appwrite-he4p5j9b9dj42v5nzeklu2u3.84.8.219.248.sslip.io/v1';
const projectId = process.env.APPWRITE_PROJECT_ID || '6a088e5f0003764bde50';
const webOrigin = process.env.APPWRITE_WEB_ORIGIN || 'https://app.alivenigeria.org';

async function ping(path, headers = {}) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 20000);
    const response = await fetch(`${endpoint}${path}`, {
      headers: {
        'X-Appwrite-Project': projectId,
        ...headers,
      },
      signal: controller.signal,
    });
    clearTimeout(timeout);

    const text = await response.text();
    return {
      ok: true,
      path,
      status: response.status,
      allowOrigin: response.headers.get('access-control-allow-origin'),
      server: response.headers.get('server'),
      body: text.slice(0, 180),
    };
  } catch (error) {
    return {
      ok: false,
      path,
      error: error?.cause?.code || error?.name || 'FETCH_FAILED',
      message: error?.cause?.message || error?.message || String(error),
    };
  }
}

const checks = [
  ping('/account', { Origin: webOrigin }),
  ping('/account', {
    'X-SDK-Name': 'Flutter',
    'X-SDK-Language': 'dart',
    'X-SDK-Platform': 'client',
  }),
];

const results = await Promise.all(checks);

for (const result of results) {
  console.log(JSON.stringify(result, null, 2));
}

if (results.every((result) => result.ok)) {
  console.log(
    '\nA 401 on /account is OK for this ping: it means Appwrite is reachable, ' +
      'the project header was accepted, and no user session was supplied.',
  );
} else {
  console.log(
    '\nPing could not reach Appwrite from this machine. Check the Appwrite/Coolify proxy, ' +
      'server firewall, DNS, or temporary network reachability, then rerun npm run appwrite:ping.',
  );
}
