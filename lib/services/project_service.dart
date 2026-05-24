import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'file_service.dart';
import 'user_service.dart';

class ProjectService {
  ProjectService._();

  static final ProjectService instance = ProjectService._();

  static const List<String> _defaultLevelTitles = [
    'Problem Statement',
    'Ideation',
    'Research',
    'Development',
    'Testing',
    'Documentation',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService.instance;

  bool _isAdminRole(Map<String, dynamic> data, String userId) {
    final createdBy = data['createdBy'] as String?;
    final collaborators = _parseCollaboratorsMap(
      data['collaborators'],
      docId: data['id'] as String? ?? '',
    );
    return createdBy == userId || collaborators[userId] == 'admin';
  }

  bool _canEditIdeaBoard(Map<String, dynamic> data, String userId) {
    final createdBy = data['createdBy'] as String? ?? '';
    final collaborators = _parseCollaboratorsMap(
      data['collaborators'],
      docId: data['id'] as String? ?? '',
    );
    return createdBy == userId || collaborators.containsKey(userId);
  }

  // ============ PROJECT STREAMS ============

  /// Get all projects for the current user (created by or collaborator)
  /// Real-time stream that combines created projects and collaborator projects
  Stream<List<Project>> watchMyProjects() {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value([]);
      }

      // Create a stream controller first
      late StreamController<List<Project>> controller;
      controller = StreamController<List<Project>>.broadcast(onCancel: () {
        // Will be managed in onListen
      });

      // We'll manually subscribe to the three queries
      late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subCreated;
      late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subAdmin;
      late StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
          subCollaborator;

      QuerySnapshot<Map<String, dynamic>>? lastCreated;
      QuerySnapshot<Map<String, dynamic>>? lastAdmin;
      QuerySnapshot<Map<String, dynamic>>? lastCollaborator;

      void emitCombined() {
        final docsMap = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        if (lastCreated != null) {
          for (final d in lastCreated!.docs) docsMap[d.id] = d;
        }
        if (lastAdmin != null) {
          for (final d in lastAdmin!.docs) docsMap[d.id] = d;
        }
        if (lastCollaborator != null) {
          for (final d in lastCollaborator!.docs) docsMap[d.id] = d;
        }

        final projects = <Project>[];
        for (final doc in docsMap.values) {
          try {
            projects.add(_parseProject(doc));
          } catch (e) {
            print('⚠️ Error parsing project ${doc.id}: $e');
          }
        }

        if (!controller.isClosed) {
          controller.add(projects);
        }
      }

      try {
        // Query 1: projects created by the user
        final createdQuery = _firestore
            .collection('projects')
            .where('createdBy', isEqualTo: authUser.uid)
            .snapshots();

        // Query 2: projects where user is admin
        final adminQuery = _firestore
            .collection('projects')
            .where('collaborators.${authUser.uid}', isEqualTo: 'admin')
            .snapshots();

        // Query 3: projects where user is collaborator
        final collaboratorQuery = _firestore
            .collection('projects')
            .where('collaborators.${authUser.uid}', isEqualTo: 'collaborator')
            .snapshots();

        subCreated = createdQuery.listen((snap) {
          lastCreated = snap;
          emitCombined();
        }, onError: (e, st) {
          print('⚠️ watchMyProjects createdQuery error: $e');
        });

        subAdmin = adminQuery.listen((snap) {
          lastAdmin = snap;
          emitCombined();
        }, onError: (e, st) {
          print('⚠️ watchMyProjects adminQuery error: $e');
        });

        subCollaborator = collaboratorQuery.listen((snap) {
          lastCollaborator = snap;
          emitCombined();
        }, onError: (e, st) {
          print('⚠️ watchMyProjects collaboratorQuery error: $e');
        });

        controller.onCancel = () async {
          await subCreated.cancel();
          await subAdmin.cancel();
          await subCollaborator.cancel();
        };
      } catch (e) {
        print('❌ Error setting up watchMyProjects queries: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }

      return controller.stream;
    });
  }

