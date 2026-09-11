import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Widget fallback must not replace the locale used for application messages.
class AppMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const AppMaterialDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(
          GlobalMaterialLocalizations.delegate.isSupported(locale)
              ? locale
              : const Locale('en'));
  @override
  bool shouldReload(AppMaterialDelegate old) => false;
}

class AppCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AppCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(
          GlobalCupertinoLocalizations.delegate.isSupported(locale)
              ? locale
              : const Locale('en'));
  @override
  bool shouldReload(AppCupertinoDelegate old) => false;
}
