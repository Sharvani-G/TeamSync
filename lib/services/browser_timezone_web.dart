// Provide a safe browser timezone detector for web builds.
// Avoid importing dart:js_util here so analysis doesn't fail in non-web contexts.
String detectBrowserTimeZone() {
  // Prefer the platform's timezone; advanced JS Intl detection is optional
  // and may be provided in a dedicated web-only implementation. This
  // safe fallback avoids analyzer errors when dart:js_util isn't available.
  return DateTime.now().timeZoneName;
}