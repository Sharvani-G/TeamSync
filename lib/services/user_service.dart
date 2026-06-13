import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$');
  static final RegExp _usernameSearchPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

  static String normalizeUsername(String username) {
    return username.trim();
  }

  static String normalizeUsernameKey(String username) {
    return normalizeUsername(username).toLowerCase();
  }

  static bool isValidUsernameFormat(String username) {
    return _usernamePattern.hasMatch(normalizeUsername(username));
  }

  static bool isValidUsernameSearchQuery(String query) {
    return _usernameSearchPattern.hasMatch(normalizeUsername(query));
  }

  static bool isLegacyEmailDerivedUsername({
    required String username,
    required String email,
  }) {
    final normalizedUsername = normalizeUsernameKey(username);
    final emailLocalPart = email.trim().split('@').first.toLowerCase();
    final sanitizedEmailLocalPart = emailLocalPart.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final collapsedSanitized = sanitizedEmailLocalPart.replaceAll(RegExp(r'_+'), '_');

    return normalizedUsername.isNotEmpty &&
        (normalizedUsername == emailLocalPart ||
            normalizedUsername == sanitizedEmailLocalPart ||
            normalizedUsername == collapsedSanitized ||
            normalizedUsername.startsWith('user_'));
  }

  static bool needsUsernameRepair({
    required String username,
    required String email,
  }) {
    if (!isValidUsernameFormat(username)) {
      return true;
    }

    if (email.trim().isEmpty) {
      return false;
    }

    return isLegacyEmailDerivedUsername(username: username, email: email);
  }

  /// Get user by username (case-insensitive lookup for UI, case-sensitive storage)
  Future<(String userId, String username, String name, String email)?> getUserByUsername(
    String username,
  ) async {
    try {
      final normalized = normalizeUsernameKey(username);
      if (!isValidUsernameSearchQuery(username)) {
        return null;
      }

      final query = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: normalized)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      final data = doc.data();

      return (
        doc.id,
        data['username'] as String? ?? username.trim(),
        data['name'] as String? ?? 'Unknown',
        data['email'] as String? ?? 'unknown@email.com',
      );
    } catch (e) {
      throw Exception('Failed to lookup user: ${e.toString()}');
    }
  }

  /// Get user by ID
  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return AppUser(
        id: userId,
        username: data['username'] as String? ?? '',
        name: data['name'] as String? ?? 'Unknown',
        email: data['email'] as String? ?? '',
        photoUrl: data['photoUrl'] as String? ?? '',
        projectsJoined: data['projectsJoined'] as int? ?? 0,
        tasksCompleted: data['tasksCompleted'] as int? ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  /// Search users by username or name (for future invite features)
  Future<List<(String userId, String username, String name)>> searchUsers(
    String query,
  ) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final trimmedQuery = normalizeUsername(query);
      if (!isValidUsernameSearchQuery(trimmedQuery)) {
        return [];
      }

      final lowerQuery = normalizeUsernameKey(trimmedQuery);

      // Search by username
      final usernameQuery = await _firestore
          .collection('users')
          .where('usernameLower', isGreaterThanOrEqualTo: lowerQuery)
          .where('usernameLower', isLessThan: '$lowerQuery\uf8ff')
          .limit(10)
          .get();

      final results = <(String, String, String)>[];

      for (final doc in usernameQuery.docs) {
        results.add((
          doc.id,
          doc['username'] as String? ?? '',
          doc['name'] as String? ?? '',
        ));
      }

      return results;
    } catch (e) {
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }

  /// Validate that a username exists and is not current user
  Future<bool> isValidCollaborator(String username, String currentUserId) async {
    try {
      final user = await getUserByUsername(username);
      if (user == null) {
        return false;
      }

      // Don't allow self-assignment
      return user.$1 != currentUserId;
    } catch (e) {
      return false;
    }
  }

  /// Get multiple users by IDs (for fetching collaborator details)
  Future<Map<String, AppUser>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) {
      return {};
    }

    try {
      final result = <String, AppUser>{};

      // Firestore has a limit of 10 items in "in" query
      final chunks = <List<String>>[];
      for (int i = 0; i < userIds.length; i += 10) {
        chunks.add(userIds.sublist(
          i,
          i + 10 > userIds.length ? userIds.length : i + 10,
        ));
      }

      for (final chunk in chunks) {
        final query = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in query.docs) {
          final data = doc.data();
          result[doc.id] = AppUser(
            id: doc.id,
            username: data['username'] as String? ?? '',
            name: data['name'] as String? ?? 'Unknown',
            email: data['email'] as String? ?? '',
            photoUrl: data['photoUrl'] as String? ?? '',
            projectsJoined: data['projectsJoined'] as int? ?? 0,
            tasksCompleted: data['tasksCompleted'] as int? ?? 0,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }
      }

      return result;
    } catch (e) {
      throw Exception('Failed to get users: ${e.toString()}');
    }
  }

  /// Create user document after Firebase Auth signup
  /// Called from auth service after successful signup
  Future<void> createUserDocument({
    required String userId,
    required String username,
    required String name,
    required String email,
  }) async {
    try {
      final exactUsername = normalizeUsername(username);
      final lowerUsername = normalizeUsernameKey(username);

      if (!isValidUsernameFormat(exactUsername)) {
        throw Exception('Username must start with a letter and use only letters, numbers, or underscores');
      }

      // Check if username already exists
      final existing = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: lowerUsername)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Username already taken');
      }

      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'username': exactUsername,
        'usernameLower': lowerUsername, // For case-insensitive search
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'photoUrl': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'projectsJoined': 0,
        'tasksCompleted': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  /// Update user profile information
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? username,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      if (name != null && name.trim().isNotEmpty) {
        updateData['name'] = name.trim();
      }

      final authPhoto = _auth.currentUser?.photoURL;
      if (authPhoto != null && authPhoto.trim().isNotEmpty) {
        updateData['photoUrl'] = authPhoto.trim();
      }

      if (username != null && username.trim().isNotEmpty) {
        final exactUsername = normalizeUsername(username);
        final lowerUsername = normalizeUsernameKey(username);

        if (!isValidUsernameFormat(exactUsername)) {
          throw Exception('Username must start with a letter and use only letters, numbers, or underscores');
        }

        // Verify username is available (shouldn't happen in normal flow)
        final existing = await _firestore
            .collection('users')
            .where('usernameLower', isEqualTo: lowerUsername)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty &&
            existing.docs.first.id != userId) {
          throw Exception('Username already taken');
        }

        updateData['username'] = exactUsername;
        updateData['usernameLower'] = lowerUsername;
      }

      if (updateData.length > 1) {
        // Only update if there are actual changes
        await _firestore.collection('users').doc(userId).update(updateData);
      }
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      if (!isValidUsernameSearchQuery(username)) {
        return false;
      }

      final query = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: normalizeUsernameKey(username))
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      // Bypass check if we encounter a permission or query error before login.
      return true;
    }
  }

  /// Get current user as AppUser
  Future<AppUser?> getCurrentUser() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return null;
    }

    return getUserById(authUser.uid);
  }

  /// Stream current user for real-time updates
  Stream<AppUser?> watchCurrentUser() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(authUser.uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return AppUser(
        id: doc.id,
        username: data['username'] as String? ?? '',
        name: data['name'] as String? ?? 'Unknown',
        email: data['email'] as String? ?? '',
        projectsJoined: data['projectsJoined'] as int? ?? 0,
        tasksCompleted: data['tasksCompleted'] as int? ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    });
  }
}
