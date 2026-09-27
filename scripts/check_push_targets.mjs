// Reports whether push delivery can actually work yet.
//
// A push notification needs three things to line up, and a green toggle in the
// app proves none of them. This reports each one separately, so "it is not
// working" can be attributed to the right layer:
//
//   1. a configured FCM provider on Appwrite
//   2. at least one device token in push_tokens (a browser or phone has
//      actually registered)
//   3. at least one subscriber to a topic, i.e. something is addressable
//
// With zero tokens, no test push can be delivered no matter how it is sent --
// which is the state this has been in.
//
//   node scripts/check_push_targets.mjs
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
};
const db = process.env.APPWRITE_DATABASE_ID;

const get = async (p) => {
  const r = await fetch(`${endpoint}/v1${p}`, { headers });
  return { status: r.status, j: await r.json().catch(() => ({})) };
};

const cfg = readFileSync('lib/config/appwrite_backend_config.dart', 'utf8');
const pushTokensId = cfg.match(/pushTokensCollectionId\s*=\s*'([^']+)'/)?.[1];

console.log('1. Appwrite FCM provider');
const providers = await get('/messaging/providers');
// The discriminator is `provider` ("fcm"/"apns"), not `type` -- `type` is the
// channel kind ("push"/"email"/"sms"). Filtering on the wrong field reported a
// configured provider as missing.
const fcm = (providers.j.providers || []).filter(
  (p) => p.provider === 'fcm' || p.provider === 'apns',
);
console.log(`   push providers: ${fcm.length}`);
for (const p of fcm) {
  console.log(`   - ${p.$id}  ${p.name}  provider=${p.provider}  enabled=${p.enabled}`);
}
if (!fcm.length) {
  console.log('   -> NO FCM PROVIDER: Appwrite cannot send push at all.');
} else if (!fcm.some((p) => p.enabled)) {
  console.log('   -> FCM PROVIDER DISABLED: sending is switched off.');
} else {
  console.log('   -> ok: an FCM provider exists and is enabled.');
}

console.log('\n2. Device tokens');
let tokens = [];
if (pushTokensId) {
  const t = await get(`/databases/${db}/collections/${pushTokensId}/documents?limit=100`);
  tokens = t.j.documents || [];
  console.log(`   push_tokens rows: ${tokens.length}`);
  for (const row of tokens.slice(0, 10)) {
    console.log(
      `   - ${row.platform ?? '?'}  user=${row.user_id ?? '?'}  ${String(row.token ?? '').slice(0, 24)}...`,
    );
  }
} else {
  console.log('   could not read pushTokensCollectionId from the Dart config');
}
if (!tokens.length) {
  console.log('   -> NO DEVICE TOKENS: no app has registered a push target, so no');
  console.log('      message can be delivered however it is sent. This is expected');
  console.log('      until a signed-in member opens the app on a real device and');
  console.log('      allows notifications.');
}

console.log('\n3. Topic subscribers');
const topics = await get('/messaging/topics?limit=100');
for (const topic of topics.j.topics || []) {
  const subs = await get(`/messaging/topics/${topic.$id}/subscribers?limit=100`);
  const n = subs.j.total ?? 0;
  console.log(`   ${topic.name.padEnd(24)} subscribers=${n}`);
}
const allTopics = topics.j.topics || [];
if (!allTopics.length) {
  console.log('   -> NO TOPICS: nothing is addressable.');
}

console.log('\n4. Firebase web configuration in the build');
const webKeys = [
  'FIREBASE_WEB_API_KEY',
  'FIREBASE_WEB_PROJECT_ID',
  'FIREBASE_WEB_MESSAGING_SENDER_ID',
  'FIREBASE_WEB_APP_ID',
  'FIREBASE_WEB_VAPID_KEY',
];
let webOk = true;
for (const k of webKeys) {
  const present = Boolean(process.env[k]);
  if (!present) webOk = false;
  console.log(`   ${k.padEnd(36)} ${present ? 'set' : 'MISSING'}`);
}
console.log(
  webOk
    ? '   -> web push is configured.'
    : '   -> WEB PUSH NOT CONFIGURED: no Firebase Web app / VAPID key. See web/README-push.md.',
);

const ready = fcm.some((p) => p.enabled) && tokens.length > 0;
console.log(`\n${ready ? 'READY: a test push can be delivered.' : 'NOT READY: a test push cannot be delivered yet.'}`);
process.exit(ready ? 0 : 1);
