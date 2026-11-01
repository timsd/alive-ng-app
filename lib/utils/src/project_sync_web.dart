import 'package:web/web.dart' as web;

void syncProjectsToWeb(String jsonString) {
  try {
    web.window.localStorage.setItem('alive_projects_cache', jsonString);
    web.window.dispatchEvent(web.CustomEvent('alive_projects_updated'));
  } catch (_) {
    // ignore
  }
}

