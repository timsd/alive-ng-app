# ALIVE-NG: HTML and Flutter Execution Checklist

Status: planned; implementation and production verification remain outstanding.
Source: user brief attached September 6, 2026, and existing implementation_plan.md.
This is the active checklist for this request. Prior documents' Complete labels are historical claims, not current test evidence.

## Execution Rules

- Work in phase order. Finish a bounded batch, verify it, record evidence, then continue.
- Use [ ] pending, [x] verified complete. Add BLOCKED with the precise dependency where necessary; never mark blocked work complete.

- Fix shared theme, layout, localization and error helpers before repeating edits across screens. Avoid blind global replacements.
- One investigation per issue: record root cause, affected paths, fix, test and remaining limitation here.
- Delegate only independent bounded work: HTML donations; Flutter navigation/theme; game/Bible. Assign separate files to avoid overlapping edits. Integrate and verify centrally.
- Run focused checks per batch, then full analysis/builds at integration. Avoid repeated full builds and broad scans without new evidence.
- Keep credentials out of source, logs, screenshots and client build arguments. Inspect environment names and presence, not secret values.
- Do not charge real payment methods during automated tests. Preserve production data, signing identity and working downloads.
- Additional improvements must have a concrete defect or accessibility/functionality justification. Record them in the discovered-issues list; avoid unbounded redesign.

## 0. Establish the Baseline and Recover Pending Work

- [ ] Inspect git status, branch, current deployment commit and existing changes before modifying files.
- [ ] Reconcile implementation_plan.md, migration-readiness docs, available previous task sheets and actual code. Record interrupted, omitted and unverified tasks; do not assume access to unavailable conversation history.
- [ ] Inventory HTML entry points, Flutter routes, role-restricted routes, providers, function IDs, tables and storage dependencies once.
- [ ] Record toolchain versions, current analyzer/test failures and release artifact paths. Check any still-running provisioning or analysis before restarting jobs.

- [ ] Review Node pinning and Appwrite function runtime separately; choose supported compatible versions using current official documentation and test provisioning before changing runtimes.
- [ ] Carry forward outstanding typed-provider integration, oversized-widget extraction and font replacements only where still incomplete.

Acceptance: a finite route/issue inventory and baseline results exist; unrelated user changes are identified.

## 1. Authentication, Account Access and Backend Errors

Primary areas: lib/screens/auth, onboarding, profile; auth/error services; Appwrite functions/configuration.

- [ ] Reproduce Google login on HTML-to-Flutter web and signed Android. Verify actual OAuth client type/ID, Appwrite provider settings and the exact HTTPS callback emitted by the live server; eliminate obsolete HTTP/port redirects.
- [ ] Test password reset request, email delivery, HTTPS redirect and successful password replacement. Show neutral request acknowledgement without claiming delivery; never show a success state after a failed request.
- [ ] Diagnose accounts created directly in Appwrite: password/provider setup, enabled status, profile-row creation and role mapping. Make first sign-in initialize required profile state safely.
- [ ] Remove general account-approval gating and obsolete account-pending notices. Keep chapter/organization membership approval and intended chat/meeting authorization; do not make private rooms public.
- [ ] Verify an authorized chapter manager can approve membership and that the member sees the updated state without stale notices.
- [ ] Offer biometric setup only after successful authentication, on supported hardware with enrollment. Handle cancellation, unavailable hardware and failed setup in plain language; preserve secure session behavior.
- [ ] Centralize user-facing error messages for notifications, dialogs, forms and snackbars; retain useful technical diagnostics privately. Include network, permissions, expired session and retry states.
- [ ] Recheck remaining Appwrite catalog/schema capacity blockers, function permissions and private-room enforcement. Provision only confirmed missing requirements and verify read/write access with appropriate roles.

Acceptance: guest, new user, returning user, direct-created user, content manager and administrator follow their intended paths; reset and OAuth succeed on real supported devices/environments.

## 2. Donations Across HTML and Flutter

Primary areas: web/index.html, web/donation.html, lib/screens/donation, donation/payment services and payment functions.

