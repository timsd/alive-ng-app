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

/// Clears Appwrite's `cookieFallback` key from localStorage.
/// No-op on non-web platforms.
void clearAppwriteCookieFallback() {
  // no-op on non-web
}
