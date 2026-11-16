import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Dismisses any open modal bottom sheets or dialogs on the root navigator so
/// deep links and notification navigation never open hidden behind an overlay.
void dismissActivePopups() {
  final nav = rootNavigatorKey.currentState;
  if (nav == null || !nav.mounted) return;
  nav.popUntil((route) => route is! PopupRoute);
}

