import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'file_picker_web_bootstrap_stub.dart'
  if (dart.library.html) 'file_picker_web_bootstrap_web.dart';
import 'project_service.dart';

class AttachmentService {
  AttachmentService._();

  static final AttachmentService instance = AttachmentService._();

  static const int defaultMaxFileSizeBytes = 25 * 1024 * 1024;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

  Future<List<ProjectAttachment>> uploadFiles({
    required String storagePathPrefix,
    required List<picker.PlatformFile> files,
    required void Function(double progress, String fileName)? onProgress,
    int maxFileSizeBytes = defaultMaxFileSizeBytes,
    Map<String, String>? customMetadata,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final uploaded = <ProjectAttachment>[];
    for (final file in files) {
      if (file.size > maxFileSizeBytes) {
        throw Exception('File too large: ${file.name} exceeds ${maxFileSizeBytes ~/ (1024 * 1024)} MB');
      }

      final bytes = await _resolveBytes(file);
      final fileId = _firestore.collection('attachments').doc().id;
      final storagePath = '$storagePathPrefix/${_sanitizeFileName(file.name)}';
      final mimeType = _mimeTypeForFileName(file.name);
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'uploadedBy': authUser.uid,
          'fileName': file.name,
          'mimeType': mimeType,
          'size': file.size.toString(),
          ...?customMetadata,
        },
      );

      debugPrint('Uploading ${file.name} to $storagePath');

      try {
        final task = ref.putData(bytes, metadata);
        task.snapshotEvents.listen((snapshot) {
          if (snapshot.totalBytes <= 0) {
            return;
          }
          onProgress?.call(
              snapshot.bytesTransferred / snapshot.totalBytes, file.name);
        }, onError: (error) {
          debugPrint('Upload progress stream failed for ${file.name}: $error');
        });

        await task;
        final downloadUrl = await ref.getDownloadURL();
        final uploadedMeta = generateMetadata(
          id: fileId,
          name: file.name,
          mimeType: mimeType,
          size: file.size,
          downloadUrl: downloadUrl,
          uploadedBy: authUser.uid,
          createdAt: DateTime.now(),
          storagePath: ref.fullPath,
        );

        // Persist attachment metadata to Firestore attachments collection
        try {
          await _firestore.collection('attachments').doc(uploadedMeta.id).set({
            'id': uploadedMeta.id,
            'name': uploadedMeta.name,
            'mimeType': uploadedMeta.mimeType,
            'size': uploadedMeta.size,
            'downloadUrl': uploadedMeta.downloadUrl,
            'fileUrl': uploadedMeta.downloadUrl,
            'uploadedBy': uploadedMeta.uploadedBy,
            'createdAt': FieldValue.serverTimestamp(),
            'storagePath': uploadedMeta.storagePath,
            ...?customMetadata,
          });
        } catch (e, st) {
          debugPrint('Failed to persist attachment metadata for ${uploadedMeta.id}: $e');
          debugPrintStack(stackTrace: st);
        }

        uploaded.add(uploadedMeta);
      } on FirebaseException catch (error, stackTrace) {
        debugPrint('Storage upload failed for ${file.name}: ${error.code} ${error.message}');
        debugPrintStack(stackTrace: stackTrace);
        if (error.code == 'permission-denied' || error.code == 'unauthorized') {
          throw Exception(
            'Upload blocked by storage permissions for ${file.name}. Please refresh and try again after allowing web access to the bucket.',
          );
        }
        rethrow;
      } catch (error, stackTrace) {
        debugPrint('Unexpected upload failure for ${file.name}: $error');
        debugPrintStack(stackTrace: stackTrace);
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
    final messageIdValue = messageId ?? _firestore.collection('projects').doc().id;
    final attachments = await uploadFiles(
      storagePathPrefix: 'project_chats/$projectId',
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
    final attachments = await uploadFiles(
      storagePathPrefix: 'project_files/$projectId/$blockId',
      files: files,
      onProgress: onProgress,
      customMetadata: {
        'projectId': projectId,
        'levelId': levelId,
        'blockId': blockId,
      },
    );

    // Optionally append files transactionally to avoid overwriting concurrent updates.
    if (appendToBlock) {
      await ProjectService.instance.appendFilesToIdeaBoardBlock(
        projectId: projectId,
        blockId: blockId,
        newFiles: attachments.map((attachment) => attachment.toMap()).toList(),
      );
    }

    return attachments;
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
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
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
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }
}
