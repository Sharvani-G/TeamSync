import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

Future<void> downloadFromUrl({
  required String url,
  required String fileName,
}) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Failed to download file (${response.statusCode})');
  }

  final safeName = _sanitizeFileName(fileName);
  final targetFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$safeName');
  await targetFile.writeAsBytes(response.bodyBytes, flush: true);

  final launched = await launchUrl(
    Uri.file(targetFile.path),
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    throw Exception('Downloaded file could not be opened');
  }
}

String _sanitizeFileName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'download';
  }
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}