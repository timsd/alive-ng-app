#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

for command in node npm flutter; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command is unavailable: %s\n' "$command" >&2
    exit 1
  fi
done

if [[ ! -f .env ]]; then
  printf '.env is required for Appwrite upload credentials and public build values.\n' >&2
  exit 1
fi

printf '=== Building Flutter Web ===\n'
node scripts/flutter_web.mjs build

printf '=== Building release APK ===\n'
node scripts/flutter_web.mjs apk

printf '=== Uploading APK to Appwrite Storage ===\n'
npm run appwrite:upload-android-release

printf '=== Build Complete ===\n'
printf 'Web: %s\n' "$PROJECT_DIR/build/web"
printf 'APK: %s\n' "$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