  /// Get all public projects for discovery
  Stream<List<Project>> watchPublicProjects() {
    return _firestore
        .collection('projects')
        .where('visibility', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _parseProject(doc)).toList();
    });
  }

  /// Get a single project by ID
  Stream<Project?> watchProject(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _parseProject(doc);
    });
  }

  // ============ PROJECT CREATION ============

  /// Create a new project with collaborators
  /// VALIDATES all collaborator usernames before creating
  Future<String> createProject({
    required String title,
    required String description,
    required List<String> collaboratorUsernames, // List of usernames to add
    required String visibility, // 'public' or 'private'
    required bool isOpenForRequests,
    required int requiredCollaborators,
    required List<String> requiredSkills,
    required String contactEmail,
    List<Map<String, dynamic>>? levels,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in to create a project');
    }

    // Validate inputs
    if (title.trim().isEmpty) {
      throw Exception('Project title cannot be empty');
    }
    if (description.trim().isEmpty) {
      throw Exception('Project description cannot be empty');
    }

    // Validate visibility
    if (visibility != 'public' && visibility != 'private') {
      throw Exception('Visibility must be public or private');
    }

    // If private, disable requests
    bool finalIsOpenForRequests = visibility == 'public' && isOpenForRequests;

    // Lookup and validate all collaborators
    final collaborators = <String, String>{
      authUser.uid: 'admin',
    }; // Map<userId, role>

    // Remove duplicates and current user from list
    final uniqueUsernames =
        {...collaboratorUsernames}.where((u) => u.trim().isNotEmpty).toList();

    for (final username in uniqueUsernames) {
      final user = await _userService.getUserByUsername(username);

      if (user == null) {
        throw Exception('User "@$username" not found');
      }

      if (user.$1 == authUser.uid) {
        throw Exception('Cannot add yourself as collaborator');
      }

      if (collaborators.containsKey(user.$1)) {
        throw Exception('Duplicate collaborator: "@$username" already added');
      }

      collaborators[user.$1] = 'collaborator';
    }

    final levelEntries = _normalizeLevelEntries(levels);

    // Create project
    final projectRef = _firestore.collection('projects').doc();

    final projectData = {
      'id': projectRef.id,
      'title': title.trim(),
      'description': description.trim(),
      'createdBy': authUser.uid,
      'collaborators': collaborators,
      'visibility': visibility,
      'isOpenForRequests': finalIsOpenForRequests,
      'requiredCollaborators': requiredCollaborators,
      'requiredSkills': requiredSkills,
      'contactEmail': contactEmail.trim(),
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
      'levels': levelEntries,
      'ideaBoardBlocks': <Map<String, dynamic>>[],
      'tasksCompleted': 0,
      'ideasAdded': 0,
      'meetingsConducted': 0,
      'messagesSent': 0,
    };

    try {
      // Create project atomically with default #general channel
      final batch = _firestore.batch();

      batch.set(projectRef, projectData);

      // Create default #general channel
      final generalChannelRef =
          projectRef.collection('channels').doc('general');
      final channelData = {
        'id': 'general',
        'projectId': projectRef.id,
        'name': 'general',
        'createdBy': authUser.uid,
        'members': <String>[],
        'isPrivate': false,
        'createdAt': Timestamp.now(),
        'lastMessageAt': null,
        'messageCount': 0,
      };
      batch.set(generalChannelRef, channelData);

      await batch.commit();
      return projectRef.id;
    } catch (e) {
      throw Exception('Failed to create project: ${e.toString()}');
    }
  }

  /// Update project visibility and settings
  Future<void> updateProject({
    required String projectId,
    String? visibility,
    bool? isOpenForRequests,
    int? requiredCollaborators,
    List<String>? requiredSkills,
    String? contactEmail,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data()!;
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can update settings');
    }

    final updateData = <String, dynamic>{
      'lastUpdated': Timestamp.now(),
    };

    if (visibility != null) updateData['visibility'] = visibility;
    if (isOpenForRequests != null)
      updateData['isOpenForRequests'] = isOpenForRequests;
    if (requiredCollaborators != null)
      updateData['requiredCollaborators'] = requiredCollaborators;
    if (requiredSkills != null) updateData['requiredSkills'] = requiredSkills;
    if (contactEmail != null) updateData['contactEmail'] = contactEmail;

    await _firestore.collection('projects').doc(projectId).update(updateData);
  }

  /// Replace all project levels atomically.
  Future<void> replaceProjectLevels({
    required String projectId,
    required List<Map<String, dynamic>> levels,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can modify levels');
    }

    await _firestore.collection('projects').doc(projectId).update({
      'levels': _normalizeLevelEntries(levels),
      'lastUpdated': Timestamp.now(),
    });
  }

  /// Add a new level to a project.
  Future<void> addProjectLevel({
    required String projectId,
    required String title,
  }) async {
    await _updateLevels(projectId, (currentLevels) {
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) {
        throw Exception('Level title cannot be empty');
      }

      if (currentLevels.any((level) =>
          (level['title'] as String? ?? '').toLowerCase() ==
          trimmedTitle.toLowerCase())) {
        throw Exception('A level with that title already exists');
      }

      currentLevels.add(_buildLevelEntry(
        title: trimmedTitle,
        order: currentLevels.length + 1,
      ));
      return currentLevels;
    });
  }

  /// Rename an existing level.
  Future<void> renameProjectLevel({
    required String projectId,
    required String levelId,
    required String title,
  }) async {
    await _updateLevels(projectId, (currentLevels) {
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) {
        throw Exception('Level title cannot be empty');
      }

      final existingIndex =
          currentLevels.indexWhere((level) => level['id'] == levelId);
      if (existingIndex == -1) {
        throw Exception('Level not found');
      }

      if (currentLevels.any((level) =>
          level['id'] != levelId &&
          (level['title'] as String? ?? '').toLowerCase() ==
              trimmedTitle.toLowerCase())) {
        throw Exception('A level with that title already exists');
      }

      currentLevels[existingIndex]['title'] = trimmedTitle;
      return currentLevels;
    });
  }

  /// Remove a level from a project and reassign order.
  Future<void> removeProjectLevel({
    required String projectId,
    required String levelId,
  }) async {
    await _updateLevels(projectId, (currentLevels) {
      currentLevels.removeWhere((level) => level['id'] == levelId);
      if (currentLevels.isEmpty) {
        throw Exception('A project must have at least one level');
      }
      return currentLevels;
    });
  }

  // ============ COLLABORATOR MANAGEMENT ============

  /// Add collaborator by username (admin only)
  /// Validates username exists and prevents duplicates
  Future<void> addCollaboratorByUsername({
    required String projectId,
    required String collaboratorUsername,
    bool makeAdmin = false,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final data = projectDoc.data()!;
    if (!_isAdminRole(data, authUser.uid)) {
      throw Exception('Only project admin can add collaborators');
    }

    // Lookup user by username
    final user = await _userService.getUserByUsername(collaboratorUsername);
    if (user == null) {
      throw Exception('User "@${collaboratorUsername}" not found');
    }

    final userId = user.$1;

    // Check if already collaborator or creator
    if (userId == authUser.uid) {
      throw Exception('Cannot add yourself as collaborator');
    }

    final collaborators = _parseCollaboratorsMap(
      data['collaborators'],
      docId: projectId,
    );

    if (collaborators.containsKey(userId)) {
      if (makeAdmin && collaborators[userId] != 'admin') {
        collaborators[userId] = 'admin';
      } else {
        throw Exception(
            'User "@${collaboratorUsername}" is already a collaborator');
      }
    } else {
      collaborators[userId] = makeAdmin ? 'admin' : 'collaborator';
    }

    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': Timestamp.now(),
    });

    await _fanOutProjectNotification(
      projectId: projectId,
      type: 'collaborator_added',
      title: 'Added to project',
      body: 'You were added to the project by the admin.',
      onlyUserIds: {userId},
      excludedUserIds: {authUser.uid},
      data: {'collaboratorId': userId},
    );
  }

  /// Remove collaborator from project (admin only)
  Future<void> removeCollaborator({
    required String projectId,
    required String userId,
    bool deleteContributions = false,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final data = projectDoc.data()!;
    if (!_isAdminRole(data, authUser.uid)) {
      throw Exception('Only project admin can remove collaborators');
    }

    // Prevent removing creator
    if (userId == authUser.uid) {
      throw Exception('Cannot remove yourself from your own project');
    }

    final collaborators = _parseCollaboratorsMap(
      data['collaborators'],
      docId: projectId,
    );

    if (!collaborators.containsKey(userId)) {
      throw Exception('User is not a collaborator on this project');
    }

    collaborators.remove(userId);

    final projectRef = _firestore.collection('projects').doc(projectId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(projectRef, {
        'collaborators': collaborators,
        'lastUpdated': Timestamp.now(),
      });
    });

    if (deleteContributions) {
      final projectSnapshot = await projectRef.get();
      final projectData = projectSnapshot.data();
      if (projectData != null) {
        final blocks = _toMapList(projectData['ideaBoardBlocks']);
        final remainingBlocks =
            blocks.where((block) => block['createdBy'] != userId).toList();
        if (remainingBlocks.length != blocks.length) {
          await projectRef.update({
            'ideaBoardBlocks': remainingBlocks,
            'lastUpdated': Timestamp.now(),
          });
        }
      }

      final messageQuery = await projectRef
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();
      for (final doc in messageQuery.docs) {
        await doc.reference.delete();
      }
    }

    await _fanOutProjectNotification(
      projectId: projectId,
      type: 'collaborator_removed',
      title: 'Removed from project',
      body: 'You were removed from the project by the admin.',
      onlyUserIds: {userId},
      excludedUserIds: {authUser.uid},
      data: {'collaboratorId': userId},
    );
  }

  /// Move a level up or down in the project order.
  Future<void> moveProjectLevel({
    required String projectId,
    required String levelId,
    required bool moveUp,
  }) async {
    await _updateLevels(projectId, (currentLevels) {
      final index = currentLevels.indexWhere((level) => level['id'] == levelId);
      if (index == -1) {
        throw Exception('Level not found');
      }

      final targetIndex = moveUp ? index - 1 : index + 1;
      if (targetIndex < 0 || targetIndex >= currentLevels.length) {
        return currentLevels;
      }

      final temp = currentLevels[index];
      currentLevels[index] = currentLevels[targetIndex];
      currentLevels[targetIndex] = temp;
      return currentLevels;
    });
  }

  // ============ JOIN REQUEST MANAGEMENT ============

  /// Submit a comprehensive join request with portfolio
  /// STEP 1: Submit request (before file uploads if needed)
  Future<String> submitJoinRequest({
    required String projectId,
    required List<String> skills,
    required String message,
    String? githubLink,
    String? linkedinLink,
    List<String> fileUrls = const [], // Pre-uploaded file URLs
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Validate project exists and is public with requests open
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    final visibility = projectData['visibility'] as String?;
    final isOpenForRequests =
        projectData['isOpenForRequests'] as bool? ?? false;

    if (visibility != 'public') {
      throw Exception('Cannot request to join private projects');
    }
    if (!isOpenForRequests) {
      throw Exception('This project is not accepting join requests');
    }

    // Check if already collaborator
    final createdBy = projectData['createdBy'] as String?;
    final collaborators = _parseCollaboratorsMap(
      projectData['collaborators'],
      docId: projectId,
    );

    if (createdBy == authUser.uid || collaborators.containsKey(authUser.uid)) {
      throw Exception('You are already a collaborator on this project');
    }

    // Check for existing pending request
    final existingRequest = await _firestore
        .collection('joinRequests')
        .where('projectId', isEqualTo: projectId)
        .where('requestedBy', isEqualTo: authUser.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception(
          'You already have a pending join request for this project');
    }

    // Get user info
    final userDoc =
        await _firestore.collection('users').doc(authUser.uid).get();
    final userEmail = authUser.email ?? 'unknown@email.com';
    final userName = userDoc.data()?['name'] as String? ?? 'Unknown User';
    final userUsername = userDoc.data()?['username'] as String? ?? 'unknown';

    // Create join request
    final requestRef = _firestore.collection('joinRequests').doc();
    final requestData = {
      'id': requestRef.id,
      'projectId': projectId,
      'requestedBy': authUser.uid,
      'requestedByEmail': userEmail,
      'requestedByName': userName,
      'requestedByUsername': userUsername,
      'skills': skills,
      'message': message.trim(),
      'githubLink': githubLink?.trim() ?? '',
      'linkedinLink': linkedinLink?.trim() ?? '',
      'fileUrls': fileUrls,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await requestRef.set(requestData);
      return requestRef.id;
    } catch (e) {
      throw Exception('Failed to submit join request: ${e.toString()}');
    }
  }

  /// Get join requests for a project (admin only)
  /// Real-time stream of all join requests for a project
  Stream<List<JoinRequest>> watchJoinRequests(String projectId) {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('joinRequests')
        .where('projectId', isEqualTo: projectId)
        .snapshots()
        .asyncMap((snapshot) async {
      // Verify user is admin
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      final projectData = projectDoc.data();

      if (projectData == null || !_isAdminRole(projectData, authUser.uid)) {
        return []; // Non-admin gets empty list
      }

      return snapshot.docs.map((doc) => _parseJoinRequest(doc)).toList();
    });
  }

  /// Get pending join requests for current user (to track own requests)
  Stream<List<JoinRequest>> watchMyJoinRequests() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('joinRequests')
        .where('requestedBy', isEqualTo: authUser.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _parseJoinRequest(doc)).toList();
    });
  }

  /// Accept a join request (admin only)
  /// Atomically adds user to collaborators and updates request status
  Future<void> acceptJoinRequest(String requestId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final requestDoc =
        await _firestore.collection('joinRequests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Join request not found');
    }

    final requestData = requestDoc.data()!;
    final projectId = requestData['projectId'] as String;
    final requestedBy = requestData['requestedBy'] as String;

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data()!;
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can accept join requests');
    }

    // Add user as collaborator and update request atomically
    final batch = _firestore.batch();

    // Update project collaborators
    final collaborators = Map<String, dynamic>.from(
      projectData['collaborators'] as Map<String, dynamic>? ?? {},
    );
    collaborators[requestedBy] = 'collaborator';

    batch.update(
      _firestore.collection('projects').doc(projectId),
      {
        'collaborators': collaborators,
        'lastUpdated': Timestamp.now(),
      },
    );

    // Update request status
    batch.update(
      _firestore.collection('joinRequests').doc(requestId),
      {
        'status': 'accepted',
        'respondedAt': DateTime.now().toIso8601String(),
      },
    );

    try {
      await batch.commit();
      await _fanOutProjectNotification(
        projectId: projectId,
        type: 'join_request_accepted',
        title: 'Join request accepted',
        body: 'Your request to join the project was accepted.',
        onlyUserIds: {requestedBy},
        excludedUserIds: {authUser.uid},
        data: {'requestId': requestId},
      );
    } catch (e) {
      throw Exception('Failed to accept join request: ${e.toString()}');
    }
  }

  /// Reject a join request (admin only)
  Future<void> rejectJoinRequest(String requestId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final requestDoc =
        await _firestore.collection('joinRequests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Join request not found');
    }

    final requestData = requestDoc.data()!;
    final projectId = requestData['projectId'] as String;

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data()!;
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can reject join requests');
    }

    try {
      await _firestore.collection('joinRequests').doc(requestId).update({
        'status': 'rejected',
        'respondedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to reject join request: ${e.toString()}');
    }
  }

  // ============ HELPER METHODS ============

  Stream<List<IdeaBoardBlock>> watchIdeaBoardBlocks({
    required String projectId,
    required String levelId,
  }) {
    return watchProject(projectId).map((project) {
      if (project == null) {
        return <IdeaBoardBlock>[];
      }

      return project.ideaBoardBlocks
          .where((block) => block.levelId == levelId)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
  }

  Future<void> addIdeaBoardBlock({
    required String projectId,
    required String levelId,
    required String type,
    required String content,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final allowedTypes = {'title', 'paragraph', 'file'};
    if (!allowedTypes.contains(type)) {
      throw Exception('Invalid block type');
    }

    final blockId = _firestore.collection('projects').doc().id;

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_canEditIdeaBoard(data, authUser.uid)) {
        throw Exception('Only collaborators can edit idea board');
      }

      final current = _toMapList(data['ideaBoardBlocks']);

      current.add({
        'id': blockId,
        'levelId': levelId,
        'type': type,
        'content': content.trim(),
        'files': <Map<String, dynamic>>[],
        'createdBy': authUser.uid,
        'createdAt': Timestamp.now(),
      });

      transaction.update(ref, {
        'ideaBoardBlocks': current,
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  Future<void> updateIdeaBoardBlock({
    required String projectId,
    required String blockId,
    String? content,
    List<Map<String, dynamic>>? files,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_canEditIdeaBoard(data, authUser.uid)) {
        throw Exception('Only collaborators can edit idea board');
      }

      final current = _toMapList(data['ideaBoardBlocks']);

      final index = current.indexWhere((item) => item['id'] == blockId);
      if (index == -1) {
        throw Exception('Block not found');
      }

      if (content != null) {
        current[index]['content'] = content.trim();
      }
      if (files != null) {
        current[index]['files'] = files;
      }

      transaction.update(ref, {
        'ideaBoardBlocks': current,
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  Future<void> removeIdeaBoardBlock({
    required String projectId,
    required String blockId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_canEditIdeaBoard(data, authUser.uid)) {
        throw Exception('Only collaborators can edit idea board');
      }

      final current = _toMapList(data['ideaBoardBlocks']);
      current.removeWhere((item) => item['id'] == blockId);

      transaction.update(ref, {
        'ideaBoardBlocks': current,
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  Future<void> moveIdeaBoardBlock({
    required String projectId,
    required String blockId,
    required bool moveUp,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_canEditIdeaBoard(data, authUser.uid)) {
        throw Exception('Only collaborators can edit idea board');
      }

      final current = _toMapList(data['ideaBoardBlocks']);
      final index = current.indexWhere((item) => item['id'] == blockId);
      if (index == -1) {
        throw Exception('Block not found');
      }

      final targetIndex = moveUp ? index - 1 : index + 1;
      if (targetIndex < 0 || targetIndex >= current.length) {
        return;
      }

      final temp = current[index];
      current[index] = current[targetIndex];
      current[targetIndex] = temp;

      transaction.update(ref, {
        'ideaBoardBlocks': current,
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  /// Parse Firestore project document to Project model
  /// Defensive parsing with null safety and logging
  Project _parseProject(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) {
        print('⚠️  Document ${doc.id} has null data');
        throw Exception('Document data is null');
      }

      _logMissingProjectFields(doc.id, data);

      // Safe parsing with defaults for all fields
      final id = doc.id;
      final title = (data['title'] as String?)?.isEmpty ?? true
          ? 'Untitled Project'
          : data['title'] as String;
      final description = data['description'] as String? ?? '';
      final createdBy = data['createdBy'] as String? ?? '';

      final collaboratorsMap = _parseCollaboratorsMap(
        data['collaborators'],
        docId: doc.id,
      );

      final visibility = data['visibility'] as String? ?? 'private';
      final isOpenForRequests = data['isOpenForRequests'] as bool? ?? false;
      final requiredCollaborators = data['requiredCollaborators'] as int? ?? 0;

      // Safe skills parsing
      final skillsData = data['requiredSkills'];
      List<String> requiredSkills = [];
      if (skillsData is List) {
        requiredSkills = skillsData.whereType<String>().toList();
      }

      final contactEmail = data['contactEmail'] as String? ?? '';
      final lastUpdated =
          _parseTimestampString(data['lastUpdated']) ?? 'Recently';
      final createdAt = _parseDateTime(data['createdAt']) ?? DateTime.now();

      // Safe levels parsing
      final levelsData = data['levels'];
      List<ProjectLevel> levels = [];
      if (levelsData is List) {
        levels = _parseProjectLevels(levelsData);
      }

      final ideaBoardBlocksData = data['ideaBoardBlocks'];
      List<IdeaBoardBlock> ideaBoardBlocks = [];
      if (ideaBoardBlocksData is List) {
        ideaBoardBlocks = _parseIdeaBoardBlocks(ideaBoardBlocksData);
      }

      // Safe stats parsing
      final tasksCompleted = data['tasksCompleted'] as int? ?? 0;
      final ideasAdded = data['ideasAdded'] as int? ?? 0;
      final meetingsConducted = data['meetingsConducted'] as int? ?? 0;
      final messagesSent = data['messagesSent'] as int? ?? 0;
      final stats = ProjectStats(
        tasksCompleted: tasksCompleted,
        ideasAdded: ideasAdded,
        meetingsConducted: meetingsConducted,
        messagesSent: messagesSent,
      );

      return Project(
        id: id,
        title: title,
        description: description,
        createdBy: createdBy,
        collaborators: collaboratorsMap,
        visibility: visibility,
        isOpenForRequests: isOpenForRequests,
        requiredCollaborators: requiredCollaborators,
        requiredSkills: requiredSkills,
        contactEmail: contactEmail,
        lastUpdated: lastUpdated,
        createdAt: createdAt,
        levels: levels,
        ideaBoardBlocks: ideaBoardBlocks,
        stats: stats,
      );
    } catch (e) {
      print('❌ Error parsing project ${doc.id}: $e');
      // Return a minimal valid project instead of crashing
      return Project(
        id: doc.id,
        title: 'Project (with errors)',
        description: 'Could not fully load this project',
        createdBy: '',
        collaborators: {},
        visibility: 'private',
        isOpenForRequests: false,
        requiredCollaborators: 0,
        requiredSkills: [],
        contactEmail: '',
        lastUpdated: 'Recently',
        createdAt: DateTime.now(),
        levels: [],
        ideaBoardBlocks: const [],
        stats: const ProjectStats(
          tasksCompleted: 0,
          ideasAdded: 0,
          meetingsConducted: 0,
          messagesSent: 0,
        ),
      );
    }
  }

  void _logMissingProjectFields(String docId, Map<String, dynamic> data) {
    const expectedFields = [
      'title',
      'description',
      'createdBy',
      'collaborators',
      'visibility',
      'isOpenForRequests',
      'requiredCollaborators',
      'requiredSkills',
      'contactEmail',
      'lastUpdated',
      'createdAt',
      'levels',
      'ideaBoardBlocks',
      'tasksCompleted',
      'ideasAdded',
      'meetingsConducted',
      'messagesSent',
    ];

    for (final field in expectedFields) {
      if (!data.containsKey(field) || data[field] == null) {
        print('⚠️ Project $docId missing $field field');
      }
    }
  }

  Map<String, String> _parseCollaboratorsMap(
    dynamic collaboratorsData, {
    required String docId,
  }) {
    final collaborators = <String, String>{};

    if (collaboratorsData == null) {
      print('⚠️ Project $docId missing collaborators field');
      return collaborators;
    }

    if (collaboratorsData is Map) {
      collaboratorsData.forEach((key, value) {
        if (key is String) {
          collaborators[key] = value is String ? value : 'collaborator';
        }
      });
      return collaborators;
    }

    if (collaboratorsData is List) {
      print('⚠️ Project $docId has legacy collaborators list');
      for (final value in collaboratorsData) {
        if (value is String && value.trim().isNotEmpty) {
          collaborators[value] = 'collaborator';
        }
      }
      return collaborators;
    }

    print(
      '⚠️ Project $docId has invalid collaborators type: '
      '${collaboratorsData.runtimeType}',
    );
    return collaborators;
  }

  /// Parse Firestore join request document to JoinRequest model
  JoinRequest _parseJoinRequest(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return JoinRequest(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      requestedBy: data['requestedBy'] as String? ?? '',
      requestedByEmail: data['requestedByEmail'] as String? ?? '',
      requestedByName: data['requestedByName'] as String? ?? '',
      requestedByUsername: data['requestedByUsername'] as String? ?? '',
      skills: List<String>.from(data['skills'] as List? ?? []),
      message: data['message'] as String? ?? '',
      githubLink: data['githubLink'] as String?,
      linkedinLink: data['linkedinLink'] as String?,
      fileUrls: List<String>.from(data['fileUrls'] as List? ?? []),
      status: data['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      respondedAt: data['respondedAt'] != null
          ? DateTime.tryParse(data['respondedAt'] as String? ?? '')
          : null,
    );
  }

  /// Helper method to parse project levels from Firestore data
  List<ProjectLevel> _parseProjectLevels(List<dynamic> levelsList) {
    final parsedLevels = levelsList.map((level) {
      final levelData = level as Map<String, dynamic>? ?? {};
      return ProjectLevel(
        id: levelData['id'] as String? ??
            _firestore.collection('projects').doc().id,
        title:
            levelData['title'] as String? ?? levelData['name'] as String? ?? '',
        order: levelData['order'] as int? ?? 0,
        createdAt: _parseDateTime(levelData['createdAt']) ?? DateTime.now(),
        completed: levelData['completed'] as bool? ?? false,
        percentage: levelData['percentage'] as int? ?? 0,
        updatedBy: levelData['updatedBy'] as String? ?? '',
        updatedAt: _parseDateTime(levelData['updatedAt']),
      );
    }).toList();

    parsedLevels.sort((a, b) => a.order.compareTo(b.order));
    return parsedLevels;
  }

  List<IdeaBoardBlock> _parseIdeaBoardBlocks(List<dynamic> blocksList) {
    final parsed = <IdeaBoardBlock>[];

    for (final item in blocksList) {
      if (item is! Map) {
        continue;
      }
      final blockMap = Map<String, dynamic>.from(item);

      final filesRaw = blockMap['files'];
      final files = <IdeaBoardFile>[];
      if (filesRaw is List) {
        for (final file in filesRaw) {
          if (file is! Map) continue;
          final fileMap = Map<String, dynamic>.from(file);
          final normalized = Map<String, dynamic>.from(fileMap)
            ..putIfAbsent(
                'id', () => _firestore.collection('projects').doc().id);
          files.add(IdeaBoardFile.fromMap(normalized));
        }
      }

      parsed.add(
        IdeaBoardBlock(
          id: blockMap['id'] as String? ??
              _firestore.collection('projects').doc().id,
          levelId: blockMap['levelId'] as String? ?? '',
          type: blockMap['type'] as String? ?? 'paragraph',
          content: blockMap['content'] as String? ?? '',
          files: files,
          createdBy: blockMap['createdBy'] as String? ?? '',
          createdAt: _parseDateTime(blockMap['createdAt']) ?? DateTime.now(),
        ),
      );
    }

    parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return parsed;
  }

  List<Map<String, dynamic>> _toMapList(dynamic rawList) {
    if (rawList is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _buildLevelEntry({
    required String title,
    required int order,
  }) {
    return {
      'id': _firestore.collection('projects').doc().id,
      'title': title,
      'order': order,
      'createdAt': Timestamp.now(),
      'completed': false,
      'percentage': 0,
      'updatedBy': '',
      'updatedAt': null,
    };
  }

  List<Map<String, dynamic>> _normalizeLevelEntries(
      List<Map<String, dynamic>>? levels) {
    final entries = (levels == null || levels.isEmpty)
        ? _defaultLevelTitles
            .asMap()
            .entries
            .map((entry) =>
                _buildLevelEntry(title: entry.value, order: entry.key + 1))
            .toList()
        : levels
            .map((level) => {
                  'id': (level['id'] as String?) ??
                      _firestore.collection('projects').doc().id,
                  'title':
                      (level['title'] as String?)?.trim().isNotEmpty == true
                          ? (level['title'] as String).trim()
                          : 'Untitled Level',
                  'order': level['order'] as int? ?? 0,
                  'createdAt': level['createdAt'] ?? Timestamp.now(),
                  'completed': level['completed'] as bool? ?? false,
                  'percentage': level['percentage'] as int? ?? 0,
                  'updatedBy': level['updatedBy'] as String? ?? '',
                  'updatedAt': level['updatedAt'] ?? null,
                })
            .toList();

    final sorted = [...entries]..sort((a, b) {
        final leftOrder = a['order'] as int? ?? 0;
        final rightOrder = b['order'] as int? ?? 0;
        return leftOrder.compareTo(rightOrder);
      });

    for (var index = 0; index < sorted.length; index++) {
      sorted[index]['order'] = index + 1;
      sorted[index]['createdAt'] ??= Timestamp.now();
    }

    return sorted;
  }

  Future<void> _updateLevels(
    String projectId,
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> levels)
        updater,
  ) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_isAdminRole(data, authUser.uid)) {
        throw Exception('Only project admin can modify levels');
      }

      final currentLevels = _normalizeLevelEntries(
        (data['levels'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .toList(),
      );

      final updatedLevels = updater([...currentLevels]);
      if (updatedLevels.isEmpty) {
        throw Exception('A project must have at least one level');
      }

      final reordered = _reorderLevels(updatedLevels);
      transaction.update(ref, {
        'levels': reordered,
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  List<Map<String, dynamic>> _reorderLevels(List<Map<String, dynamic>> levels) {
    final ordered = [...levels]..sort((a, b) {
        final leftOrder = a['order'] as int? ?? 0;
        final rightOrder = b['order'] as int? ?? 0;
        return leftOrder.compareTo(rightOrder);
      });

    for (var index = 0; index < ordered.length; index++) {
      ordered[index]['order'] = index + 1;
      ordered[index]['createdAt'] ??= Timestamp.now();
    }

    return ordered;
  }

  Future<void> _ensureDefaultLevelsIfMissing(String projectId) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data()!;
      final existingLevels = data['levels'] as List<dynamic>? ?? [];
      if (existingLevels.isNotEmpty) {
        return;
      }

      transaction.update(ref, {
        'levels': _normalizeLevelEntries(null),
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  Future<void> updateProjectLevelProgress({
    required String projectId,
    required String levelId,
    required int percentage,
    required bool completed,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    if (percentage < 0 || percentage > 100) {
      throw Exception('Percentage must be between 0 and 100');
    }

    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('projects').doc(projectId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Project not found');
      }

      final data = snapshot.data()!;
      if (!_isAdminRole(data, authUser.uid)) {
        throw Exception('Only project admin can update tracker progress');
      }

      final levels = _normalizeLevelEntries(
        (data['levels'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );

      final index = levels.indexWhere((entry) => entry['id'] == levelId);
      if (index == -1) {
        throw Exception('Level not found');
      }

      levels[index]['completed'] = completed;
      levels[index]['percentage'] = percentage;
      levels[index]['updatedBy'] = authUser.uid;
      levels[index]['updatedAt'] = Timestamp.now();

      transaction.update(ref, {
        'levels': _reorderLevels(levels),
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  Stream<int> watchProjectUnreadCount(String projectId) {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value(0);
      }

      return _firestore
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(authUser.uid)
          .snapshots()
          .asyncExpand((memberDoc) {
        final lastReadAt = _parseDateTime(memberDoc.data()?['lastReadAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return _firestore
            .collection('projects')
            .doc(projectId)
            .collection('messages')
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final createdAt = _parseDateTime(data['createdAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return createdAt.isAfter(lastReadAt) &&
                data['senderId'] != authUser.uid;
          }).length;
        });
      });
    });
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _parseTimestampString(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  // ============ DEBUG HELPERS ============

  /// Debug helper to diagnose project retrieval issues
  /// Returns detailed information about projects in database
  Future<Map<String, dynamic>> debugProjectRetrieval() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return {'error': 'Not logged in', 'uid': null};
    }

    try {
      // Check created projects
      final createdDocs = await _firestore
          .collection('projects')
          .where('createdBy', isEqualTo: authUser.uid)
          .get();

      // Check all projects
      final allDocs = await _firestore.collection('projects').get();

      // Check where user is collaborator
      int collaboratingCount = 0;
      final collaboratingProjects = <Map<String, dynamic>>[];

      for (final doc in allDocs.docs) {
        final data = doc.data();
        final createdBy = data['createdBy'] as String? ?? '';
        final collaborators =
            data['collaborators'] as Map<String, dynamic>? ?? {};

        if (collaborators.containsKey(authUser.uid)) {
          collaboratingCount++;
          collaboratingProjects.add({
            'id': doc.id,
            'title': data['title'],
            'createdBy': createdBy,
          });
        }
      }

      return {
        'logged_in': true,
        'uid': authUser.uid,
        'created_projects': createdDocs.docs.length,
        'created_list': createdDocs.docs
            .map((d) => {'id': d.id, 'title': d['title']})
            .toList(),
        'total_projects_in_db': allDocs.docs.length,
        'collaborating_projects': collaboratingCount,
        'collaborating_list': collaboratingProjects,
        'total_accessible': createdDocs.docs.length + collaboratingCount,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'uid': authUser.uid,
      };
    }
  }

  // ============ CHANNEL SYSTEM (Discord-style) ============

  /// Watch all channels in a project
  Stream<List<ProjectChannel>> watchProjectChannels(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) => _parseProjectChannel(doc)).toList();
      } catch (e) {
        print('❌ Error parsing channels: $e');
        return [];
      }
    });
  }

  /// Create a new channel in a project
  Future<String> createChannel({
    required String projectId,
    required String name,
    bool isPrivate = false,
    List<String> invitedMembers = const [],
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is collaborator
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    if (!_canEditIdeaBoard(projectData, authUser.uid)) {
      throw Exception('You do not have access to this project');
    }

    // Validate channel name
    final trimmedName =
        name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-_]'), '-');
    if (trimmedName.isEmpty) {
      throw Exception('Channel name cannot be empty');
    }

    // Check for duplicate channel name
    final existing = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .where('name', isEqualTo: trimmedName)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Channel "$trimmedName" already exists');
    }

    final channelRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc();

    final channelData = {
      'id': channelRef.id,
      'projectId': projectId,
      'name': trimmedName,
      'createdBy': authUser.uid,
      'members': isPrivate ? invitedMembers : <String>[],
      'isPrivate': isPrivate,
      'createdAt': Timestamp.now(),
      'lastMessageAt': null,
      'messageCount': 0,
    };

    try {
      await channelRef.set(channelData);
      return channelRef.id;
    } catch (e) {
      throw Exception('Failed to create channel: ${e.toString()}');
    }
  }

  /// Delete a channel (admin or creator only)
  Future<void> deleteChannel({
    required String projectId,
    required String channelId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Cannot delete #general channel
    if (channelId == 'general') {
      throw Exception('Cannot delete the #general channel');
    }

    // Verify user is admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data() ?? <String, dynamic>{};
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can delete channels');
    }

    // Delete all messages in channel, then the channel itself
    final batch = _firestore.batch();
    final messagesDocs = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .get();

    for (final msg in messagesDocs.docs) {
      batch.delete(msg.reference);
    }

    batch.delete(_firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId));

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete channel: ${e.toString()}');
    }
  }

  /// Add a member to a private channel
  Future<void> addChannelMember({
    required String projectId,
    required String channelId,
    required String memberUsername,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is channel creator or admin
    final channelDoc = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .get();

    if (!channelDoc.exists) {
      throw Exception('Channel not found');
    }

    final channelData = channelDoc.data()!;
    final createdBy = channelData['createdBy'] as String?;

    if (createdBy != authUser.uid) {
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      final projectData = projectDoc.data() ?? <String, dynamic>{};
      if (!_isAdminRole(projectData, authUser.uid)) {
        throw Exception(
            'Only channel creator or project admin can add members');
      }
    }

    // Lookup member by username
    final member = await _userService.getUserByUsername(memberUsername);
    if (member == null) {
      throw Exception('User "@$memberUsername" not found');
    }

    final members = List<String>.from(
        (channelData['members'] as List? ?? []).cast<String>());
    if (members.contains(member.$1)) {
      throw Exception('User is already a member of this channel');
    }

    members.add(member.$1);
    await channelDoc.reference.update({'members': members});
  }

  /// Rename a channel (creator or admin only)
  Future<void> renameChannel({
    required String projectId,
    required String channelId,
    required String newName,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) throw Exception('User must be logged in');

    final channelRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId);

    final channelDoc = await channelRef.get();
    if (!channelDoc.exists) throw Exception('Channel not found');

    final channelData = channelDoc.data()!;
    final createdBy = channelData['createdBy'] as String?;

    // Only creator or project admin can rename
    if (createdBy != authUser.uid) {
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      final projectData = projectDoc.data() ?? <String, dynamic>{};
      if (!_isAdminRole(projectData, authUser.uid)) {
        throw Exception(
            'Only channel creator or project admin can rename this channel');
      }
    }

    final trimmed =
        newName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-_]'), '-');
    if (trimmed.isEmpty) throw Exception('Channel name cannot be empty');

    await channelRef.update({'name': trimmed});
  }

  /// Leave a private channel (removes current user from members). For public channels this is a no-op.
  Future<void> leaveChannel({
    required String projectId,
    required String channelId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) throw Exception('User must be logged in');

    final channelRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId);

    final channelDoc = await channelRef.get();
    if (!channelDoc.exists) throw Exception('Channel not found');

    final channelData = channelDoc.data()!;
    final isPrivate = channelData['isPrivate'] as bool? ?? false;
    if (!isPrivate) return; // nothing to do for public channels

    final members = List<String>.from(
        (channelData['members'] as List? ?? []).cast<String>());
    members.remove(authUser.uid);
    await channelRef.update({'members': members});
  }

  /// Watch messages in a specific channel (paginated)
  Stream<List<ProjectChatMessage>> watchChannelMessages(
    String projectId,
    String channelId, {
    int limit = 30,
  }) {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => _parseProjectChatMessage(doc))
              .toList()
              .reversed
              .toList();
        } catch (e) {
          print('❌ Error parsing channel messages: $e');
          return [];
        }
      });
    });
  }

  /// Load older messages in a channel for pagination
  Future<List<ProjectChatMessage>> loadOlderChannelMessages(
    String projectId,
    String channelId, {
    required DateTime before,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .where('createdAt', isLessThan: before)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => _parseProjectChatMessage(doc))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('❌ Error loading older channel messages: $e');
      return [];
    }
  }

  // ============ CHAT SYSTEM ============

  /// Watch all messages in a project, ordered newest first with pagination support
  Stream<List<ProjectChatMessage>> watchProjectMessages(
    String projectId, {
    int limit = 30,
  }) {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }
    // DEPRECATED: Project-wide message listeners have been removed in favor of
    // channel-scoped listeners. Use `watchChannelMessages(projectId, channelId)`.
    print(
        '⚠️ watchProjectMessages is deprecated. Use watchChannelMessages instead.');
    return Stream.value([]);
  }

  /// Load older messages for pagination
  Future<List<ProjectChatMessage>> loadOlderProjectMessages(
    String projectId, {
    required DateTime before,
    int limit = 30,
  }) async {
    // DEPRECATED: Use `loadOlderChannelMessages(projectId, channelId, before)`
    print(
        '⚠️ loadOlderProjectMessages is deprecated. Use loadOlderChannelMessages instead.');
    return [];
  }

  /// Send a message in a specific project channel
  Future<void> sendChannelMessage({
    required String projectId,
    required String channelId,
    required String text,
    String replyToMessageId = '',
    List<Map<String, dynamic>> attachments = const [],
    String? messageId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user has access to project
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    if (!_canEditIdeaBoard(projectData, authUser.uid)) {
      throw Exception('You do not have access to this project');
    }

    // Verify channel exists and user has access
    final channelDoc = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .get();

    if (!channelDoc.exists) {
      throw Exception('Channel not found');
    }

    final channelData = channelDoc.data()!;
    final isPrivate = channelData['isPrivate'] as bool? ?? false;
    final members = List<String>.from(
        (channelData['members'] as List? ?? []).cast<String>());

    // Check private channel access
    if (isPrivate && !members.contains(authUser.uid)) {
      throw Exception('You do not have access to this channel');
    }

    final userDoc =
        await _firestore.collection('users').doc(authUser.uid).get();
    final userUsername = userDoc.data()?['username'] as String? ?? 'Unknown';
    final userPhoto = userDoc.data()?['photoUrl'] as String? ?? '';

    final messageRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final messageData = {
      'id': messageRef.id,
      'projectId': projectId,
      'channelId': channelId,
      'senderId': authUser.uid,
      'senderUsername': userUsername,
      'senderPhoto': userPhoto,
      'text': text.trim(),
      'replyToMessageId': replyToMessageId,
      'edited': false,
      'deleted': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'reactions': <String, List<String>>{},
      'attachments': attachments,
    };

    try {
      await messageRef.set(messageData);

      // Update channel's lastMessageAt and messageCount
      await channelDoc.reference.update({
        'lastMessageAt': Timestamp.now(),
        'messageCount': FieldValue.increment(1),
      });

      // Fan out notification to channel members
      final projectTitle = projectData['title'] as String? ?? 'Project';
      final messagePreview =
          text.substring(0, (text.length > 50 ? 50 : text.length));

      // For private channels, send only to members; for public channels, broadcast to all
      if (isPrivate && members.isNotEmpty) {
        await _fanOutProjectNotification(
          projectId: projectId,
          type: 'new_message',
          title: 'New message in $projectTitle',
          body: '$userUsername: $messagePreview...',
          onlyUserIds: members.toSet(),
          excludedUserIds: {authUser.uid},
          data: {'messageId': messageRef.id, 'channelId': channelId},
        );
      } else {
        // Public channel - broadcast to all collaborators
        await _fanOutProjectNotification(
          projectId: projectId,
          type: 'new_message',
          title: 'New message in $projectTitle',
          body: '$userUsername: $messagePreview...',
          excludedUserIds: {authUser.uid},
          data: {'messageId': messageRef.id, 'channelId': channelId},
        );
      }
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  /// Send a message in project chat (DEPRECATED: use sendChannelMessage with channelId='general')
  /// This method now writes to the #general channel for backward compatibility
  Future<void> sendProjectMessage({
    required String projectId,
    required String text,
    String replyToMessageId = '',
    List<Map<String, dynamic>> attachments = const [],
    String? messageId,
  }) async {
    // Delegate to channel-aware method with default #general channel
    await sendChannelMessage(
      projectId: projectId,
      channelId: 'general',
      text: text,
      replyToMessageId: replyToMessageId,
      attachments: attachments,
      messageId: messageId,
    );
  }

  /// Edit a message in a channel (sender or admin only)
  Future<void> editChannelMessage({
    required String projectId,
    required String channelId,
    required String messageId,
    required String newText,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final messageRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) {
      throw Exception('Message not found');
    }

    final messageData = messageDoc.data()!;
    final senderId = messageData['senderId'] as String?;

    // Verify sender or admin
    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data() ?? <String, dynamic>{};

    if (senderId != authUser.uid && !_isAdminRole(projectData, authUser.uid)) {
      throw Exception('You can only edit your own messages');
    }

    try {
      await messageRef.update({
        'text': newText.trim(),
        'edited': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to edit message: ${e.toString()}');
    }
  }

  /// Edit a message (sender or admin only) - DEPRECATED: use editChannelMessage
  Future<void> editProjectMessage({
    required String projectId,
    required String messageId,
    required String newText,
  }) async {
    // Try both old and new storage locations for backward compatibility
    final oldMessageRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .doc(messageId);

    final oldDoc = await oldMessageRef.get();
    if (oldDoc.exists) {
      // Old location - still support it for now
      final data = oldDoc.data()!;
      final senderId = data['senderId'] as String?;
      final authUser = _auth.currentUser;

      if (authUser == null) {
        throw Exception('User must be logged in');
      }

      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      final projectData = projectDoc.data() ?? <String, dynamic>{};

      if (senderId != authUser.uid &&
          !_isAdminRole(projectData, authUser.uid)) {
        throw Exception('You can only edit your own messages');
      }

      try {
        await oldMessageRef.update({
          'text': newText.trim(),
          'edited': true,
          'updatedAt': Timestamp.now(),
        });
      } catch (e) {
        throw Exception('Failed to edit message: ${e.toString()}');
      }
      return;
    }

    // New location - delegate to channel-aware method
    await editChannelMessage(
      projectId: projectId,
      channelId: 'general',
      messageId: messageId,
      newText: newText,
    );
  }

  /// Delete a message (sender or admin only)
  /// Delete a message in a channel (sender or admin only)
  Future<void> deleteChannelMessage({
    required String projectId,
    required String channelId,
    required String messageId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final messageRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('messages')
        .doc(messageId);

    final messageDoc = await messageRef.get();
    if (!messageDoc.exists) {
      throw Exception('Message not found');
    }

    final messageData = messageDoc.data()!;
    final senderId = messageData['senderId'] as String?;
    final attachments = List<Map<String, dynamic>>.from(
      (messageData['attachments'] as List? ?? []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data() ?? <String, dynamic>{};

    if (senderId != authUser.uid && !_isAdminRole(projectData, authUser.uid)) {
      throw Exception('You can only delete your own messages');
    }

    try {
      // Delete associated files from storage
      for (final attachment in attachments) {
        final storagePath = attachment['storagePath'] as String? ?? '';
        if (storagePath.isNotEmpty) {
          await FileService.instance.deleteProjectChatAttachment(storagePath);
        }
      }

      // Soft-delete the message (mark as deleted)
      await messageRef.update({
        'deleted': true,
        'text': '[This message was deleted]',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  /// Delete a message (sender or admin only) - DEPRECATED: use deleteChannelMessage
  Future<void> deleteProjectMessage({
    required String projectId,
    required String messageId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Try both old and new storage locations for backward compatibility
    final oldMessageRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .doc(messageId);

    final oldDoc = await oldMessageRef.get();
    if (oldDoc.exists) {
      // Old location - still support it
      final data = oldDoc.data()!;
      final senderId = data['senderId'] as String?;
      final attachments = List<Map<String, dynamic>>.from(
        (data['attachments'] as List? ?? []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      final projectData = projectDoc.data() ?? <String, dynamic>{};

      if (senderId != authUser.uid &&
          !_isAdminRole(projectData, authUser.uid)) {
        throw Exception('You can only delete your own messages');
      }

      for (final attachment in attachments) {
        final storagePath = attachment['storagePath'] as String? ?? '';
        if (storagePath.isNotEmpty) {
          await FileService.instance.deleteProjectChatAttachment(storagePath);
        }
      }

      await oldMessageRef.update({
        'deleted': true,
        'text': '[This message was deleted]',
        'updatedAt': Timestamp.now(),
      });
      return;
    }

    // New location - delegate to channel-aware method
    await deleteChannelMessage(
      projectId: projectId,
      channelId: 'general',
      messageId: messageId,
    );
  }

  /// Clear all chat history for a project (admin only)
  Future<void> clearProjectChat(String projectId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data() ?? <String, dynamic>{};

    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can clear chat');
    }

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('messages')
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Mark project chat as read (sets last-read timestamp)
  Future<void> markProjectChatRead({required String projectId}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(authUser.uid)
          .set(
        {
          'lastReadAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      print('⚠️  Error marking chat read: $e');
    }
  }

  // ============ UNREAD / PRESENCE HELPERS ============

  /// Mark a channel as read for the current user. Stores per-channel lastReadAt
  /// under `projects/{projectId}/channels/{channelId}/members/{userId}`.
  Future<void> markChannelRead(
      {required String projectId, required String channelId}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) return;

    final memberRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('channels')
        .doc(channelId)
        .collection('members')
        .doc(authUser.uid);

    try {
      await memberRef.set({
        'userId': authUser.uid,
        'lastReadAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Error marking channel read: $e');
    }
  }

  /// Get unread count for a channel for a specific user. This is a simple
  /// server query: count messages newer than the user's lastReadAt.
  Future<int> getChannelUnreadCount(
      {required String projectId,
      required String channelId,
      required String userId}) async {
    try {
      final memberDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('members')
          .doc(userId)
          .get();

      final lastReadAt = _parseDateTime(memberDoc.data()?['lastReadAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('channels')
          .doc(channelId)
          .collection('messages')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastReadAt))
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('⚠️ Error getting unread count: $e');
      return 0;
    }
  }

  /// Persist the user's active channel selection under `projects/{projectId}/members/{userId}.lastSelectedChannel`
  Future<void> setUserActiveChannel(
      {required String projectId, required String channelId}) async {
    final authUser = _auth.currentUser;
    if (authUser == null) return;

    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(authUser.uid)
          .set({'lastSelectedChannel': channelId}, SetOptions(merge: true));
    } catch (e) {
      print('⚠️ Error setting active channel: $e');
    }
  }

  /// Read the user's last selected channel if present
  Future<String?> getUserActiveChannel(
      {required String projectId, required String userId}) async {
    try {
      final doc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(userId)
          .get();
      final val = doc.data()?['lastSelectedChannel'] as String?;
      return val;
    } catch (e) {
      print('⚠️ Error getting active channel: $e');
      return null;
    }
  }

  // ============ CALL SYSTEM ============

  Stream<ProjectCallSession?> watchActiveProjectCall(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      try {
        if (snapshot.docs.isEmpty) {
          return null;
        }
        return _parseProjectCallSession(snapshot.docs.first);
      } catch (e) {
        print('❌ Error parsing active call: $e');
        return null;
      }
    });
  }

  Stream<List<ProjectCallSession>> watchProjectCallHistory(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => _parseProjectCallSession(doc))
            .toList();
      } catch (e) {
        print('❌ Error parsing call history: $e');
        return [];
      }
    });
  }

  Future<String> startProjectCall({
    required String projectId,
    required String type,
    List<String> invitedParticipants = const [],
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;

    if (!_canEditIdeaBoard(projectData, authUser.uid)) {
      throw Exception('You do not have access to this project');
    }

    final callRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .doc();
    final roomName =
        'teamsync-${projectId.toLowerCase()}-${callRef.id.toLowerCase()}';
    final roomUrl = 'https://meet.jit.si/$roomName';

    final callData = {
      'id': callRef.id,
      'projectId': projectId,
      'startedBy': authUser.uid,
      'participants': [authUser.uid],
      'active': true,
      'type': type,
      'invitedParticipants': invitedParticipants,
      'roomName': roomName,
      'roomUrl': roomUrl,
      'startedAt': Timestamp.now(),
      'endedAt': null,
      'audioEnabled': true,
      'videoEnabled': true,
      'screenSharing': false,
    };

    try {
      await callRef.set(callData);

      final collaborators = _parseCollaboratorsMap(
        projectData['collaborators'],
        docId: projectId,
      );
      final createdBy = projectData['createdBy'] as String? ?? '';
      final teamMembers = <String>{
        createdBy,
        ...collaborators.keys,
      };

      await _fanOutProjectNotification(
        projectId: projectId,
        type: 'call_started',
        title: 'Call started in ${projectData['title']}',
        body: 'Join the call now',
        onlyUserIds: invitedParticipants.isNotEmpty
            ? invitedParticipants.toSet()
            : teamMembers,
        excludedUserIds: {authUser.uid},
        data: {'callId': callRef.id},
      );

      return callRef.id;
    } catch (e) {
      throw Exception('Failed to start call: ${e.toString()}');
    }
  }

  Future<String> scheduleProjectCall({
    required String projectId,
    required String title,
    required String agenda,
    required String description,
    required DateTime scheduledAt,
    required int durationMinutes,
    required List<String> invitedParticipants,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final projectDoc =
        await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    if (!_isAdminRole(projectData, authUser.uid)) {
      throw Exception('Only project admin can schedule calls');
    }

    final scheduleRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSchedules')
        .doc();

    final reminderAt = scheduledAt.subtract(const Duration(minutes: 15));
    final scheduleData = {
      'id': scheduleRef.id,
      'projectId': projectId,
      'title': title.trim(),
      'agenda': agenda.trim(),
      'description': description.trim(),
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'durationMinutes': durationMinutes,
      'invitedParticipants': invitedParticipants,
      'createdBy': authUser.uid,
      'createdAt': Timestamp.now(),
      'reminderAt': Timestamp.fromDate(reminderAt),
      'status': 'scheduled',
    };

    try {
      await scheduleRef.set(scheduleData);

      final collaborators = _parseCollaboratorsMap(
        projectData['collaborators'],
        docId: projectId,
      );
      final createdBy = projectData['createdBy'] as String? ?? '';
      final teamMembers = <String>{createdBy, ...collaborators.keys};
      final targets = invitedParticipants.isNotEmpty
          ? invitedParticipants.toSet()
          : teamMembers;

      final projectTitle = projectData['title'] as String? ?? 'Project';
      await _fanOutProjectNotification(
        projectId: projectId,
        type: 'call_scheduled',
        title: 'Call scheduled in $projectTitle',
        body: '$title at ${scheduledAt.toLocal()}',
        onlyUserIds: targets,
        excludedUserIds: {authUser.uid},
        data: {'scheduleId': scheduleRef.id},
        deliverAt: DateTime.now(),
      );

      if (reminderAt.isAfter(DateTime.now())) {
        await _fanOutProjectNotification(
          projectId: projectId,
          type: 'call_reminder',
          title: 'Scheduled call reminder',
          body: '$title starts in 15 minutes',
          onlyUserIds: targets,
          excludedUserIds: {authUser.uid},
          data: {'scheduleId': scheduleRef.id},
          deliverAt: reminderAt,
        );
      }

      return scheduleRef.id;
    } catch (e) {
      throw Exception('Failed to schedule call: ${e.toString()}');
    }
  }

  Future<void> joinProjectCall({
    required String projectId,
    required String callId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final callRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .doc(callId);

    final callDoc = await callRef.get();
    if (!callDoc.exists) {
      throw Exception('Call not found');
    }

    final participants = List<String>.from(
      (callDoc.data()?['participants'] as List? ?? []).cast<String>(),
    );

    if (!participants.contains(authUser.uid)) {
      participants.add(authUser.uid);
      await callRef.update({'participants': participants});
    }
  }

  Future<void> leaveProjectCall({
    required String projectId,
    required String callId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final callRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .doc(callId);

    final callDoc = await callRef.get();
    if (!callDoc.exists) {
      return;
    }

    final participants = List<String>.from(
      (callDoc.data()?['participants'] as List? ?? []).cast<String>(),
    );

    participants.remove(authUser.uid);
    await callRef.update({'participants': participants});
  }

  Future<void> endProjectCall({
    required String projectId,
    required String callId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final callRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .doc(callId);

    final callDoc = await callRef.get();
    if (!callDoc.exists) {
      throw Exception('Call not found');
    }

    final startedBy = callDoc.data()?['startedBy'] as String?;
    if (startedBy != authUser.uid) {
      throw Exception('Only the call host can end the call');
    }

    await callRef.update({
      'active': false,
      'endedAt': Timestamp.now(),
      'participants': [],
    });
  }

  Future<void> updateCallState({
    required String projectId,
    required String callId,
    bool? audioEnabled,
    bool? videoEnabled,
    bool? screenSharing,
  }) async {
    final updateData = <String, dynamic>{};
    if (audioEnabled != null) updateData['audioEnabled'] = audioEnabled;
    if (videoEnabled != null) updateData['videoEnabled'] = videoEnabled;
    if (screenSharing != null) updateData['screenSharing'] = screenSharing;

    if (updateData.isEmpty) return;

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSessions')
        .doc(callId)
        .update(updateData);
  }

  // ============ NOTIFICATION SYSTEM ============

  Stream<List<ProjectNotificationItem>> watchMyNotifications() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(authUser.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => _parseNotificationItem(doc))
            .where((item) =>
                item.deliverAt == null ||
                !item.deliverAt!.isAfter(DateTime.now()))
            .toList();
      } catch (e) {
        print('❌ Error parsing notifications: $e');
        return [];
      }
    });
  }

  Future<void> markNotificationRead(String notificationId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(authUser.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('⚠️  Error marking notification read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(authUser.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error marking all notifications read: $e');
    }
  }

  Stream<int> watchUnreadNotificationCount() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value(0);
    }

    return watchMyNotifications().map((notifications) {
      return notifications.where((notification) => !notification.read).length;
    });
  }

  Stream<List<ProjectCallSchedule>> watchProjectCallSchedules(
      String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('callSchedules')
        .orderBy('scheduledAt', descending: true)
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => _parseProjectCallSchedule(doc))
            .toList();
      } catch (e) {
        print('❌ Error parsing call schedules: $e');
        return [];
      }
    });
  }

  Future<void> _fanOutProjectNotification({
    required String projectId,
    required String type,
    required String title,
    required String body,
    DateTime? deliverAt,
    Set<String> onlyUserIds = const <String>{},
    Set<String> excludedUserIds = const <String>{},
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    try {
      final projectDoc =
          await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return;

      final projectData = projectDoc.data()!;
      final createdBy = projectData['createdBy'] as String? ?? '';
      final collaborators = _parseCollaboratorsMap(
        projectData['collaborators'],
        docId: projectId,
      );

      final recipients = <String>{
        createdBy,
        ...collaborators.keys,
      };

      if (onlyUserIds.isNotEmpty) {
        final filtered = recipients.intersection(onlyUserIds);
        recipients.clear();
        recipients.addAll(filtered);
      }

      recipients.removeAll(excludedUserIds);

      final batch = _firestore.batch();
      for (final userId in recipients) {
        final notificationRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();

        batch.set(notificationRef, {
          'id': notificationRef.id,
          'userId': userId,
          'projectId': projectId,
          'type': type,
          'title': title,
          'body': body,
          'read': false,
          'createdAt': Timestamp.now(),
          'deliverAt': deliverAt != null ? Timestamp.fromDate(deliverAt) : null,
          'data': data,
        });
      }

      await batch.commit();
    } catch (e) {
      print('⚠️  Error fanning out notifications: $e');
    }
  }

  // ============ PARSER METHODS ============

  ProjectChatMessage _parseProjectChatMessage(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProjectChatMessage(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      channelId: data['channelId'] as String? ??
          'general', // Default to 'general' for backward compatibility
      senderId: data['senderId'] as String? ?? '',
      senderUsername: data['senderUsername'] as String? ?? 'Unknown',
      senderPhoto: data['senderPhoto'] as String? ?? '',
      text: data['text'] as String? ?? '',
      replyToMessageId: data['replyToMessageId'] as String? ?? '',
      edited: data['edited'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(data['updatedAt']) ?? DateTime.now(),
      reactions: Map<String, List<String>>.from(
        (data['reactions'] as Map? ?? {}).map((key, value) => MapEntry(
              key as String,
              List<String>.from((value as List? ?? []).cast<String>()),
            )),
      ),
      attachments: List<ProjectAttachment>.from(
        (data['attachments'] as List? ?? []).map((attachment) {
          final map = Map<String, dynamic>.from(attachment as Map);
          return ProjectAttachment.fromMap(map);
        }),
      ),
    );
  }

  ProjectChannel _parseProjectChannel(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final lastMessageAtValue = data['lastMessageAt'];
    DateTime? lastMessageAt;
    if (lastMessageAtValue is Timestamp) {
      lastMessageAt = lastMessageAtValue.toDate();
    } else if (lastMessageAtValue is DateTime) {
      lastMessageAt = lastMessageAtValue;
    }

    return ProjectChannel(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      name: data['name'] as String? ?? 'general',
      createdBy: data['createdBy'] as String? ?? '',
      members:
          List<String>.from((data['members'] as List? ?? []).cast<String>()),
      isPrivate: data['isPrivate'] as bool? ?? false,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      lastMessageAt: lastMessageAt,
      messageCount: data['messageCount'] as int? ?? 0,
    );
  }

  ProjectCallSession _parseProjectCallSession(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProjectCallSession(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      startedBy: data['startedBy'] as String? ?? '',
      participants: List<String>.from(
        (data['participants'] as List? ?? []).cast<String>(),
      ),
      active: data['active'] as bool? ?? false,
      type: data['type'] as String? ?? 'team',
      invitedParticipants: List<String>.from(
        (data['invitedParticipants'] as List? ?? []).cast<String>(),
      ),
      startedAt: _parseDateTime(data['startedAt']) ?? DateTime.now(),
      endedAt: _parseDateTime(data['endedAt']),
      audioEnabled: data['audioEnabled'] as bool? ?? true,
      videoEnabled: data['videoEnabled'] as bool? ?? true,
      screenSharing: data['screenSharing'] as bool? ?? false,
      roomName: data['roomName'] as String? ?? '',
      roomUrl: data['roomUrl'] as String? ?? '',
    );
  }

  ProjectCallSchedule _parseProjectCallSchedule(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProjectCallSchedule(
      id: doc.id,
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      agenda: data['agenda'] as String? ?? '',
      description: data['description'] as String? ?? '',
      scheduledAt: _parseDateTime(data['scheduledAt']) ?? DateTime.now(),
      durationMinutes: data['durationMinutes'] as int? ?? 30,
      invitedParticipants: List<String>.from(
        (data['invitedParticipants'] as List? ?? []).cast<String>(),
      ),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      reminderAt: _parseDateTime(data['reminderAt']) ?? DateTime.now(),
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  ProjectNotificationItem _parseNotificationItem(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ProjectNotificationItem(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      type: data['type'] as String? ?? 'new_message',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      deliverAt: _parseDateTime(data['deliverAt']),
      data: Map<String, dynamic>.from(data['data'] as Map? ?? {}),
    );
  }
}
