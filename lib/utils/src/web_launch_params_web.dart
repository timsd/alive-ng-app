import 'package:web/web.dart' as web;

String? getSelectedProjectId() {
  try {
    return web.window.sessionStorage.getItem('selected_project_id');
  } catch (_) {
    return null;
  }
}

void clearSelectedProjectId() {
  try {
    web.window.sessionStorage.removeItem('selected_project_id');
  } catch (_) {
    // ignore
  }
}

void setSelectedProjectId(String projectId) {
  try {
    web.window.sessionStorage.setItem('selected_project_id', projectId);
  } catch (_) {
    // ignore
  }
}

String? getInitialRoute() {
  try {
    return web.window.sessionStorage.getItem('start_route');
  } catch (_) {
    return null;
  }
}

void clearInitialRoute() {
  try {
    web.window.sessionStorage.removeItem('start_route');
  } catch (_) {}
}

String? _inMemoryPostAuthRedirect;

String? getPostAuthRedirect() {
  try {
    return web.window.sessionStorage.getItem('post_auth_redirect') ?? _inMemoryPostAuthRedirect;
  } catch (_) {
    return _inMemoryPostAuthRedirect;
  }
}

void setPostAuthRedirect(String route) {
  _inMemoryPostAuthRedirect = route;
  try {
    web.window.sessionStorage.setItem('post_auth_redirect', route);
  } catch (_) {}
}

void clearPostAuthRedirect() {
  _inMemoryPostAuthRedirect = null;
  try {
    web.window.sessionStorage.removeItem('post_auth_redirect');
  } catch (_) {}
}

String consumePostAuthRedirectOrHome([String defaultRoute = '/home']) {
  final pending = getPostAuthRedirect();
  if (pending != null &&
      pending.trim().isNotEmpty &&
      pending.trim() != '/' &&
      pending.trim() != '/auth' &&
      pending.trim() != '/onboarding') {
    clearPostAuthRedirect();
    clearInitialRoute();
    return pending.trim();
  }
  final initial = getInitialRoute();
  if (initial != null &&
      initial.trim().isNotEmpty &&
      initial.trim() != '/' &&
      initial.trim() != '/auth' &&
      initial.trim() != '/onboarding') {
    clearInitialRoute();
    return initial.trim();
  }
  return defaultRoute;
}

/// Clears Appwrite's `cookieFallback` key from localStorage.
///
/// The Appwrite web SDK persists the session cookie there
/// (`client_browser.dart`); a stale value re-sends an "active session"
/// signature and causes `appwrite_user_session_already_exists` on login.
void clearAppwriteCookieFallback() {
  try {
    web.window.localStorage.removeItem('cookieFallback');
  } catch (_) {
    // ignore
  }
}
