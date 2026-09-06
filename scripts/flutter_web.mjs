import { existsSync, readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';

const mode = process.argv[2] ?? 'run';
const windowsFlutter = 'C:\\flutter\\bin\\flutter.bat';
const flutter = process.env.FLUTTER_BIN ||
  (process.platform === 'win32' && existsSync(windowsFlutter)
    ? windowsFlutter
    : 'flutter');

const allowedDefines = new Set([
  'APPWRITE_ENDPOINT',
  'APPWRITE_PROJECT_ID',
  'APPWRITE_DATABASE_ID',
  'APPWRITE_FCM_PROVIDER_ID',
  'LIVEKIT_URL',
  'PAYSTACK_PUBLIC_KEY',
  'PAYSTACK_CALLBACK_URL',
  'GOOGLE_WEB_CLIENT_ID',
  'WEB_PUSH_CERT_KEY',
  'GLITCHTIP_DSN',
  'GLITCHTIP_ENVIRONMENT',
  'GLITCHTIP_RELEASE',
  'GLITCHTIP_TRACES_SAMPLE_RATE',
  'APPWRITE_RESOURCES_BASE_URL',
  'ANDROID_APK_URL',
  'PLAY_STORE_URL',
]);

const defines = [];
if (existsSync('.env')) {
  for (const rawLine of readFileSync('.env', 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const equals = line.indexOf('=');
    if (equals < 1) continue;
    const key = line.slice(0, equals).trim();
    if (!allowedDefines.has(key)) continue;
    const value = line.slice(equals + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
    defines.push(`--dart-define=${key}=${value}`);
  }
}

const args = switchBuildArgs(mode, defines);

function switchBuildArgs(requestedMode, dartDefines) {
  switch (requestedMode) {
    case 'build':
    case 'web':
      return ['build', 'web', '--release', '--no-wasm-dry-run', ...dartDefines];
    case 'apk':
      return ['build', 'apk', '--release', ...dartDefines];
    case 'appbundle':
      return ['build', 'appbundle', '--release', ...dartDefines];
    case 'run':
      return ['run', '-d', 'chrome', ...dartDefines];
    default:
      throw new Error(`Unknown Flutter build mode: ${requestedMode}`);
  }
}

const isWindowsBatch = process.platform === 'win32' && /\.bat$/i.test(flutter);
const child = isWindowsBatch
  ? spawn(process.env.ComSpec ?? 'cmd.exe', ['/d', '/s', '/c', 'call', flutter, ...args], {
      stdio: 'inherit',
    })
  : spawn(flutter, args, { stdio: 'inherit', shell: false });
child.on('error', (error) => {
  console.error(`Unable to start Flutter: ${error.message}`);
  process.exitCode = 1;
});
child.on('exit', (code) => {
  process.exitCode = code ?? 1;
});

