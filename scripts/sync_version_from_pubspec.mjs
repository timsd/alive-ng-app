import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const rootDir = process.cwd();
const pubspecPath = resolve(rootDir, 'pubspec.yaml');

if (!existsSync(pubspecPath)) {
  console.error('❌ pubspec.yaml not found at', pubspecPath);
  process.exit(1);
}

const pubspecContent = readFileSync(pubspecPath, 'utf8');
const versionMatch = pubspecContent.match(/^version:\s*([^\s#]+)/m);

if (!versionMatch) {
  console.error('❌ Could not parse version from pubspec.yaml');
  process.exit(1);
}

const currentVersion = versionMatch[1].trim();
console.log(`📌 Single Source of Truth version from pubspec.yaml: ${currentVersion}`);

// 1. Sync lib/constants/app_constants.dart
const appConstantsPath = resolve(rootDir, 'lib/constants/app_constants.dart');
if (existsSync(appConstantsPath)) {
  let content = readFileSync(appConstantsPath, 'utf8');
  const updated = content.replace(
    /static const String appVersion = '[^']+';/,
    `static const String appVersion = '${currentVersion}';`
  );
  if (content !== updated) {
    writeFileSync(appConstantsPath, updated, 'utf8');
    console.log(`✅ Synced lib/constants/app_constants.dart -> ${currentVersion}`);
  } else {
    console.log(`✓ lib/constants/app_constants.dart already matches (${currentVersion})`);
  }
}

// 2. Sync web/index.html
const webIndexPath = resolve(rootDir, 'web/index.html');
if (existsSync(webIndexPath)) {
  let content = readFileSync(webIndexPath, 'utf8');
  const updated = content.replace(
    /<meta name="version" content="[^"]*">/,
    `<meta name="version" content="${currentVersion}">`
  );
  if (content !== updated) {
    writeFileSync(webIndexPath, updated, 'utf8');
    console.log(`✅ Synced web/index.html -> ${currentVersion}`);
  } else {
    console.log(`✓ web/index.html already matches (${currentVersion})`);
  }
}

console.log('🎉 Version synchronization complete!');

