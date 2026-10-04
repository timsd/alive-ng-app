import { Client, Functions, Query } from 'node-appwrite';
import fs from 'fs';

const _orig = Client.prototype.prepareRequest;
if (_orig) {
  Client.prototype.prepareRequest = function (...args) {
    const r = _orig.apply(this, args);
    if (r && r.options) {
      delete r.options.dispatcher;
      delete r.options.agent;
    }
    return r;
  };
}

const env = fs.readFileSync('.env', 'utf8');
const get = (k) => (env.match(new RegExp('^' + k + '=(.*)$', 'm')) || [])[1]?.trim();

const client = new Client()
  .setEndpoint(get('APPWRITE_ENDPOINT'))
  .setProject(get('APPWRITE_PROJECT_ID'))
  .setKey(get('APPWRITE_API_KEY'));

const fn = new Functions(client);

async function main() {
  const functionId = process.argv[2] || 'paystack_payments';
  const res = await fn.listExecutions(functionId, [
    Query.orderDesc('$createdAt'),
    Query.limit(5),
  ]);

  console.log(`Recent executions for ${functionId} (total: ${res.total}):`);
  for (const e of res.executions) {
    console.log(`\n=== ID: ${e.$id} | Status: ${e.status} | HTTP: ${e.responseStatusCode} | Created: ${e.$createdAt}`);
    console.log(`Logs: ${e.logs || '(none)'}`);
    console.log(`Errors: ${e.errors || '(none)'}`);
    console.log(`Response: ${e.responseBody || '(empty)'}`);
  }
}

main().catch(console.error);
