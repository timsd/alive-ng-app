const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const projectRoot = path.resolve(__dirname, '..');
const cliPath = path.resolve(projectRoot, 'node_modules/appwrite-cli/run.js');

// Parse .env
const rawEnv = fs.readFileSync(path.resolve(projectRoot, '.env'), 'utf8');
const env = {};
for (const line of rawEnv.split(/\r?\n/)) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
  const idx = trimmed.indexOf('=');
  const k = trimmed.slice(0, idx).trim();
  const v = trimmed.slice(idx + 1).trim().replace(/^['"]|['"]$/g, '');
  env[k] = v;
}

const endpoint = env.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1';
const projectId = env.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
const apiKey = env.APPWRITE_FUNCTION_API_KEY || env.APPWRITE_API_KEY;

console.log('--- Appwrite CLI Setup ---');
spawnSync(
  process.execPath,
  [cliPath, 'client', '--endpoint', endpoint, '--project-id', projectId, '--key', apiKey],
  { encoding: 'utf8', cwd: projectRoot }
);

const config = JSON.parse(fs.readFileSync(path.resolve(projectRoot, 'appwrite.config.json'), 'utf8'));
const functions = config.functions || [];

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function runCli(args) {
  const res = spawnSync(process.execPath, [cliPath, ...args], {
    cwd: projectRoot,
    encoding: 'utf8'
  });
  return {
    status: res.status,
    stdout: res.stdout || '',
    stderr: res.stderr || ''
  };
}

async function deployFunction(fn) {
  console.log(`\n========================================`);
  console.log(`Deploying: ${fn.name} (ID: ${fn.$id})`);
  console.log(`Path: ${fn.path}`);
  console.log(`Entrypoint: ${fn.entrypoint}`);
  console.log(`Commands: ${fn.commands}`);
  console.log(`========================================`);

  const deployRes = runCli([
    'functions', 'create-deployment',
    '--function-id', fn.$id,
    '--code', fn.path,
    '--entrypoint', fn.entrypoint || 'src/main.js',
    '--commands', fn.commands || 'npm install',
    '--activate', 'true'
  ]);

  if (deployRes.status !== 0) {
    console.error(`❌ Failed to create deployment for ${fn.name}:`);
    console.error(deployRes.stderr || deployRes.stdout);
    return { id: fn.$id, name: fn.name, success: false, error: deployRes.stderr || deployRes.stdout };
  }

  // Extract deployment ID from output
  const lines = deployRes.stdout.split(/\r?\n/);
  let deploymentId = null;
  for (const line of lines) {
    const match = line.match(/\$id\s*:\s*([a-zA-Z0-9_-]+)/);
    if (match) {
      deploymentId = match[1].trim();
      break;
    }
  }

  if (!deploymentId) {
    console.log(`Deployment response:\n${deployRes.stdout}`);
    console.warn(`Could not parse deployment ID, but deployment creation succeeded.`);
    return { id: fn.$id, name: fn.name, success: true, deploymentId: 'unknown' };
  }

  console.log(`Deployment created: ${deploymentId}. Waiting for build to finish...`);

  let buildStatus = 'waiting';
  let attempts = 0;
  const maxAttempts = 30; // 30 * 3s = 90s max per function
  while (attempts < maxAttempts) {
    await sleep(3000);
    attempts++;

    const getRes = runCli([
      'functions', 'get-deployment',
      '--function-id', fn.$id,
      '--deployment-id', deploymentId
    ]);

    for (const l of getRes.stdout.split(/\r?\n/)) {
      const match = l.match(/status\s*:\s*([a-zA-Z0-9_-]+)/);
      if (match) {
        buildStatus = match[1].trim();
        break;
      }
    }

    process.stdout.write(`Attempt ${attempts}: ${buildStatus}...\r`);

    if (buildStatus === 'ready' || buildStatus === 'failed') {
      break;
    }
  }

  console.log(`\nFinal status for ${fn.name} (${deploymentId}): ${buildStatus}`);
  return {
    id: fn.$id,
    name: fn.name,
    success: buildStatus === 'ready',
    deploymentId,
    status: buildStatus
  };
}

async function main() {
  const results = [];
  for (const fn of functions) {
    const res = await deployFunction(fn);
    results.push(res);
  }

  console.log('\n========================================');
  console.log('DEPLOYMENT SUMMARY');
  console.log('========================================');
  for (const r of results) {
    const icon = r.success ? '✅' : '❌';
    console.log(`${icon} [${r.id}] ${r.name}: ${r.status || 'FAILED'} (Deployment: ${r.deploymentId || 'none'})`);
  }

  // Also query remote functions list to verify active deployments
  console.log('\n--- Remote Functions State ---');
  const finalCheck = runCli(['functions', 'list']);
  console.log(finalCheck.stdout);
}

main().catch(err => {
  console.error('Fatal error in deployment script:', err);
  process.exit(1);
});
