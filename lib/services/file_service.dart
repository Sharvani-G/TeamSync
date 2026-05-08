import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FileService {
  FileService._();

  static final FileService instance = FileService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a single file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required File file,
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
      final storageFileName = fileName ?? file.path.split('/').last;
      final storagePath =
          'joinRequests/$projectId/$requestId/$storageFileName';

      final ref = _storage.ref(storagePath);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(file.path),
        customMetadata: {
          'projectId': projectId,
          'requestId': requestId,
          'uploadedBy': authUser.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      // Wait for upload to complete
      final taskSnapshot = await uploadTask;

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
    List<File> files,
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

  /// Get file size in MB
  static double getFileSize(File file) {
    return file.lengthSync() / (1024 * 1024);
  }

  /// Check if file size is acceptable (max 10 MB per file)
  static bool isFileSizeValid(File file, {double maxMB = 10}) {
    return getFileSize(file) <= maxMB;
  }

  /// Extract file name from path
  static String getFileName(String filePath) {
    return filePath.split('/').last;
  }
}
