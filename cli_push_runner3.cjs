const fs = require('fs');
const { spawnSync } = require('child_process');

const run = 'node_modules/appwrite-cli/run.js';
const raw = fs.readFileSync('.env', 'utf8');
const envLines = raw.split(/\r?\n/);
const vars = {};
for (const line of envLines) {
  const trimmed = line.trim();
  if (!trimmed || !trimmed.includes('=')) continue;
  const isCommented = trimmed.startsWith('#');
  const clean = isCommented ? trimmed.slice(1).trim() : trimmed;
  if (!clean || !clean.includes('=')) continue;
  const idx = clean.indexOf('=');
  const key = clean.slice(0, idx).trim();
  const val = clean.slice(idx + 1).trim().replace(/^["']|["']$/g, '');
  if (key.startsWith('APPWRITE') && val) vars[key] = val;
}

const endpoint = vars.APPWRITE_ENDPOINT || 'https://api.alivenigeria.org/v1';
const projectId = vars.APPWRITE_PROJECT_ID || '6a3bef53002f5090dedf';
const funcKey = vars.APPWRITE_FUNCTION_API_KEY || vars.APPWRITE_API_KEY;
if (!funcKey) {
  console.error('NO KEY');
  process.exit(1);
}

const out = ['KEY_SOURCE: ' + (vars.APPWRITE_FUNCTION_API_KEY ? 'function_key' : 'api_key')];

let r = spawnSync(
  process.execPath,
  [run, 'client', '--endpoint', endpoint, '--project-id', projectId, '--key', funcKey],
  { cwd: process.cwd(), encoding: 'utf8' }
);
out.push('===== CLIENT =====\n' + (r.stdout || '') + (r.stderr || ''));

r = spawnSync(
  process.execPath,
  [run, 'push', 'functions', '--all', '--force'],
  { cwd: process.cwd(), encoding: 'utf8', timeout: 600000 }
);
out.push('===== PUSH =====\n' + (r.stdout || '') + (r.stderr || ''));

fs.writeFileSync('cli_push_log2.txt', out.join('\n'), 'utf8');
console.log('done exit=' + r.status);