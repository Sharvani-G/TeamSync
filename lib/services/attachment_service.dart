import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import 'file_picker_web_bootstrap_stub.dart'
    if (dart.library.html) 'file_picker_web_bootstrap_web.dart';
import 'project_service.dart';

class AttachmentUploadResult {
  final String downloadURL;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String fileId;

  AttachmentUploadResult({
    required this.downloadURL,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.fileId,
  });
}

class AttachmentService {
  AttachmentService._();

  static final AttachmentService instance = AttachmentService._();

  static const int defaultMaxFileSizeBytes = 10 * 1024 * 1024;
  static const Duration _signedUrlTimeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(minutes: 5);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Uri get _storageGatewayBaseUri => Uri.parse(serverUploadUrl);

  Future<void> diagnoseStorageConnection() async {
    debugPrint('=== STORAGE DIAGNOSTIC START ===');

    final authUser = _auth.currentUser;
    if (authUser == null) {
      debugPrint('TEST 0 FAIL: No authenticated user is available for signed upload validation.');
      return;
    }

    final authToken = await authUser.getIdToken(true) ?? '';
    if (authToken.isEmpty) {
      throw Exception('Unable to obtain Firebase auth token');
    }
    final testBytes = Uint8List.fromList(utf8.encode('test'));

    try {
      final signature = await _requestCloudinarySignature(
        authToken: authToken,
        fileName: 'diagnostic.txt',
        mimeType: 'text/plain',
        fileSize: testBytes.length,
        context: {
          'type': 'chat',
          'projectId': '__diagnostic__',
          'channelId': '__diagnostic__',
        },
      );

      debugPrint('TEST 1: Cloudinary signature endpoint ok at folder=${signature.folder}');

      final uploadResponse = await _sendMultipartUpload(
        uploadUrl: signature.uploadUrl,
        apiKey: signature.apiKey,
        timestamp: signature.timestamp,
        signature: signature.signature,
        folder: signature.folder,
        fileName: 'diagnostic.txt',
        mimeType: 'text/plain',
        fileBytes: testBytes,
      );

      debugPrint('TEST 2 PASS: Cloudinary multipart upload completed with status=${uploadResponse.statusCode}');
    } catch (e) {
      debugPrint('TEST FAIL: Signed URL diagnostic failed: $e');
      return;
    }

    debugPrint('=== STORAGE DIAGNOSTIC END ===');
  }

