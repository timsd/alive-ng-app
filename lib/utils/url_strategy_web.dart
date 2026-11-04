import 'package:flutter_web_plugins/url_strategy.dart';

/// Activates path-based URL strategy on Flutter Web.
/// This removes the `/#/` hash from URLs, enabling clean paths like
/// `/reset-password` instead of `/#/reset-password`.
void configureUrlStrategy() {
  usePathUrlStrategy();
}

