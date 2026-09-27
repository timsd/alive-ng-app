// Push notification readiness check.
//
// Reports what the server has and what the app needs, so a "notifications do
// not arrive" report can be attributed to a missing piece rather than guessed
// at. Sending a real notification is not attempted: the only accounts that
// exist are real people, and a test push to a member's handset is not
// something to do without asking.
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

if (existsSync(resolve(process.cwd(), '.env'))) {
  for (const line of readFileSync(resolve(process.cwd(), '.env'), 'utf8').split(/\r?\n/)) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
}
const endpoint = (process.env.APPWRITE_ENDPOINT || '').replace(/\/v1\/?$/, '');
const headers = {
  'X-Appwrite-Project': process.env.APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': process.env.APPWRITE_API_KEY,
  'Content-Type': 'application/json',
};
const db = process.env.APPWRITE_DATABASE_ID;
const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  const t = await r.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  return { status: r.status, j, t };
};

console.log('--- 1. server-side FCM provider ---');
const providers = await get('/providers');
const pcm = (providers.j.providers || []).find(
  (p) => p.type === 'push' || p.type === 'fcm',
);
if (!pcm) {
  console.log('  NONE: no push/FCM provider registered on the server.');
  console.log('  Nothing can be sent until one is added in the Appwrite console.');
} else {
  console.log(`  provider: ${pcm.$id}  type=${pcm.type}  enabled=${pcm.enabled}  name=${pcm.name}`);

  const topics = await get(`/providers/${pcm.$id}/topics`);
  const names = (topics.j.topics || []).map((x) => x.name);
  console.log(`  topics: ${names.length ? names.join(', ') : '(none)'}`);
  for (const t of topics.j.topics || []) {
    const subs = await get(
      `/providers/message-subscriptions?queries[]=${encodeURIComponent(JSON.stringify({ method: 'equal', attribute: 'topics', values: [t.$id] }))}`,
    );
    console.log(`    ${t.name}: ${subs.j.total ?? '?'} subscribers`);
  }
}

console.log('\n--- 2. registered device tokens ---');
const tokens = await get(`/databases/${db}/collections/push_tokens/documents?limit=100`);
console.log(`  push_tokens: ${tokens.j.total ?? 0} documents`);
for (const d of (tokens.j.documents || []).slice(0, 10)) {
  console.log(
    `    user=${d.user_id ?? '(none)'}  platform=${d.platform ?? '?'}  token=${String(d.token ?? '').slice(0, 24)}...  created=${d.created_at ?? '?'}`,
  );
}
if (!(tokens.j.total > 0)) {
  console.log('  No device has registered a token, so no push can be delivered');
  console.log('  even if the server side were perfect.');
}

console.log('\n--- 3. build-time provider id in the app ---');
const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const m = cfg.match(/fcmProviderId\s*=\s*String\.fromEnvironment\(([\s\S]*?)\);/);
console.log(`  ${(m ? m[1] : '(not found)').replace(/\s+/g, ' ')}`);
console.log('  An empty default means the app was built without the provider id,');
console.log('  so the client cannot subscribe to a topic even if one exists.');

console.log('\n--- 4. client subscribe call ---');
const users = await get('/users?limit=100');
console.log(`  accounts that could receive a push: ${users.j.total ?? users.users?.length ?? 0}`);
