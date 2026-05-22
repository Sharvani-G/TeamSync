import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart' as picker;

import 'user_service.dart';

typedef PlatformFile = picker.PlatformFile;


class FileService {
  FileService._();

  static final FileService instance = FileService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Uint8List> _resolveBytes(PlatformFile file) async {
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

  Future<String> _resolveUsername(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final username = doc.data()?['username'] as String? ?? '';
      return username.trim();
    } catch (e) {
      print('Failed to resolve uploader username: $e');
      return '';
    }
  }

  Future<String> uploadBytes({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
    Map<String, String>? metadata,
  }) async {
    final ref = _storage.ref(storagePath);
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: contentType, customMetadata: metadata),
    );
    await task;
    return ref.getDownloadURL();
  }

  /// Upload a single file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required PlatformFile file,
    required String projectId,
    required String requestId,
    String? fileName,
  }) async {
    try {
      final authUser = _auth.currentUser;
      if (authUser == null) {
        throw Exception('User must be logged in');
      }

      // Construct storage path: joinRequests/{projectId}/{requestId}/{fileName}
        final fallbackName = file.path?.split('/').last ?? 'file';
        final storageFileName = fileName ?? file.name.ifEmpty(fallbackName);
      final storagePath =
          'joinRequests/$projectId/$requestId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(storageFileName),
        customMetadata: {
          'projectId': projectId,
          'requestId': requestId,
          'uploadedBy': authUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      if (file.bytes == null) {
        throw Exception('Selected file has no readable content');
      }
      final uploadTask = ref.putData(file.bytes!, metadata);

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  /// Upload multiple files
  Future<List<String>> uploadPortfolioFiles(
    String projectId,
    List<PlatformFile> files,
  ) async {
    try {
      final urls = <String>[];
      final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';

      for (final file in files) {
        try {
          final url = await uploadFile(
            file: file,
            projectId: projectId,
            requestId: requestId,
          );
          urls.add(url);
        } catch (e) {
          // Continue with other files even if one fails
          print('Failed to upload file: ${e.toString()}');
        }
      }

      if (urls.isEmpty && files.isNotEmpty) {
        throw Exception('Failed to upload all files');
      }

      return urls;
    } catch (e) {
      throw Exception('Failed to upload portfolio files: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> uploadIdeaBoardAttachment({
    required String projectId,
    required String levelId,
    required String blockId,
    required PlatformFile file,
    String? fileId,
    void Function(double progress, String fileName)? onProgress,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final fileName = file.name;
    final attachmentId = fileId ?? _firestore.collection('projectFiles').doc().id;
    final storagePath = 'project_files/$projectId/$blockId/$attachmentId';
    final uploadedByUsername = await _resolveUsername(authUser.uid);

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: _getContentType(fileName),
      customMetadata: {
        'projectId': projectId,
        'levelId': levelId,
        'blockId': blockId,
        'uploadedBy': authUser.uid,
        'uploadedByUsername': uploadedByUsername,
        'fileName': fileName,
      },
    );

    final bytes = await _resolveBytes(file);
    final task = ref.putData(bytes, metadata);

    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes, fileName);
      }
    }, onError: (error) {
      print('Upload progress stream failed for $fileName: $error');
    });

    await task;

    final url = await ref.getDownloadURL();
    return {
      'id': attachmentId,
      'fileName': fileName,
      'fileUrl': url,
      'fileType': _getCategory(fileName),
      'fileSize': file.size,
      'uploadedBy': authUser.uid,
      'uploadedByUsername': uploadedByUsername,
      'uploadedAt': DateTime.now().toIso8601String(),
      'storagePath': ref.fullPath,
      'projectId': projectId,
      'blockId': blockId,
      'name': fileName,
      'url': url,
      'type': _getCategory(fileName),
      'sizeBytes': file.size,
    };
  }

  Future<Map<String, dynamic>> uploadProjectChatAttachment({
    required String projectId,
    required String messageId,
    required PlatformFile file,
    String? fileId,
    void Function(double progress, String fileName)? onProgress,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final attachmentId = fileId ?? _firestore.collection('projectFiles').doc().id;
    final storagePath = 'project_chat_files/$projectId/$messageId/$attachmentId';
    final uploadedByUsername = await _resolveUsername(authUser.uid);

    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: _getContentType(file.name),
      customMetadata: {
        'projectId': projectId,
        'messageId': messageId,
        'uploadedBy': authUser.uid,
        'uploadedByUsername': uploadedByUsername,
        'fileName': file.name,
      },
    );

    final bytes = await _resolveBytes(file);
    final task = ref.putData(bytes, metadata);
    task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes, file.name);
      }
    }, onError: (error) {
      print('Upload progress stream failed for ${file.name}: $error');
    });

    await task;

    final url = await ref.getDownloadURL();
    return {
      'id': attachmentId,
      'fileName': file.name,
      'fileUrl': url,
      'fileType': _getCategory(file.name),
      'fileSize': file.size,
      'uploadedBy': authUser.uid,
      'uploadedByUsername': uploadedByUsername,
      'uploadedAt': DateTime.now().toIso8601String(),
      'storagePath': ref.fullPath,
      'projectId': projectId,
      'messageId': messageId,
      'name': file.name,
      'url': url,
      'type': _getCategory(file.name),
      'sizeBytes': file.size,
    };
  }

  Future<void> deleteIdeaBoardAttachment(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return;
    }

    try {
      await _storage.ref(storagePath).delete();
    } catch (e) {
      print('Failed to delete idea board attachment [$storagePath]: ${e.toString()}');
    }
  }

  Future<void> deleteProjectChatAttachment(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return;
    }

    try {
      await _storage.ref(storagePath).delete();
    } catch (e) {
      print('Failed to delete chat attachment [$storagePath]: ${e.toString()}');
    }
  }

  /// Get download URL for a file
  Future<String> getDownloadUrl({
    required String projectId,
    required String requestId,
    required String fileName,
  }) async {
    try {
      final storagePath = 'joinRequests/$projectId/$requestId/$fileName';
      final ref = _storage.ref(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get download URL: ${e.toString()}');
    }
  }

  /// Delete a file from storage
  Future<void> deleteFile({
    required String projectId,
    required String requestId,
    required String fileName,
  }) async {
    try {
      final storagePath = 'joinRequests/$projectId/$requestId/$fileName';
      final ref = _storage.ref(storagePath);
      await ref.delete();
    } catch (e) {
      print('Failed to delete file: ${e.toString()}');
      // Don't throw - file might already be deleted
    }
  }

  /// Delete all files for a request
  Future<void> deleteRequestFiles({
    required String projectId,
    required String requestId,
  }) async {
    try {
      final storagePath = 'joinRequests/$projectId/$requestId';
      final ref = _storage.ref(storagePath);

      // List all files in the directory
      final result = await ref.listAll();

      // Delete each file
      for (final item in result.items) {
        await item.delete();
      }
    } catch (e) {
      print('Failed to delete request files: ${e.toString()}');
      // Don't throw - files might already be deleted
    }
  }

  /// Get content type from file extension
  String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();

    const mimeTypes = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
    };

    return mimeTypes[extension] ?? 'application/octet-stream';
  }

  String _getCategory(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'].contains(extension)) {
      return 'image';
    }
    if (['pdf'].contains(extension)) {
      return 'pdf';
    }
    if (['doc', 'docx', 'txt', 'csv'].contains(extension)) {
      return 'doc';
    }
    if (['zip', 'rar'].contains(extension)) {
      return 'zip';
    }
    return 'file';
  }

  /// Get file size in MB
  static double getFileSize(PlatformFile file) {
    return file.size / (1024 * 1024);
  }

  /// Check if file size is acceptable (max 10 MB per file)
  static bool isFileSizeValid(PlatformFile file, {double maxMB = 10}) {
    return getFileSize(file) <= maxMB;
  }

  /// Extract file name from path
  static String getFileName(String filePath) {
    return filePath.split('/').last;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
