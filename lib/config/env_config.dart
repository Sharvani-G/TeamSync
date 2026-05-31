import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

enum TeamSyncEnvironmentProfile {
  local,
  production,
}

class TeamSyncEnvConfig {
  TeamSyncEnvConfig._({
    required this.profile,
    required this.firebaseOptions,
    required this.storageBucketUri,
    required this.storageRegion,
  });

  static final Future<TeamSyncEnvConfig> instance = resolve();

  final TeamSyncEnvironmentProfile profile;
  final FirebaseOptions firebaseOptions;
  final String storageBucketUri;
  final String storageRegion;

  static Future<TeamSyncEnvConfig> resolve() async {
    final String profileEnv = const String.fromEnvironment('TEAMSYNC_PROFILE');
    final normalizedProfile = profileEnv.trim().toLowerCase();
    final isDev = normalizedProfile == 'development';

    if (normalizedProfile == 'local' || normalizedProfile == 'dev' || isDev) {
      return TeamSyncEnvConfig.local();
    }

    if (normalizedProfile == 'production' ||
        normalizedProfile == 'prod' ||
        normalizedProfile == 'release') {
      return TeamSyncEnvConfig.production();
    }

    return TeamSyncEnvConfig.production();
  }

  static TeamSyncEnvConfig production() {
    return _buildConfig(TeamSyncEnvironmentProfile.production);
  }

  static TeamSyncEnvConfig local() {
    return _buildConfig(TeamSyncEnvironmentProfile.local);
  }

  static TeamSyncEnvConfig _buildConfig(TeamSyncEnvironmentProfile profile) {
    final baseOptions = DefaultFirebaseOptions.currentPlatform;
    final bucketToken = baseOptions.storageBucket?.trim() ?? '';
    if (bucketToken.isEmpty) {
      throw StateError('TEAMSYNC_STORAGE_BUCKET_URI_INVALID: empty token');
    }

    final bucketName = _resolveBucketName(bucketToken);
    final bucketUri = profile == TeamSyncEnvironmentProfile.production
        ? 'https://firebasestorage.googleapis.com/v0/b/$bucketName/o'
        : 'gs://$bucketName';

    if (!_isValidBucketUri(bucketUri)) {
      throw StateError('TEAMSYNC_STORAGE_BUCKET_URI_INVALID: $bucketUri');
    }

    final storageRegion = profile == TeamSyncEnvironmentProfile.production
        ? 'asia-south1'
        : 'local-testing';

    if (bucketName.trim().isEmpty) {
      throw StateError('TEAMSYNC_STORAGE_BUCKET_URI_INVALID: empty bucket name');
    }

    return TeamSyncEnvConfig._(
      profile: profile,
      firebaseOptions: FirebaseOptions(
        apiKey: baseOptions.apiKey,
        appId: baseOptions.appId,
        messagingSenderId: baseOptions.messagingSenderId,
        projectId: baseOptions.projectId,
        authDomain: baseOptions.authDomain,
        storageBucket: bucketName,
        measurementId: _nullableString(baseOptions.measurementId),
      ),
      storageBucketUri: bucketUri,
      storageRegion: storageRegion,
    );
  }

  static String _resolveBucketName(String storageBucket) {
    final trimmed = storageBucket.trim();
    if (trimmed.startsWith('gs://')) {
      return trimmed.substring(5);
    }
    if (trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.length >= 3) {
        return uri.pathSegments[2];
      }
    }
    return trimmed;
  }

  static bool _isValidBucketUri(String bucketUri) {
    final uri = Uri.tryParse(bucketUri.trim());
    if (uri == null) return false;
    return uri.scheme == 'gs' ||
        (uri.scheme == 'https' &&
            uri.host == 'firebasestorage.googleapis.com');
  }

  static String? _nullableString(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void logStartupSelection() {
    final mode = profile == TeamSyncEnvironmentProfile.production
        ? 'production'
        : 'local';
    debugPrint('[ENV] selected $mode profile');
    debugPrint('[ENV] storage bucket uri: $storageBucketUri');
    debugPrint('[ENV] storage region: $storageRegion');
  }
}