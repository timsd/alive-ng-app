/**
 * Updates the Coolify build-time variable that carries every `--dart-define`
 * for the ALIVE Flutter Web service.
 *
 * The Dockerfile builds with `flutter build web ... ${FLUTTER_BUILD_ARGS}`, so
 * this single variable is what injects the app's compile-time configuration.
 * Anything omitted from it silently falls back to the `String.fromEnvironment`
 * default in Dart.
 *
 * This exists because APPWRITE_FCM_PROVIDER_ID was missing from the Coolify
 * value, so `AppwriteBackendConfig.fcmProviderId` resolved to '' in the shipped
 * app and AppwritePushService skipped registering a push target. Note that this
 * Coolify version rejects `build_variables` on a PATCH ("This field is not
 * allowed"), so the variable is edited through the `envs` collection instead.
 *
 * Scoped to the single service UUID in .env, so the monpa and LiveKit services
 * on the same Coolify are never touched.
 *
 *   node scripts/set_coolify_build_args.mjs
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

function loadDotEnv(filePath = resolve(process.cwd(), '.env')) {
  if (!existsSync(filePath)) return;
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const [rawKey, ...valueParts] = line.split('=');
    const key = rawKey.trim();
    if (!key || process.env[key] !== undefined) continue;
    process.env[key] = valueParts.join('=').trim().replace(/^['"]|['"]$/g, '');
  }
}
loadDotEnv();

const base = (process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
const headers = {
  Authorization: `Bearer ${process.env.COOLIFY_API_TOKEN}`,
  'Content-Type': 'application/json',
  Accept: 'application/json',
};
const uuid = process.env.COOLIFY_SERVICE_UUID;
const appUrl = `${base}/api/v1/applications/${uuid}`;

// Refuse to touch anything that is not the ALIVE app.
const app = await (await fetch(appUrl, { headers })).json();
if (!app?.name?.includes('ALIVE')) {
  throw new Error(
    `Refusing to modify "${app?.name ?? uuid}": not the ALIVE application.`,
  );
}
console.log(`Target: ${app.name} (${app.git_repository} @ ${app.git_branch})`);

const desired = (process.env.FLUTTER_BUILD_ARGS || '').trim();
if (!desired) throw new Error('FLUTTER_BUILD_ARGS is empty in .env');

const definesIn = (s) =>
  new Set((s.match(/--dart-define=([A-Z0-9_]+)=/g) || []).map((d) => d.split('=')[1]));

const envs = await (await fetch(`${appUrl}/envs`, { headers })).json();
const current = (envs ?? []).find((v) => v.key === 'FLUTTER_BUILD_ARGS');

if (!current) {
  console.log('FLUTTER_BUILD_ARGS not present in Coolify; creating it.');
  const res = await fetch(`${appUrl}/envs`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      key: 'FLUTTER_BUILD_ARGS',
      value: desired,
      is_build_time: true,
      is_runtime: true,
      is_preview: false,
    }),
  });
  console.log(`create status: ${res.status} ${(await res.text()).slice(0, 200)}`);
} else {
  // Merge rather than overwrite: Coolify holds defines the local .env does not
  // (the Firebase web config, recaptcha, web-push key). Replacing the value
  // outright would strip those and break the deployed app.
  const have = definesIn(current.value ?? '');
  const want = definesIn(desired);
  const missing = [...want].filter((k) => !have.has(k));
  const extra = [...have].filter((k) => !want.has(k));

  console.log(`\ncurrent value: ${(current.value ?? '').length} chars`);
  if (missing.length) console.log(`missing in Coolify: ${missing.join(', ')}`);
  if (extra.length) {
    console.log(`ONLY in Coolify (must keep): ${extra.join(', ')}`);
  }

  if (missing.length) {
    const merged = `${(current.value ?? '').trim()} ${desired}`;
    console.log('\nAppending the missing defines (keeping the existing ones)...');

    // Try the per-env route first, then the whole-collection PUT, because
    // supported routes differ between Coolify versions.
    for (const [label, method, url, body] of [
      [
        'PATCH envs/{uuid}',
        'PATCH',
        `${appUrl}/envs/${current.uuid}`,
        { value: merged },
      ],
      [
        'PUT envs/{uuid}',
        'PUT',
        `${appUrl}/envs/${current.uuid}`,
        {
          key: 'FLUTTER_BUILD_ARGS',
          value: merged,
          is_build_time: true,
          is_runtime: true,
          is_preview: false,
        },
      ],
      [
        'PUT envs (collection)',
        'PUT',
        `${appUrl}/envs`,
        [
          {
            uuid: current.uuid,
            key: 'FLUTTER_BUILD_ARGS',
            value: merged,
            is_build_time: true,
            is_runtime: true,
            is_preview: false,
          },
        ],
      ],
    ]) {
      const res = await fetch(url, {
        method,
        headers,
        body: JSON.stringify(body),
      });
      const text = await res.text();
      console.log(`  [${label}] -> ${res.status} ${text.slice(0, 120)}`);
      if (res.ok) break;
    }
  } else {
    console.log('\nCoolify already has every define; nothing to change.');
  }
}

const after = await (await fetch(`${appUrl}/envs`, { headers })).json();
const now = (after ?? []).find((v) => v.key === 'FLUTTER_BUILD_ARGS');
const stillMissing = [...definesIn(desired)].filter(
  (k) => !definesIn(now?.value ?? '').has(k),
);
console.log(
  `\nresult: ${stillMissing.length ? 'STILL MISSING ' + stillMissing.join(', ') : 'all defines present'}`,
);
