import 'dart:html' as html;

void appendBootLog(String message) {
  try {
    final key = 'teamsync.bootLogs';
    final existing = html.window.localStorage[key];
    final list = <String>[];
    if (existing != null && existing.isNotEmpty) {
      try {
        // store as newline-separated for simplicity
        list.addAll(existing.split('\n'));
      } catch (_) {}
    }
    list.add('${DateTime.now().toIso8601String()} $message');
    html.window.localStorage[key] = list.join('\n');
    // also append to document.title for quick retrieval via Playwright
    try {
      final currentTitle = html.document.title ?? '';
      html.document.title = '${DateTime.now().toIso8601String()} $message | $currentTitle';
    } catch (_) {}
  } catch (_) {}
}
