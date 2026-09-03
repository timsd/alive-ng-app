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

out.push('=== COMMIT 0f9649cf FILES ===');
out.push(run(['show', '--stat', '--oneline', '0f9649cf']));
out.push('');
out.push('=== SHOW HEAD ===');
out.push(run(['show', '--stat', '--oneline', 'HEAD']));
out.push('');
out.push('=== STATUS -sb ===');
out.push(run(['status', '-sb']));
out.push('');
out.push('=== AHEAD/BEHIND ===');
out.push(run(['rev-list', '--left-right', '--count', 'origin/master...HEAD']));
out.push('');
out.push('=== REMOTE BRANCHES ===');
out.push(run(['branch', '-r']));
out.push('');
out.push('=== UNTRACKED ===');
out.push(run(['status', '--porcelain']));

writeFileSync('gitinfo2.txt', out.join('\n'), 'utf8');
console.log('written');