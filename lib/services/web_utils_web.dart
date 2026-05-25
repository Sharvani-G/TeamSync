import 'dart:html' as html;

String getLocationFragment() {
  final hash = html.window.location.hash ?? '';
  if (hash.startsWith('#')) return hash.substring(1);
  return hash;
}

void clearOAuthCallbackState() {
  try {
    // Clear URL fragment
    final path = html.window.location.pathname ?? '';
    final search = html.window.location.search ?? '';
    html.window.history.replaceState(null, '', path + search);

    // Remove known redirect/auth keys from storage
    final keysToRemove = <String>[];
    for (var i = 0; i < html.window.localStorage.length; i++) {
      final key = html.window.localStorage.keys.elementAt(i);
      if (key.startsWith('firebase:') || key.contains('redirect') || key.contains('oauth') || key.contains('auth')) {
        keysToRemove.add(key);
      }
    }
    for (final k in keysToRemove) {
      html.window.localStorage.remove(k);
    }
    // Also try sessionStorage
    final sessKeys = <String>[];
    for (var i = 0; i < html.window.sessionStorage.length; i++) {
      final key = html.window.sessionStorage.keys.elementAt(i);
      if (key.startsWith('firebase:') || key.contains('redirect') || key.contains('oauth') || key.contains('auth')) {
        sessKeys.add(key);
      }
    }
    for (final k in sessKeys) {
      html.window.sessionStorage.remove(k);
    }
  } catch (e) {
    // ignore
  }
}
