# Localization

Flutter interface messages live in lib/l10n/app_en.arb, app_yo.arb,
app_ig.arb and app_ha.arb. Run `flutter gen-l10n` after edits.
Generated source is under lib/l10n/generated; do not edit it manually.

Use `AppLocalizations.of(context)!.home` inside widgets, or watch
`appLocalizationsProvider` from Riverpod. The existing translationProvider
and languageProvider are transitional adapters to generated messages, not
separate translation catalogs. Unknown legacy keys still use the existing
formatted-key fallback; migrate those callers to typed getters.

LocaleNotifier restores the saved language before the first frame and stores
subsequent selections. It also reads the older selected_language preference
when the current language preference is absent. There is no translation asset
download or artificial splash delay.

Application locale resolution no longer forces English. Material and Cupertino
controls fall back separately to English only when the Flutter SDK does not
provide their requested locale. Their wording needs custom delegates if fully
localized system controls are required.

## Checks

- `flutter gen-l10n`: regenerate strongly typed messages.
- `node scripts/check_l10n.mjs`: fail on missing or empty translations.
- `flutter test test/localization_test.dart`: verify all four app locales.
- `node scripts/export_web_localizations.mjs`: export public JSON catalogs to
  web/locales for the standalone HTML pages. Exporting does not automatically
  replace existing HTML text or implement a language selector.

The initial migration preserves existing translations. Missing messages remain
explicit: Yoruba 38, Igbo 59, Hausa 59. English fallback keeps existing behavior,
but the completeness check fails until these messages are translated. Do not
fill gaps with English and call them translated. Generated code does not catch
hardcoded interface text, so screen-by-screen migration remains necessary.

The runtime content translation service in lib/services/translation_service.dart
is separate from interface localization. Bible translation data and published
content are also separate; ARB files do not provide Bible verses.
