import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/mock_data.dart';
import '../models/models.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<AppUser> watchCurrentUser() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value(currentUser);
    }

    return _firestore.collection('users').doc(authUser.uid).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) {
          return AppUser(
            id: authUser.uid,
            name: authUser.displayName ?? currentUser.name,
            email: authUser.email ?? currentUser.email,
            projectsJoined: currentUser.projectsJoined,
            tasksCompleted: currentUser.tasksCompleted,
          );
        }

        return AppUser(
          id: (data['uid'] as String?) ?? authUser.uid,
          name: (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name'] as String
              : (authUser.displayName ?? currentUser.name),
          email: (data['email'] as String?) ?? authUser.email ?? currentUser.email,
          projectsJoined: currentUser.projectsJoined,
          tasksCompleted: currentUser.tasksCompleted,
        );
      },
    );
  }

  Future<void> updateCurrentUserName(String name) async {
    final authUser = _auth.currentUser;
    final trimmedName = name.trim();

    if (authUser == null || trimmedName.isEmpty) {
      return;
    }

    await authUser.updateDisplayName(trimmedName);
    await _firestore.collection('users').doc(authUser.uid).set(
      {
        'uid': authUser.uid,
        'name': trimmedName,
        'email': authUser.email ?? currentUser.email,
      },
      SetOptions(merge: true),
    );
  }
}