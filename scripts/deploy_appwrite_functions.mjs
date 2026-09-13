import fs from 'fs';
import path from 'path';
import https from 'https';
import { execSync } from 'child_process';

const envContent = fs.readFileSync('.env', 'utf8');
const getEnv = (k) => {
  const m = envContent.match(new RegExp('^' + k + '=(.*)$', 'm'));
  return m ? m[1].trim() : '';
};

const apiKey = getEnv('APPWRITE_API_KEY');
const projectId = getEnv('APPWRITE_PROJECT_ID') || '6a3bef53002f5090dedf';
const endpoint = getEnv('APPWRITE_ENDPOINT') || 'https://api.alivenigeria.org/v1';
const host = new URL(endpoint).hostname;

async function request(path, method = 'GET', body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const defaultHeaders = {
      'X-Appwrite-Project': projectId,
      'X-Appwrite-Key': apiKey,
      ...headers
    };
    if (body && typeof body === 'string' && !defaultHeaders['Content-Type']) {
      defaultHeaders['Content-Type'] = 'application/json';
    }

    const req = https.request({
      hostname: host,
      path: '/v1' + path,
      method: method,
      headers: defaultHeaders,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({ status: res.statusCode, data: json });
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

// 1. Verify / create start_livekit_broadcast function entity
async function ensureFunctionExists(config) {
  const check = await request(`/functions/${config.$id}`);
  if (check.status === 200) {
    console.log(`Function ${config.$id} already exists on Appwrite.`);
    return;
  }

  console.log(`Creating function ${config.$id}...`);
  const createPayload = JSON.stringify({
    functionId: config.$id,
    name: config.name,
    runtime: config.runtime || 'node-20.0',
    execute: config.execute || ['users'],
    events: config.events || [],
    schedule: config.schedule || '',
    timeout: config.timeout || 30,
    enabled: config.enabled ?? true,
    logging: config.logging ?? true,
    entrypoint: config.entrypoint || 'src/main.js',
    commands: config.commands || 'npm install',
    scopes: config.scopes || []
  });

  const res = await request('/functions', 'POST', createPayload);
  console.log(`Create function result:`, res.status, res.data.message || res.data.$id);
}

// 2. Set function environment variables
async function setFunctionVariables(functionId, vars) {
  const existingRes = await request(`/functions/${functionId}/variables`);
  const existingVars = existingRes.data.variables || [];
  const existingMap = new Map(existingVars.map(v => [v.key, v.$id]));

  for (const [key, value] of Object.entries(vars)) {
    if (!value) continue;
    if (existingMap.has(key)) {
      const varId = existingMap.get(key);
      await request(`/functions/${functionId}/variables/${varId}`, 'PUT', JSON.stringify({ key, value }));
      console.log(`Updated var ${key} for ${functionId}`);
    } else {
      await request(`/functions/${functionId}/variables`, 'POST', JSON.stringify({ key, value }));
      console.log(`Created var ${key} for ${functionId}`);
    }
  }
}

// 3. Package and upload deployment using multipart/form-data
async function deployFunction(functionId, folderPath, entrypoint = 'src/main.js', commands = 'npm install') {
  console.log(`Packaging ${folderPath} for deployment...`);
  const tarFile = path.resolve(`.tmp_${functionId}.tar.gz`);
  
  // Use tar to create archive (Windows 10+ has tar builtin)
  try {
    if (fs.existsSync(tarFile)) fs.unlinkSync(tarFile);
    // cd into folder and create tar.gz of all files
    execSync(`tar -czf "${tarFile}" -C "${folderPath}" .`, { stdio: 'inherit' });
  } catch (e) {
    console.error(`Tar error for ${functionId}:`, e.message);
    return;
  }

  const fileBytes = fs.readFileSync(tarFile);
  const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);

  let pre = '';
  // entrypoint
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="entrypoint"\r\n\r\n${entrypoint}\r\n`;
  // commands
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="commands"\r\n\r\n${commands}\r\n`;
  // activate
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="activate"\r\n\r\ntrue\r\n`;
  // code
  pre += `--${boundary}\r\nContent-Disposition: form-data; name="code"; filename="code.tar.gz"\r\nContent-Type: application/gzip\r\n\r\n`;

  const post = `\r\n--${boundary}--\r\n`;

  const bodyBuffer = Buffer.concat([
    Buffer.from(pre, 'utf8'),
    fileBytes,
    Buffer.from(post, 'utf8')
  ]);

  console.log(`Uploading deployment for ${functionId} (${bodyBuffer.length} bytes)...`);

  const res = await request(`/functions/${functionId}/deployments`, 'POST', bodyBuffer, {
    'Content-Type': `multipart/form-data; boundary=${boundary}`,
    'Content-Length': bodyBuffer.length
  });

  console.log(`Deploy ${functionId} status:`, res.status, res.data.status || res.data.message || res.data);
  try { fs.unlinkSync(tarFile); } catch (_) {}

  // Appwrite ignores the multipart 'activate' flag. We must PATCH to activate.
  const deploymentId = res.data?.$id;
  if (deploymentId && (res.status === 200 || res.status === 201 || res.status === 202)) {
    console.log(`Waiting for deployment ${deploymentId} to build...`);
    let ready = false;
    for (let i = 0; i < 30; i++) {
      await new Promise(r => setTimeout(r, 3000));
      const check = await request(`/functions/${functionId}/deployments/${deploymentId}`);
      const st = check.data?.status;
      console.log(`  Build status: ${st}`);
      if (st === 'ready') { ready = true; break; }
      if (st === 'failed') { console.error('  ❌ Build failed!'); break; }
    }
    if (ready) {
      const activateRes = await request(`/functions/${functionId}/deployments/${deploymentId}`, 'PATCH', '');
      console.log(`  Activated: ${activateRes.status}`);
    }
  }
}

async function run() {
  const configFile = JSON.parse(fs.readFileSync('appwrite.config.json', 'utf8'));
  
  for (const fn of configFile.functions) {
    console.log(`\n========================================`);
    console.log(`Processing ${fn.name} (${fn.$id})...`);
    await ensureFunctionExists(fn);

    // Set env vars for start_livekit_broadcast
    if (fn.$id === 'start_livekit_broadcast') {
      await setFunctionVariables(fn.$id, {
        LIVEKIT_URL: getEnv('LIVEKIT_URL') || 'wss://livekit.alivenigeria.org',
        LIVEKIT_API_KEY: getEnv('LIVEKIT_API_KEY'),
        LIVEKIT_API_SECRET: getEnv('LIVEKIT_API_SECRET'),
        YOUTUBE_STREAM_KEY: getEnv('YOUTUBE_STREAM_KEY'),
        YOUTUBE_STREAM_URL: getEnv('YOUTUBE_STREAM_URL') || 'rtmp://a.rtmp.youtube.com/live2',
        YOUTUBE_BACKUP_STREAM_URL: getEnv('YOUTUBE_BACKUP_STREAM_URL') || 'rtmp://b.rtmp.youtube.com/live2?backup=1',
        APPWRITE_ENDPOINT: endpoint,
        APPWRITE_PROJECT_ID: projectId,
        APPWRITE_API_KEY: apiKey,
        APPWRITE_DATABASE_ID: getEnv('APPWRITE_DATABASE_ID') || '6a089307002e54291a32',
      });
    } else if (fn.$id === '6a08e9010035dc8c1e51') { // createLiveKitToken
      await setFunctionVariables(fn.$id, {
        LIVEKIT_URL: getEnv('LIVEKIT_URL') || 'wss://livekit.alivenigeria.org',
        LIVEKIT_API_KEY: getEnv('LIVEKIT_API_KEY'),
        LIVEKIT_API_SECRET: getEnv('LIVEKIT_API_SECRET'),
      });
    }

    // Deploy code
    if (fs.existsSync(fn.path)) {
      await deployFunction(fn.$id, fn.path, fn.entrypoint, fn.commands);
    } else {
      console.log(`Path ${fn.path} does not exist locally.`);
    }
  }
}

run().catch(console.error);
