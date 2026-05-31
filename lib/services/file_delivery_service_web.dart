import 'dart:html' as html;

import 'package:http/http.dart' as http;

Future<void> downloadFromUrl({
  required String url,
  required String fileName,
}) async {
  await executeSecureDeviceDownload(downloadUrl: url, fileName: fileName);
}

Future<void> executeSecureDeviceDownload({
  required String downloadUrl,
  required String fileName,
}) async {
  final uri = Uri.tryParse(downloadUrl.trim());
  if (uri == null || uri.scheme != 'https') {
    throw Exception('Invalid download URL');
  }

  final response = await http.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to download file (${response.statusCode})');
  }

  final blob = html.Blob(<Object?>[response.bodyBytes]);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..download = fileName.trim().isNotEmpty ? fileName.trim() : 'download'
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(objectUrl);
}