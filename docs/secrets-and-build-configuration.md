# Secrets & Build Configuration Guide

## Principle
No secret is ever committed to the repo or shipped in client (Flutter/HTML) code.
`.env` is both `.gitignore`d and `.dockerignore`d. Server-side secrets live only in
Appwrite function environment variables and Coolify runtime variables.

---

## Two build-time injection paths (do NOT confuse them)

The web build injects configuration through **two distinct mechanisms**. Using the
wrong one is the most common mistake.

### Path A - Dart code (`--dart-define`)
- Feeds Flutter Dart `String.fromEnvironment(...)` values (e.g. `PaymentConfig`,
  `AppwriteBackendConfig`).
- **Coolify:** set the build arg
  `FLUTTER_BUILD_ARGS=--dart-define=PAYSTACK_PUBLIC_KEY=pk_live_... --dart-define=APPWRITE_ENDPOINT=https://api.alivenigeria.org/v1`
- **Dockerfile:** `ARG FLUTTER_BUILD_ARGS` -> `flutter build web ... ${FLUTTER_BUILD_ARGS}`.
- Use ONLY for public / non-sensitive values (public keys, endpoints, project IDs).

### Path B - Web HTML placeholders (`scripts/configure_web.dart`)
- Replaces `{{PLACEHOLDER}}` tokens in `web/index.html` and `web/donation.html`
  at Docker build time.
- `configure_web.dart` reads **process environment variables** (and `.env` when run
  locally). Inside Docker, `.env` is excluded, so values must come from build-time env.
- **Coolify:** add a **Build Time Environment Variable** (Coolify passes these to
  `docker build` as `--build-arg`). The Dockerfile must declare a matching `ARG`.
- Only allowlisted public configuration belongs in HTML placeholders.
- Appwrite API keys and payment secrets must never be substituted into HTML.

> [!IMPORTANT]
> `--dart-define` values do NOT reach HTML files, and HTML `{{...}}` placeholders are
> NOT filled by `--dart-define`. They are separate pipelines.

---

## Public identifiers vs secrets

| Public (safe in client code) | Secret (NEVER in client/repo) |
|---|---|
| Appwrite endpoint, project ID, database ID, collection/bucket/function IDs | Appwrite API key (`standard_...`) |
| Paystack PUBLIC key (`pk_live_...`) | Paystack SECRET key (`sk_live_...`) |
| reCAPTCHA SITE key | Resend API key (`re_...`) |
| — | LiveKit API secret, Coolify API token |

reCAPTCHA **site** keys are public by design (Google documents this); their
security comes from reCAPTCHA / App Check verification, not secrecy.

> [!NOTE]
> Firebase has been removed from the client app. All push notification targets and
> analytics now go through Appwrite Messaging / Appwrite TablesDB, and crash
> reporting is handled by GlitchTip (Sentry-compatible). If a push provider is ever
> configured in Appwrite Console, keep its service-account JSON server-side only.

---

## The web donation page needs NO client key
`paystack_payments` is deployed with `execute: ["any"]`, so guest checkout works with
only the `X-Appwrite-Project` header. No client API-key build argument or header is supported.
The Paystack secret stays server-side inside the function.

If you ever restrict the function to `execute: ["users"]`, guests must use an
**anonymous Appwrite session** (web SDK) - never a hardcoded key.

---

## Security rules
1. Docker build-args can leak via `docker history` / image metadata. Never put a real
   secret in a build-arg. If a build-time secret is unavoidable, use BuildKit
   `RUN --mount=type=secret`.
2. Rotate/revoke any key that was ever committed - git history retains it even after
   removal from the current file.
3. Appwrite function secrets are set via `npm run appwrite:function-vars`
   (`scripts/upsert_appwrite_function_variables.mjs`) or the Coolify/Appwrite console -
   never in client code.
4. Keep `.env` out of git and out of the Docker image (already enforced by
   `.gitignore` and `.dockerignore`).
