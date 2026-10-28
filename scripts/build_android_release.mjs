import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { execSync } from 'node:child_process';

const envPath = resolve(process.cwd(), '.env');
const configJsonPath = resolve(process.cwd(), 'config/production_env.json');

// 1. Load local .env fallback
const envVars = {};
if (existsSync(envPath)) {
  const content = readFileSync(envPath, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const idx = trimmed.indexOf('=');
    if (idx > 0) {
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim().replace(/^['"]|['"]$/g, '');
      envVars[key] = val;
    }
  }
}

// 2. Fetch latest production FLUTTER_BUILD_ARGS from Coolify if credentials exist
async function fetchCoolifyEnvs() {
  const base = (envVars.COOLIFY_API_URL || process.env.COOLIFY_API_URL || '').replace(/\/+$/, '');
  const token = envVars.COOLIFY_API_TOKEN || process.env.COOLIFY_API_TOKEN;
  const uuid = envVars.COOLIFY_SERVICE_UUID || process.env.COOLIFY_SERVICE_UUID;

  if (!base || !token || !uuid) {
    console.log('ℹ️ Coolify API credentials not fully set; using local .env and config/production_env.json definitions.');
    return null;
  }

  try {
    console.log(`🌐 Querying Coolify production environment for app ${uuid}...`);
    const res = await fetch(`${base}/api/v1/applications/${uuid}/envs`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
    });
    if (!res.ok) {
      console.warn(`⚠️ Coolify returned status ${res.status}; falling back to local configuration.`);
      return null;
    }
    const data = await res.json();
    const buildArgsEnv = (data || []).find((e) => e.key === 'FLUTTER_BUILD_ARGS');
    if (buildArgsEnv?.value) {
      console.log('✅ Successfully retrieved FLUTTER_BUILD_ARGS from Coolify production!');
      return buildArgsEnv.value;
    }
  } catch (err) {
    console.warn('⚠️ Could not connect to Coolify API:', err.message);
  }
  return null;
}

// 3. Parse and build the JSON dart-define map
async function prepareProductionJson() {
  const coolifyArgs = await fetchCoolifyEnvs();
  const defineMap = {};

  if (coolifyArgs) {
    // Parse `--dart-define=KEY=VAL`
    const regex = /--dart-define=([A-Z0-9_]+)=([^ ]+)/g;
    let match;
    while ((match = regex.exec(coolifyArgs)) !== null) {
      defineMap[match[1]] = match[2];
    }
  }

  // Ensure all critical keys are present with fallbacks
  const defaults = {
    APPWRITE_ENDPOINT: 'https://api.alivenigeria.org/v1',
    APPWRITE_PROJECT_ID: '6a3bef53002f5090dedf',
    APPWRITE_DATABASE_ID: '6a089307002e54291a32',
    APPWRITE_FCM_PROVIDER_ID: '6a0cbd1600215f960c03',
    APPWRITE_RESOURCES_BASE_URL: 'https://app.alivenigeria.org/resources',
    APPWRITE_SUPER_ADMIN_EMAILS: 'alivenigeria2011@gmail.com,dammyolodude@gmail.com,app@alivenigeria.org',
    LIVEKIT_URL: 'wss://livekit.alivenigeria.org',
    PAYSTACK_PUBLIC_KEY: 'pk_live_4d497ec0f12f944e22598c8daa40ce716e8971cf',
    PAYSTACK_WEBHOOK_URL: 'https://api.alivenigeria.org/webhooks/paystack',
    PAYSTACK_CALLBACK_URL: 'https://app.alivenigeria.org/payment/callback',
    RECAPTCHA_SITE_KEY: '6LcKstkrAAAAAMWfR5Ki5eBh1TdCLQD-e7ofMi4S',
    GLITCHTIP_DSN: 'https://73d0ec10487c4a92b5ea6d5f2e97da8d@glitchtip.alivenigeria.org/1',
    GLITCHTIP_ENVIRONMENT: 'production',
    GLITCHTIP_RELEASE: 'alive-ng-app@2.0.4+11',
    GLITCHTIP_TRACES_SAMPLE_RATE: '0',
    FIREBASE_WEB_API_KEY: 'AIzaSyDmpl9Idp9Q0ult4BfWPg5J7A1URQOpDoU',
    FIREBASE_WEB_APP_ID: '1:234909240985:web:9d703098e9fcce3e8e3208',
    FIREBASE_WEB_PROJECT_ID: 'alive-ng-flutter-app',
    FIREBASE_WEB_AUTH_DOMAIN: 'alive-ng-flutter-app.firebaseapp.com',
    FIREBASE_WEB_STORAGE_BUCKET: 'alive-ng-flutter-app.firebasestorage.app',
    FIREBASE_WEB_MESSAGING_SENDER_ID: '234909240985',
    FIREBASE_WEB_MEASUREMENT_ID: 'G-CC6JE7224Q',
    GOOGLE_WEB_CLIENT_ID: '234909240985-1dernhsf9qmkau7idp4hn1nudegpd5ju.apps.googleusercontent.com',
    GOOGLE_ANDROID_CLIENT_ID: '234909240985-8fvqsqs734jgtnqf38d7e6uesp4rbn78.apps.googleusercontent.com',
    GOOGLE_IOS_CLIENT_ID: '234909240985-jr2767d4lmp9plt62fk6j3colff51gue.apps.googleusercontent.com',
    WEB_PUSH_CERT_KEY: 'BMFvrKu5q_mKn80IaIsX3hREab1nodMrdKDlMGOL_lVCIuTwxq4mTZiFG1SYUcCy6G-TrjK9X4H08Jll1PQjkYg',
  };

  for (const [k, v] of Object.entries(defaults)) {
    if (!defineMap[k]) {
      defineMap[k] = envVars[k] || v;
    }
  }

  writeFileSync(configJsonPath, JSON.stringify(defineMap, null, 2), 'utf8');
  console.log(`✅ Production environment definition written to: ${configJsonPath}`);
  return configJsonPath;
}

// 4. Run build
async function run() {
  const target = (process.argv[2] || 'all').toLowerCase();
  await prepareProductionJson();

  if (target === 'prepare' || target === 'sync') {
    console.log('✅ Configuration synced. Ready for Flutter build.');
    return;
  }

  console.log(`\n🚀 Starting Android build with Coolify production environment (${target.toUpperCase()})...`);

  if (target === 'apk' || target === 'all') {
    console.log('\n📦 Building Release APK with --dart-define-from-file=config/production_env.json...');
    execSync('flutter build apk --release --dart-define-from-file=config/production_env.json', {
      stdio: 'inherit',
    });
    console.log('✅ APK build completed successfully!');
  }

  if (target === 'aab' || target === 'all') {
    console.log('\n📦 Building Release App Bundle (AAB) with --dart-define-from-file=config/production_env.json...');
    execSync('flutter build appbundle --release --dart-define-from-file=config/production_env.json', {
      stdio: 'inherit',
    });
    console.log('✅ AAB build completed successfully!');
  }

  console.log('\n🎉 Android build finished with full Coolify production environment included!\n');
}

run().catch((err) => {
  console.error('❌ Build failed:', err);
  process.exit(1);
});
