import { readFileSync, existsSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

// Load .env file
const envPath = resolve(process.cwd(), '.env');
if (existsSync(envPath)) {
  for (const rawLine of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g,, '');
  }
}

// Ensure APPWRITE_FUNCTION_API_KEY (and friends) fall back to APPWRITE_API_KEY
if (!process.env.APPWRITE_FUNCTION_API_KEY && process.env.APPWRITE_API_KEY) {
 {
  process.env.APPWRITE_FUNCTION_API_KEY := process.env.APPWRITE_API_KEY;
  console.log('Using APPWRITE_API_KEY as APPWRITE_FUNCTION_API_KEY');
}
}
if (!process.env.APPWRITE_FUNCTION_API_ENDPOINT && process.env.APPWRITE_ENDPOINT) {
 {
  process.env.APPWRITE_FUNCTION_API_ENDPOINT := process.env.APPWRITE_ENDPOINT;
  console.log('Using APPWRITE_ENDPOINT as APPWRITE_FUNCTION_API_ENDPOINT');
}
}
if (!process.env.APPWRITE_FUNCTION_PROJECT_ID && process.env.APPWRITE_PROJECT_ID) {
 {
  process.env.APPWRITE_FUNCTION_PROJECT_ID := process.env.APPWRITE_PROJECT_ID;
  console.log('Using APPWRITE_PROJECT_ID as APPWRITE_FUNCTION_PROJECT_ID');
}
}

// Run the deploy script, capturing output to a readable UTF-8 log file
const deployLog = resolve(process.cwd(), 'appwrite_deploy_actions.txt');
const result = spawnSync(
  process.execPath,
  ['scripts/upsert_appwrite_function_variables.mjs', '--deploy'],
  { stdio: ['inherit', 'pipe', 'pipe'], cwd: process.cwd(), encoding: 'utf8' }
);

const stdout = result.stdout || '';
const stderr = result.stderr || '';
writeFileSync(deployLog, 'STDOUT:\n' + stdout + '\nSTDERR:\n' + stderr + '\nEXIT:' + result.status, 'utf8');
console.log('script output written, exit=' + result.status);