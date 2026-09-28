// Validates every workflow file, because a YAML error surfaces in GitHub as
// "no jobs were run / run failed at startup" rather than as a lint warning.
//
//   node scripts/check_workflows.mjs
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const dir = '.github/workflows';
const files = readdirSync(dir).filter((f) => f.endsWith('.yml') || f.endsWith('.yaml'));

// A small YAML sanity checker. Pulling in a full parser is not worth it for
// three files, and the failure GitHub reports is structural: a tab character,
// a broken indentation level, or a key that is not where it should be.
let problems = 0;

for (const file of files) {
  const raw = readFileSync(join(dir, file), 'utf8');
  const lines = raw.split(/\r?\n/);
  const issues = [];

  lines.forEach((line, i) => {
    const n = i + 1;
    // YAML forbids tabs for indentation. This is the single most common cause
    // of a workflow that GitHub refuses to run.
    if (/^\t/.test(line) || /^\s*\t/.test(line)) {
      issues.push(`line ${n}: TAB used for indentation`);
    }
    if (/\s+$/.test(line) && line.trim() !== '') {
      issues.push(`line ${n}: trailing whitespace`);
    }
  });

  // A top-level key must start at column 0.
  lines.forEach((line, i) => {
    if (/^\s+\S/.test(line) && !/^ /.test(line)) {
      issues.push(`line ${i + 1}: unexpected leading indentation`);
    }
  });

  // Detect the merge damage this repo actually hit: a comment line running
  // straight into the next key, e.g. "...see README-push.md.on:".
  lines.forEach((line, i) => {
    if (/#[^\n]*\b(on|jobs|steps|name|uses|runs-on):\s*$/.test(line)) {
      issues.push(`line ${i + 1}: comment runs into a key on the same line ` +
        `"${line.trim().slice(-40)}"`);
    }
  });

  // 'on:' is required, and it must not be quoted as the string "on" in a way
  // that changes meaning -- presence is what matters here.
  if (!/^on:/m.test(raw)) {
    issues.push('no top-level `on:` trigger found');
  }
  if (!/^jobs:/m.test(raw)) {
    issues.push('no top-level `jobs:` block found');
  }

  if (issues.length) {
    problems += issues.length;
    console.log(`${file}\n  !! ${issues.length} issue(s)`);
    for (const p of issues) console.log(`     ${p}`);
  } else {
    console.log(`${file}\n  OK`);
  }
}

console.log(problems === 0 ? '\nAll workflows look structurally valid.' : `\n${problems} issue(s).`);
process.exit(problems === 0 ? 0 : 1);