- [ ] Selecting a project takes the HTML guest to its HTML donation flow and scrolls/focuses the donor-details section below any fixed header.
- [ ] Fix NGN/USD amount validation: currency-specific minimum, decimals, browser step/min constraints and server minor-unit conversion agree. Test blank, zero, negative, malformed, valid and boundary amounts.
- [ ] Diagnose invalid-key errors from actual frontend public-key configuration, function secrets, test/live environment and payment responses. Never ship Paystack secret keys to clients.
- [ ] Fix Flutter Donate: guests enter name/email in a modal; signed-in users use their profile details; both continue to the configured payment flow.
- [ ] Restore non-monetary donation directly to its intended form, including guest access where designed.
- [ ] Make selected projects, allocation ratios and Reset a sticky summary that remains visible while scrolling, without covering fields, mobile keyboards or the payment action.
- [ ] Verify allocation totals, rounding, currency switches and reset state. Preserve project funding totals and existing fund-update text/images.
- [ ] Correct clipped project modals, button alignment and unreachable Donate controls on small screens.
- [ ] Verify cancellation, retry, callback and signed webhook handling. Award donations/download access only after server-verified payment; prevent duplicate processing.

Acceptance: HTML and Flutter guest/member payment journeys pass with test transactions; real payments require an explicit controlled live check.

## 3. Shared Visual System and Navigation

Primary areas: lib/utils/app_theme.dart, shared widgets, navigation/profile/kids/lessons screens and all HTML styles.

- [ ] Extract a verified typography, spacing, icon and theme reference from the old project; reuse current theme APIs and one compatible icon family.
- [ ] Replace the language globe with the translation/language symbol. Use a game icon for Instant Word and a bell for profile notifications; reserve the gear for Settings.
- [ ] Rebuild More as an opaque, theme-aware tray with four icon-and-label items per row, without individual surrounding boxes. Preserve readable wrapping and accessible touch targets.
- [ ] Keep More and project trays beneath the Flutter header, within screen width and safe areas; remove unwanted glass overlay and decorative dash/handle.
- [ ] Move Help & Support, About App, About ALIVE and Sign Out from Profile to More without duplicate routes.
- [ ] Make Kids Mission icons visible in both themes, remove icon subtitles, match quick-action sizing and open the selected option directly instead of an extra modal.
- [ ] Compare Android and Flutter-web Home quick actions and intentionally align navigation. Preserve access through More; treat missing features caused by stale APKs separately from design decisions.
- [ ] Fix overflowing dropdown labels across routes with constrained widths and appropriate wrapping/expanded controls, including larger accessibility text.
- [ ] Fix Interactive Lessons tabs, including All Lessons and In Progress: selected, unselected and disabled text must remain visible in light and dark modes.
- [ ] Audit remaining headings, body text, icons, buttons, labels, dialogs and error states in both themes. Use semantic theme styles; preserve meaningful imagery and status colors.
- [ ] Align HTML buttons, spacing and typography with the same visual system, including donation, privacy and terms pages.

Acceptance: no clipped controls or unreadable text at narrow phone, tablet and desktop widths, both themes and enlarged text. Four-column More remains usable at the smallest supported width.

## 4. Splash, Startup and Release Freshness

- [ ] Match HTML splash logo/animation scale to Flutter, then modestly enlarge both and center them within safe viewport bounds. Respect reduced-motion settings.
- [ ] Fix HTML startup landing at the footer: inspect autofocus, scroll restoration, anchors and initialization order. Start at Home while preserving deliberate deep links.
- [ ] Measure startup stages before optimizing; defer nonessential work and avoid duplicate initialization. Show measured progress only where available, otherwise honest stage labels.
- [ ] Identify why Android lacks current Flutter features: compare commit, build inputs, configuration, artifact timestamp and installed version before clearing caches.
- [ ] Remove obsolete artifact fallback from release selection; build from the verified checkout. Purge only confirmed disposable outputs within checked paths.
- [ ] Publish the APK as ALIVE-NG-App.apk, with correct Android-package content type and download filename; remove .zip suffix at its source. Verify the downloaded bytes are the signed APK.
- [ ] Upload a new version safely before replacing its download reference. Retain the previous working release until the new download and install pass.

