// Registers bindOfficeOnSignup in appwrite.config.json so the proven
// deployer (which uses the https module, not fetch) can ship it.
//
//   node scripts/register_bind_office_function.mjs
import { readFileSync, writeFileSync } from 'node:fs';

const path = 'appwrite.config.json';
const config = JSON.parse(readFileSync(path, 'utf8'));
const ID = 'bind_office_on_signup';

if (config.functions.some((f) => f.$id === ID)) {
  console.log('already present in appwrite.config.json');
} else {
  config.functions.push({
    $id: ID,
    name: 'bindOfficeOnSignup',
    path: 'appwrite_functions/bindOfficeOnSignup',
    entrypoint: 'src/main.js',
    commands: 'npm install',
    events: ['users.*.create'],
    execute: ['users'],
    runtime: 'node-20.0',
    scopes: ['databases.read', 'databases.write', 'users.read'],
  });
  writeFileSync(path, `${JSON.stringify(config, null, 2)}\n`);
  console.log(`added ${ID} to appwrite.config.json`);
}
console.log(config.functions.map((f) => f.$id).join(', '));
