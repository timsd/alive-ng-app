import https from 'node:https';
import fs from 'node:fs';

const envContent = fs.existsSync('.env') ? fs.readFileSync('.env', 'utf8') : '';
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : (process.env[k] || '');
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const livekitUrl = getEnv('LIVEKIT_URL') || 'wss://livekit.alivenigeria.org';

async function main() {
  console.log('==============================================');
  console.log('🚀 1. SMOKE TEST: Appwrite Function createLiveKitToken');
  console.log('==============================================');
  
  const tokenPayload = JSON.stringify({
    body: JSON.stringify({
      roomName: 'alive-meet-community',
      participantName: 'Smoke Test Admin',
      identity: 'smoke-test-admin',
      meetingType: 'general',
    }),
    async: false,
  });

  const livekitRes = await new Promise((resolve) => {
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: '/v1/functions/6a08e9010035dc8c1e51/executions',
      method: 'POST',
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(tokenPayload),
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', (err) => resolve({ error: err.message }));
    req.write(tokenPayload);
    req.end();
  });
  console.log('createLiveKitToken result:', livekitRes.status, livekitRes.body?.responseBody || livekitRes.body);

  console.log('\n==============================================');
  console.log('🚀 2. SMOKE TEST: Resend Email Appwrite Function');
  console.log('==============================================');
  const emailPayload = JSON.stringify({
    body: JSON.stringify({
      action: 'send_welcome',
      email: 'dammyolodude@gmail.com',
      name: 'Timothy',
    }),
    async: false,
  });

  const emailRes = await new Promise((resolve) => {
    const req = https.request({
      hostname: 'api.alivenigeria.org',
      path: '/v1/functions/send_email/executions',
      method: 'POST',
      headers: {
        'X-Appwrite-Project': projectId,
        'X-Appwrite-Key': apiKey,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(emailPayload),
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', (err) => resolve({ error: err.message }));
    req.write(emailPayload);
    req.end();
  });
  console.log('send_email result:', emailRes.status, emailRes.body?.responseBody || emailRes.body);

  console.log('\n==============================================');
  console.log('🚀 3. SMOKE TEST: LiveKit Server HTTPS/WSS Connectivity');
  console.log('==============================================');
  const pingLiveKit = await new Promise((resolve) => {
    https.get('https://livekit.alivenigeria.org', (res) => {
      resolve({ status: res.statusCode });
    }).on('error', (err) => resolve({ error: err.message }));
  });
  console.log('livekit.alivenigeria.org status:', pingLiveKit);
}

main().catch(console.error);