  Future<List<picker.PlatformFile>> pickFiles({bool allowMultiple = true}) async {
    try {
      ensureFilePickerWebInitialized();
      final result = await picker.FilePicker.pickFiles(
        allowMultiple: allowMultiple,
        withData: true,
        withReadStream: false,
        type: picker.FileType.any,
      );

      if (result == null) {
        debugPrint('Attachment picker canceled by user');
        return [];
      }

      final files = result.files
          .where((file) => file.bytes != null || file.readStream != null)
          .toList();

      if (files.length != result.files.length) {
        debugPrint(
          'Attachment picker skipped ${result.files.length - files.length} unreadable file(s)',
        );
      }

      debugPrint('Attachment picker selected ${files.length} file(s)');
      return files;
    } catch (error, stackTrace) {
      debugPrint('Attachment picker failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  ProjectAttachment generateMetadata({
    required String id,
    required String name,
    required String mimeType,
    required int size,
    required String downloadUrl,
    required String uploadedBy,
    required DateTime createdAt,
    required String storagePath,
  }) {
    return ProjectAttachment(
      id: id,
      name: name,
      mimeType: mimeType,
      size: size,
      downloadUrl: downloadUrl,
      uploadedBy: uploadedBy,
      createdAt: createdAt,
      storagePath: storagePath,
    );
  }

  Future<AttachmentUploadResult> uploadFileWithProgress({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    required Map<String, dynamic> context,
    required void Function(double progress) onProgress,
    required String? authToken,
  }) async {
    final totalBytes = fileBytes.length;
    onProgress(0.0);

    final token = authToken?.trim() ?? '';
    final isIdeaBoard = context['type'] == 'ideaboard';
    if (isIdeaBoard) {
      onProgress(0.1);
      final cloudName = 'dkrfetmrq';
      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

      final projectId = (context['projectId'] as String? ?? '').trim();
      final levelId = (context['levelId'] as String? ?? '').trim();
      final blockId = (context['blockId'] as String? ?? '').trim();
      final folder = 'teamsync/$projectId/idea-board/$levelId/$blockId';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['upload_preset'] = 'ml_default';
      request.fields['folder'] = folder;
      request.fields['resource_type'] = 'auto';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      onProgress(0.5);
      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
      final body = await streamedResponse.stream.bytesToString();
      final cloudinaryResponse = http.Response(body, streamedResponse.statusCode, headers: streamedResponse.headers);

      if (cloudinaryResponse.statusCode != 200 && cloudinaryResponse.statusCode != 201) {
        final errorMessage = _extractCloudinaryError(cloudinaryResponse.body);
        debugPrint('[UPLOAD] Cloudinary unsigned write operation rejected: ${cloudinaryResponse.body}');
        throw Exception(errorMessage);
      }

      final responseData = jsonDecode(cloudinaryResponse.body) as Map<String, dynamic>;
      final String permanentDownloadUrl = responseData['secure_url'] as String? ?? '';
      final String publicId = responseData['public_id'] as String? ?? '';

      if (permanentDownloadUrl.isEmpty) {
        throw Exception('Cloudinary did not return a secure URL.');
      }

      onProgress(1.0);
      debugPrint('[UPLOAD] Asset verified in Cloudinary (unsigned). Permanent link cached: $permanentDownloadUrl');
      return AttachmentUploadResult(
        downloadURL: permanentDownloadUrl,
        storagePath: publicId,
        fileName: fileName,
        fileSize: totalBytes,
        mimeType: mimeType,
        fileId: publicId,
      );
    }

    if (token.isEmpty) {
      throw Exception('Unable to obtain Firebase auth token');
    }

    final signature = await _requestCloudinarySignature(
      authToken: token,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: totalBytes,
      context: context,
    );

    onProgress(0.3);
    debugPrint('[UPLOAD] Cloudinary credentials received for folder: ${signature.folder}');

    onProgress(0.99);
    final cloudinaryResponse = await _sendMultipartUpload(
      uploadUrl: signature.uploadUrl,
      apiKey: signature.apiKey,
      timestamp: signature.timestamp,
      signature: signature.signature,
      folder: signature.folder,
      fileName: fileName,
      mimeType: mimeType,
      fileBytes: fileBytes,
    );

    if (cloudinaryResponse.statusCode != 200 && cloudinaryResponse.statusCode != 201) {
      final errorMessage = _extractCloudinaryError(cloudinaryResponse.body);
      debugPrint('[UPLOAD] Cloudinary write operation rejected: ${cloudinaryResponse.body}');
      throw Exception(errorMessage);
    }

    final responseData = jsonDecode(cloudinaryResponse.body) as Map<String, dynamic>;
    final String permanentDownloadUrl = responseData['secure_url'] as String? ?? '';
    final String publicId = responseData['public_id'] as String? ?? '';

    if (permanentDownloadUrl.isEmpty) {
      throw Exception('Cloudinary did not return a secure URL.');
    }

    if (!permanentDownloadUrl.startsWith('https://res.cloudinary.com')) {
      throw Exception('Cloudinary returned an invalid secure URL.');
    }

    onProgress(1.0);
    debugPrint('[UPLOAD] Asset verified in Cloudinary. Permanent link cached: $permanentDownloadUrl');
    return AttachmentUploadResult(
      downloadURL: permanentDownloadUrl,
      storagePath: publicId,
      fileName: fileName,
      fileSize: totalBytes,
      mimeType: mimeType,
      fileId: publicId,
    );
  }

  Future<List<ProjectAttachment>> uploadFiles({
    required String storagePathPrefix,
    required Map<String, dynamic> context,
    required List<picker.PlatformFile> files,
    required void Function(double progress, String fileName)? onProgress,
    int maxFileSizeBytes = defaultMaxFileSizeBytes,
    Map<String, String>? customMetadata,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final String authToken = ((await authUser.getIdToken(true)) ?? '').trim();
    if (authToken.isEmpty) {
      throw Exception('Unable to obtain Firebase auth token');
    }
    final uploaded = <ProjectAttachment>[];

    for (final file in files) {
      if (file.size > maxFileSizeBytes) {
        throw Exception('File too large. Maximum size is 10MB.');
      }

      final mimeType = _mimeTypeForFileName(file.name);
      if (!_isSupportedUploadType(fileName: file.name, mimeType: mimeType)) {
        throw Exception('File type not supported.');
      }

      final bytes = await _resolveBytes(file);
      debugPrint('Uploading ${file.name} through signed URL pipeline');
      final attachmentId = _firestore.collection('attachments').doc().id;

      try {
        final uploadResult = await uploadFileWithProgress(
          fileName: file.name,
          fileBytes: bytes,
          mimeType: mimeType,
          context: {
            ...context,
            'storagePathPrefix': storagePathPrefix,
            'originalFileName': file.name,
          },
          onProgress: (progress) => onProgress?.call(progress, file.name),
          authToken: authToken,
        );

        final uploadedMeta = generateMetadata(
          id: attachmentId,
          name: file.name,
          mimeType: mimeType,
          size: file.size,
          downloadUrl: uploadResult.downloadURL,
          uploadedBy: authUser.uid,
          createdAt: DateTime.now(),
          storagePath: uploadResult.storagePath,
        );

        try {
          await _firestore.collection('attachments').doc(uploadedMeta.id).set({
            'id': uploadedMeta.id,
            'name': uploadedMeta.name,
            'mimeType': uploadedMeta.mimeType,
            'size': uploadedMeta.size,
            'downloadUrl': uploadedMeta.downloadUrl,
            'file_url': uploadedMeta.downloadUrl,
            'fileUrl': uploadedMeta.downloadUrl,
            'uploadedBy': uploadedMeta.uploadedBy,
            'createdAt': FieldValue.serverTimestamp(),
            'storagePath': uploadedMeta.storagePath,
            ...?customMetadata,
            ...context.map((key, value) => MapEntry(key, value?.toString() ?? '')),
          });
        } catch (e, st) {
          debugPrint('Failed to persist attachment metadata for ${uploadedMeta.id}: $e');
          debugPrintStack(stackTrace: st);
        }

        uploaded.add(uploadedMeta);
      } catch (e, stackTrace) {
        debugPrint('[UPLOAD ERROR DIAGNOSTIC]');
        debugPrint('-> Exception Type: ${e.runtimeType}');
        debugPrint('-> Exception Message: $e');
        debugPrint('-> Forensics Stack: $stackTrace');
        onProgress?.call(0.0, file.name);
        rethrow;
      }
    }

    return uploaded;
  }

  /// Attach files to a chat channel message
  Future<List<ProjectAttachment>> attachToChatChannel({
    required String projectId,
    required String channelId,
    required String text,
    required List<picker.PlatformFile> files,
    String replyToMessageId = '',
    String? messageId,
    void Function(double progress, String fileName)? onProgress,
  }) async {
    if (projectId.trim().isEmpty || channelId.trim().isEmpty) {
      throw ArgumentError('Execution halted: Critical chat identifiers resolved to empty values.');
    }

    try {
      final messageIdValue = messageId ?? _firestore.collection('projects').doc().id;
      final attachments = await uploadFiles(
        storagePathPrefix: 'project_chat_files/$projectId/$channelId',
        context: {
          'type': 'chat',
          'projectId': projectId,
          'channelId': channelId,
          'messageId': messageIdValue,
        },
        files: files,
        onProgress: onProgress,
        customMetadata: {
          'projectId': projectId,
          'channelId': channelId,
          'messageId': messageIdValue,
        },
      );

      await ProjectService.instance.sendChannelMessage(
        projectId: projectId,
        channelId: channelId,
        text: text,
        replyToMessageId: replyToMessageId,
        attachments: attachments.map((attachment) => attachment.toMap()).toList(),
        messageId: messageIdValue,
      );

      return attachments;
    } catch (e, stackTrace) {
      debugPrint('[UPLOAD ERROR DIAGNOSTIC]');
      debugPrint('-> Exception Type: ${e.runtimeType}');
      debugPrint('-> Exception Message: $e');
      debugPrint('-> Forensics Stack: $stackTrace');
      rethrow;
    }
  }

  /// Attach files to chat (DEPRECATED: use attachToChatChannel)
  /// Delegates to #general channel for backward compatibility
  Future<List<ProjectAttachment>> attachToChat({
    required String projectId,
    required String text,
    required List<picker.PlatformFile> files,
    String replyToMessageId = '',
    String? messageId,
    void Function(double progress, String fileName)? onProgress,
  }) async {
    return attachToChatChannel(
      projectId: projectId,
      channelId: 'general',
      text: text,
      files: files,
      replyToMessageId: replyToMessageId,
      messageId: messageId,
      onProgress: onProgress,
    );
  }

  Future<List<ProjectAttachment>> attachToIdeaBoard({
    required String projectId,
    required String levelId,
    required String blockId,
    required List<Map<String, dynamic>> existingFiles,
    required List<picker.PlatformFile> files,
    void Function(double progress, String fileName)? onProgress,
    bool appendToBlock = true,
  }) async {
    if (projectId.trim().isEmpty || blockId.trim().isEmpty) {
      throw ArgumentError('Execution halted: Critical reference identifiers (projectId/blockId) resolved to empty values.');
    }

    try {
      final attachments = await uploadFiles(
        storagePathPrefix: 'project_files/$projectId/$blockId',
        context: {
          'type': 'ideaboard',
          'projectId': projectId,
          'levelId': levelId,
          'blockId': blockId,
        },
        files: files,
        onProgress: onProgress,
        customMetadata: {
          'projectId': projectId,
          'levelId': levelId,
          'blockId': blockId,
        },
      );

      if (appendToBlock) {
        await ProjectService.instance.appendFilesToIdeaBoardBlock(
          projectId: projectId,
          blockId: blockId,
          newFiles: attachments.map((attachment) => attachment.toMap()).toList(),
        );
      }

      return attachments;
    } catch (e, stackTrace) {
      debugPrint('[UPLOAD ERROR DIAGNOSTIC]');
      debugPrint('-> Exception Type: ${e.runtimeType}');
      debugPrint('-> Exception Message: $e');
      debugPrint('-> Forensics Stack: $stackTrace');
      rethrow;
    }
  }

  bool _isSupportedUploadType({
    required String fileName,
    required String mimeType,
  }) {
    final normalizedMime = mimeType.trim().toLowerCase();
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    if (normalizedMime.startsWith('image/')) return true;

    switch (normalizedMime) {
      case 'application/pdf':
      case 'application/zip':
      case 'application/msword':
      case 'application/vnd.ms-excel':
      case 'application/vnd.ms-powerpoint':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      case 'text/plain':
      case 'text/csv':
      case 'application/csv':
        return true;
    }

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'pdf':
      case 'txt':
      case 'csv':
      case 'zip':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'ppt':
      case 'pptx':
        return true;
      default:
        return false;
    }
  }

  String _mapStorageUploadError(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();

    if (normalized.contains('timeout')) {
      return 'Upload paused: request timed out.';
    }
    if (normalized.contains('file_too_large')) {
      return 'Upload paused: file exceeds the 25MB limit.';
    }
    if (normalized.contains('unauthorized') ||
        normalized.contains('permission-denied') ||
        normalized.contains('invalid or expired credentials')) {
      return 'Upload blocked by storage permissions.';
    }
    if (normalized.contains('quota-exceeded')) {
      return 'Upload paused: storage quota exceeded.';
    }
    if (normalized.contains('canceled')) {
      return 'Upload canceled.';
    }

    return message.trim().isNotEmpty ? message.trim() : 'Upload failed.';
  }

  Future<Uint8List> _resolveBytes(picker.PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes!;
    }

    if (file.readStream != null) {
      final chunks = <int>[];
      await for (final chunk in file.readStream!) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    }

    throw Exception('Selected file has no readable content');
  }

