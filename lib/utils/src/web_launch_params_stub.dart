String? getSelectedProjectId() {
  return null;
}

void clearSelectedProjectId() {
  // no-op on non-web
}

void setSelectedProjectId(String projectId) {
  // no-op on non-web
}

String? getInitialRoute() {
  return null;
}

void clearInitialRoute() {
  // no-op on non-web
}

String? _stubPostAuthRedirect;

String? getPostAuthRedirect() {
  return _stubPostAuthRedirect;
}

void setPostAuthRedirect(String route) {
  _stubPostAuthRedirect = route;
}

void clearPostAuthRedirect() {
  _stubPostAuthRedirect = null;
}

String consumePostAuthRedirectOrHome([String defaultRoute = '/home']) {
  final pending = getPostAuthRedirect();
  if (pending != null &&
      pending.trim().isNotEmpty &&
      pending.trim() != '/' &&
      pending.trim() != '/auth' &&
      pending.trim() != '/onboarding') {
    clearPostAuthRedirect();
    return pending.trim();
  }
  return defaultRoute;
}

/// Clears Appwrite's `cookieFallback` key from localStorage.
/// No-op on non-web platforms.
void clearAppwriteCookieFallback() {
  // no-op on non-web
}
