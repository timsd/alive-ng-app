import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';

const GIT = 'C:\\Program Files\\Git\\bin\\git.exe';
const REPO = 'C:\\Users\\Timothy Olodude\\Documents\\ZavTech Projects\\alive-ng-app';
const out = [];

function run(args) {
  try {
    return execFileSync(GIT, args, {
      cwd: REPO,
      encoding: 'utf8',
      env: { ...process.env },
    }).trim();
  } catch (e) {
    return 'ERR: ' + (e.stderr ? e.stderr.toString().trim() : e.message);
  }
}

out.push('=== VER ===');
out.push(run(['--version']));
out.push('');
out.push('=== REMOTE ===');
out.push(run(['remote', '-v']));
out.push('');
out.push('=== STATUS ===');
out.push(run(['status', '--short']));
out.push('');
out.push('=== LOG ===');
out.push(run(['log', '--oneline', '-8']));
out.push('');
out.push('=== BRANCH ===');
out.push(run(['branch', '--show-current']));

writeFileSync('gitinfo.txt', out.join('\n'), 'utf8');
console.log('written');