  String _sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _mimeTypeForFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  Future<_CloudinarySignatureResponse> _requestCloudinarySignature({
    required String authToken,
    required String fileName,
    required String mimeType,
    required int fileSize,
    required Map<String, dynamic> context,
  }) async {
    debugPrint('[UPLOAD URL] ${AppConfig.apiBaseUrl}/api/storage/cloudinary-signature');
    final gatewayResponse = await http
        .post(
          _storageGatewayBaseUri.resolve('api/storage/cloudinary-signature'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({
            'fileName': fileName,
            'mimeType': mimeType,
            'fileSize': fileSize,
            'context': context,
          }),
        )
        .timeout(_signedUrlTimeout);

    if (gatewayResponse.statusCode != 200) {
      throw Exception(_extractCloudinaryError(gatewayResponse.body));
    }

    final payload = jsonDecode(gatewayResponse.body) as Map<String, dynamic>;
    final uploadUrl = payload['uploadUrl'] as String? ?? '';
    final apiKey = payload['apiKey'] as String? ?? '';
    final signature = payload['signature'] as String? ?? '';
    final folder = payload['folder'] as String? ?? '';
    final timestampValue = payload['timestamp'];
    final timestamp = timestampValue is int
        ? timestampValue
        : int.tryParse(timestampValue?.toString() ?? '') ?? 0;

    if (uploadUrl.isEmpty || apiKey.isEmpty || signature.isEmpty || folder.isEmpty || timestamp == 0) {
      throw Exception('Cloudinary signature endpoint returned incomplete credentials.');
    }

    return _CloudinarySignatureResponse(
      uploadUrl: uploadUrl,
      apiKey: apiKey,
      timestamp: timestamp,
      signature: signature,
      folder: folder,
    );
  }

  Future<http.Response> _sendMultipartUpload({
    required String uploadUrl,
    required String apiKey,
    required int timestamp,
    required String signature,
    required String folder,
    required String fileName,
    required String mimeType,
    required Uint8List fileBytes,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp.toString();
    request.fields['signature'] = signature;
    request.fields['folder'] = folder;
    request.fields['resource_type'] = 'auto';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
    final body = await streamedResponse.stream.bytesToString();
    return http.Response(body, streamedResponse.statusCode, headers: streamedResponse.headers);
  }

  String _extractCloudinaryError(String body) {
    if (body.trim().isEmpty) {
      return 'Cloudinary upload failed.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          return error['message']?.toString() ?? 'Cloudinary upload failed.';
        }
        if (error != null) {
          return error.toString();
        }
      }
    } catch (_) {
      // Fall back to raw body below.
    }

    return body.trim();
  }

  Future<void> deleteFile({required String publicId}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) throw Exception('User must be logged in to delete files');

    final token = await authUser.getIdToken();
    final response = await http.post(
      _storageGatewayBaseUri.resolve('api/storage/delete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'publicId': publicId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete file: ${response.body}');
    }
  }
}

class _CloudinarySignatureResponse {
  final String uploadUrl;
  final String apiKey;
  final int timestamp;
  final String signature;
  final String folder;

  const _CloudinarySignatureResponse({
    required this.uploadUrl,
    required this.apiKey,
    required this.timestamp,
    required this.signature,
    required this.folder,
  });
}
