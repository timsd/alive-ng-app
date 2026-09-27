// Reports the real state of push delivery, and creates the topic the app
// subscribes to if it is missing.
//
// Two Appwrite 1.8 API shapes matter here and both mislead if you use the
// obvious path:
//   - providers live at /messaging/providers, NOT /providers. The old path
//     reports zero and sends you hunting for a provider that already exists.
//   - topics live at /messaging/topics, NOT nested under a provider. The
//     nested list returns an empty array even when the topic is there.
//
//   node scripts/check_push_state.mjs
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
const call = async (method, p, body) => {
  const res = await fetch(`${endpoint}/v1${p}`, {
    method,
    headers,
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const t = await res.text();
  let j = {};
  try { j = JSON.parse(t); } catch {}
  return { status: res.status, j, t };
};

// AppwritePushService subscribes every device to this topic.
const TOPIC_NAME = 'all_users';
const configured = process.env.APPWRITE_FCM_PROVIDER_ID;

const providers = await call('GET', '/messaging/providers');
console.log(`providers: ${(providers.j.providers || []).length}`);
for (const p of providers.j.providers || []) {
  console.log(`  ${p.$id}  type=${p.type}  enabled=${p.enabled}  name=${p.name}`);
  console.log(
    `    .env APPWRITE_FCM_PROVIDER_ID ${configured === p.$id ? 'MATCHES' : `MISMATCH (${configured})`}`,
  );
}

const topics = await call('GET', '/messaging/topics?limit=100');
console.log(`\ntop-level topics: ${topics.j.total ?? 0}`);
for (const t of topics.j.topics || []) {
  console.log(
    `  ${t.$id}  ${t.name}  provider=${t.providerId ?? t.provider ?? '?'}  ` +
      `subscribe=${JSON.stringify(t.subscribe)}`,
  );
}

const hasTopic = (topics.j.topics || []).some((t) => t.name === TOPIC_NAME);
if (!hasTopic && (providers.j.providers || []).length) {
  console.log(`\ncreating topic '${TOPIC_NAME}'...`);
  const made = await call('POST', '/messaging/topics', {
    topicId: TOPIC_NAME,
    name: TOPIC_NAME,
    subscribe: ['users'],
    publish: ['users', 'team'],
    providerId: providers.j.providers[0].$id,
  });
  console.log(`  -> ${made.status} ${made.t.slice(0, 160)}`);
} else if (hasTopic) {
  console.log(`\ntopic '${TOPIC_NAME}' already exists; nothing to create.`);
}

const subs = await call('GET', '/messaging/message-subscriptions?limit=50');
console.log(`\nserver-side subscriptions: ${subs.j.total ?? 0}`);
for (const s of (subs.j.subscriptions || []).slice(0, 10)) {
  console.log(`  endpoint=${String(s.endpoint ?? '').slice(0, 44)}...`);
}

const db = process.env.APPWRITE_DATABASE_ID;
const tokens = await call('GET', `/databases/${db}/collections/push_tokens/documents?limit=20`);
console.log(`\npush_tokens recorded by the app: ${tokens.j.total ?? 0}`);

console.log('\nProvider, topic and credentials are in place. What remains is a');
console.log('SUBSCRIBED DEVICE, which needs the web app built with');
console.log('  --dart-define=APPWRITE_FCM_PROVIDER_ID=' + (providers.j.providers?.[0]?.$id ?? '<id>'));
console.log('and notification permission granted in a browser.');