Acceptance: current web/APK identify the same release source, start on the correct screen and offer a working correctly named download.

## 5. Bible Reader, Books and Content Access

- [ ] Reproduce empty Bible books on the installed release APK; inspect bundled content, import/index readiness, SQLite/platform setup and network/offline behavior.
- [ ] Verify translation -> book -> chapter -> verse navigation with correct text, readable themes, copy, highlight/color and share actions.
- [ ] Open a tract PDF inside the app from the PDF action. Keep reading and download actions distinct.
- [ ] Route tract downloads through the existing minimum tract-production donation, then unlock after verified payment and save into the Downloads area. Prevent duplicate charges for an already entitled download.
- [ ] Normalize generated share links to https://app.alivenigeria.org without the incorrect www prefix; verify deep-link destinations.
- [ ] Open User Guide content directly when selected, without an intermediate View Guide popup.
- [ ] Recheck pending podcast upload/listening and tract rich-text extraction issues from recovered task records, if still present.

Acceptance: release APK reads actual Bible content and documents online/offline as supported; payment-gated downloads and share links work end to end.

## 6. Bible Game State and Scoring

Primary areas: lib/screens/bible/bible_game_screen.dart and existing game, speech and achievement services.

- [ ] Define one typed round state: mode, translation, verse, attempts, reveal/hint use, score, lifecycle state and completion. Reuse current domain logic where sound.
- [ ] Voice front: recitation instruction and nonclickable reference, active microphone, no speaker. Recognition uses the chosen verse/translation and supported speech locale.
- [ ] Voice reveal: confirm a 2-point deduction before flipping. Back shows reference, full correct verse and audio action. Returning to the front permits recitation and does not silently charge again.
- [ ] Voice hint unlocks after three failed attempts and costs 1 point with a clear warning. Test cancellation, microphone permission, interrupted recognition and duplicate submits.
- [ ] Fill Gaps: one expanding input per missing word; prevent multiple words being entered as one answer. Rename Check Answer to Submit.
- [ ] Wrong Fill Gaps submissions clear entered answers and allow three attempts. Hint then becomes available, confirms its exact cost, reveals the answer and advances as specified.
- [ ] Resolve the brief's conflicting Fill Gaps hint costs before implementing: it says warning of 2 points but deduction of 1. Proposed consistent rule is 1 point, matching the explicit deduction; confirmation and debit must agree.
- [ ] Confirm or preserve a usable starting-score/earning rule. Exhausted spendable points end the game and offer restart; first-time players must not start in an immediate game-over state.
- [ ] On genuine app backgrounding, rotate to a different verse on return and reset round attempts/inputs. Distinguish permission dialogs and audio interruptions so they do not unfairly rotate a round.
- [ ] Add milestones such as reaching 200 points without reveal/hint. Define whether the streak is per session and avoid awarding twice.
- [ ] Verify translation availability, answer normalization, apostrophes/punctuation, retry limits, hint confirmation, lifecycle transitions and scoring with focused tests.

Acceptance: each mode follows a documented deterministic state machine; displayed costs equal charged costs, and a round cannot be scored twice.

## 7. Achievements and Localization

- [ ] Present achievements as an accessible badge/trophy collection with earned/locked states, progress and a shareable achievement detail, using the shared visual system.
- [ ] Evaluate the proposed redeemable achievement balance separately from historical achievement scores. Recommended first release: retain permanent achievements and keep game deductions in the game score.
- [ ] If reward redemption is selected, implement one-time claims, server-authoritative balance, transaction history and atomic deductions. Do not silently spend previously earned achievements or create repeatable free claims.
- [ ] Inventory all supported locales and move remaining interface wording into existing localization resources, including dialogs, validation, game prompts, notifications and accessibility labels.
- [ ] Verify each supported language across every route, persistence after restart and date/number formatting. Flag missing translations rather than claiming complete translation from a fallback.
- [ ] Map daily verses to available approved Bible translations for the selected language, including Yoruba. Verify content availability/licensing; show an explicit fallback when a translation is unavailable.
- [ ] Distinguish interface translation from user-authored/backend content. Support localized published content where available; do not silently machine-translate names, payment references or uploaded documents.

