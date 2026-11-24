import 'package:web/web.dart' as web;

/// Directly navigates the current browser tab to [url] (never blocked by
/// post-async popup blockers unlike `window.open`).
bool redirectWebPage(String url) {
  try {
    web.window.location.assign(url);
    return true;
  } catch (_) {
    return false;
  }
}
