import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'user_service.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService.instance;

  Stream<T> _retryingStream<T>(
    String label,
    Stream<T> Function() createStream, {
    Duration initialDelay = const Duration(milliseconds: 300),
    Duration maxDelay = const Duration(seconds: 5),
  }) async* {
    var attempt = 0;

    while (true) {
      try {
        await for (final value in createStream()) {
          attempt = 0;
          yield value;
        }
        return;
      } catch (e) {
        attempt += 1;
        final delayMs = initialDelay.inMilliseconds * attempt;
        final clampedDelayMs = delayMs.clamp(
          initialDelay.inMilliseconds,
          maxDelay.inMilliseconds,
        );
        print('⚠️ $label stream error: $e');
        await Future.delayed(Duration(milliseconds: clampedDelayMs));
      }
    }
  }

  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value(null);
      }

      return _retryingStream<AppUser?>(
        'watchCurrentUser(${authUser.uid})',
        () => _firestore.collection('users').doc(authUser.uid).snapshots().map(
          (snapshot) {
            final data = snapshot.data();
            if (data == null) {
              return AppUser(
                id: authUser.uid,
                username: '',
                name: authUser.displayName ?? 'User',
                email: authUser.email ?? '',
                projectsJoined: 0,
                tasksCompleted: 0,
                createdAt: DateTime.now(),
              );
            }

            return AppUser(
              id: authUser.uid,
              username: (data['username'] as String?)?.trim() ?? '',
              name: (data['name'] as String?)?.trim().isNotEmpty == true
                  ? data['name'] as String
                  : (authUser.displayName ?? 'User'),
              email: (data['email'] as String?) ?? authUser.email ?? '',
              projectsJoined: (data['projectsJoined'] as int?) ?? 0,
              tasksCompleted: (data['tasksCompleted'] as int?) ?? 0,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            );
          },
        ),
      );
    });
  }

  /// Update current user name
  Future<void> updateCurrentUserName(String name) async {
    final authUser = _auth.currentUser;
    final trimmedName = name.trim();

    if (authUser == null || trimmedName.isEmpty) {
      return;
    }

    try {
      await authUser.updateDisplayName(trimmedName);
      await _userService.updateUserProfile(
        userId: authUser.uid,
        name: trimmedName,
      );
    } catch (e) {
      throw Exception('Failed to update name: ${e.toString()}');
    }
  }

  /// Update current user username
  Future<void> updateCurrentUserUsername(String username) async {
    await repairCurrentUserUsername(username);
  }

  Future<void> repairCurrentUserUsername(String username) async {
    final authUser = _auth.currentUser;
    final trimmedUsername = username.trim();

    if (authUser == null || trimmedUsername.isEmpty) {
      return;
    }

    if (!UserService.isValidUsernameFormat(trimmedUsername)) {
      throw Exception(
          'Username must start with a letter and use only letters, numbers, or underscores');
    }

    final isAvailable = await _userService.isUsernameAvailable(trimmedUsername);
    if (!isAvailable) {
      throw Exception('Username already taken');
    }

    try {
      final existingDoc =
          await _firestore.collection('users').doc(authUser.uid).get();
      if (!existingDoc.exists) {
        await _userService.createUserDocument(
          userId: authUser.uid,
          username: trimmedUsername,
          name: authUser.displayName?.trim().isNotEmpty == true
              ? authUser.displayName!.trim()
              : 'User',
          email: authUser.email ?? '',
        );
        return;
      }

      await _userService.updateUserProfile(
          userId: authUser.uid, username: trimmedUsername);
    } catch (e) {
      throw Exception('Failed to update username: ${e.toString()}');
    }
  }

  /// Get current user  (one-time fetch, not stream)
  Future<AppUser?> getCurrentUser() async {
    return _userService.getCurrentUser();
  }
}