Acceptance: no unintended English interface strings remain in a completed locale; Bible content uses the intended available translation. Any content/translation gaps are listed explicitly.

## 8. Contact and Information Screens

- [ ] Contact: one row of clickable email, phone and website icons; email app@alivenigeria.org; existing verified phone/site destinations; remove address. Include accessible labels/tooltips.
- [ ] About App: Send Feedback opens the verified developer contact; remove general ministry contact from this screen. Do not invent the developer address.
- [ ] About ALIVE: clickable contact icons in one row with consistent spacing and readable theme states.
- [ ] Verify relocated More links and Sign Out, including cleared private state and correct return route.

Acceptance: every contact action opens the expected application/destination and keyboard/screen-reader labels remain clear.

## 9. Integration, Deployment and Production Evidence

- [ ] Complete a route matrix covering all discovered screens, not just the reported examples: HTML/Flutter web/Android; guest/member/content manager/admin; light/dark; loading/empty/error/success.
- [ ] Run focused unit/widget/browser tests for changed logic, then full Flutter analysis and project tests. Record pre-existing failures separately.
- [ ] Capture screenshots at representative phone/tablet/desktop sizes and enlarged text; compare reference style, typography, spacing, modal bounds and contrast.
- [ ] Verify real backend permissions, Google login, reset delivery, Bible content, chapter approval, donations, private meetings and uploads. Emulator/browser success alone does not certify device features.
- [ ] Diagnose manual Coolify deployment from the latest actual log and effective build settings. Verify repo branch/root Dockerfile/build arguments and exact source commit; avoid repeated blind redeploys.
- [ ] Confirm no server secrets enter HTML, Flutter defines, build assets, git or release metadata. Keep intentionally retained FCM configuration documented.
- [ ] Build signed release APK/AAB and web from the same verified source. Preserve Android application ID/signing key and increment versionCode for store updates.
- [ ] Push reviewed changes, deploy appropriate Appwrite functions/schema and Coolify web, verify live health and routes, then publish the tested APK download.
- [ ] Validate installation/update on a physical Android device, biometrics/microphone, OAuth callbacks and downloaded-file naming. Record hardware checks needing the user's device instead of marking them passed.
- [ ] Update README and relevant setup docs to current behavior; keep the personal Oracle roadmap out of git.
- [ ] Remove only proven unused files/caches after import/build/reference checks. Keep required migration tools until their work is verified complete.

Acceptance: every checklist item has evidence or a named remaining blocker. Production readiness is based on successful release and live checks, not a guessed percentage.

## Batch Evidence Record

For each completed batch append:

- Task IDs/phase:
- Root cause and changed files:
- Tests and result:
- Commit / deployment / artifact identifier:
- Remaining blocker or next batch:

## Decisions to Resolve During the Relevant Batch

1. Fill Gaps hint: proposed 1-point warning and deduction; source brief also mentions 2.
2. Preserve existing viable game starting score unless review proves it broken; document score earning and exhaustion precisely.
3. Redeemable achievement wallet is a proposed extension, not necessary for the immediate game fixes. Keep permanent achievements intact pending a chosen reward rule.
4. Use existing verified developer contact and phone; request missing values only if the code/config does not supply them.

## Discovered Issues

- Existing implementation_plan.md asserts theme and audit completion without current per-route evidence; revalidate under this checklist.
- Previous APK upload changes may delete a working release before replacement upload succeeds; inspect and make publishing non-destructive before running it.
- Prior provisioning reported optional column capacity skips; these are unresolved until each affected data path is verified or repaired.
- Any additional confirmed defect: record affected route, impact and smallest scoped fix here before expanding work.
