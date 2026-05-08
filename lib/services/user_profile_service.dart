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

  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value(null);
      }

      return _firestore.collection('users').doc(authUser.uid).snapshots().map(
        (snapshot) {
          final data = snapshot.data();
          if (data == null) {
            // User document doesn't exist yet, create default.
            return AppUser(
              id: authUser.uid,
              username: authUser.email?.split('@').first ?? 'user',
              name: authUser.displayName ?? 'User',
              email: authUser.email ?? '',
              projectsJoined: 0,
              tasksCompleted: 0,
              createdAt: DateTime.now(),
            );
          }

          return AppUser(
            id: authUser.uid,
            username: (data['username'] as String?) ?? 'unknown',
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
    final authUser = _auth.currentUser;
    final trimmedUsername = username.trim();

    if (authUser == null || trimmedUsername.isEmpty) {
      return;
    }

    try {
      await _userService.updateUserProfile(
        userId: authUser.uid,
        username: trimmedUsername,
      );
    } catch (e) {
      throw Exception('Failed to update username: ${e.toString()}');
    }
  }

  /// Get current user  (one-time fetch, not stream)
  Future<AppUser?> getCurrentUser() async {
    return _userService.getCurrentUser();
  }
}