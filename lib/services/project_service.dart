import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
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

  // ============ PROJECT STREAMS ============

  /// Get all projects for the current user (created by or collaborator)
  /// Real-time stream that combines created projects and collaborator projects
  Stream<List<Project>> watchMyProjects() {
    return _auth.authStateChanges().asyncExpand((authUser) {
      if (authUser == null) {
        return Stream.value([]);
      }

      // Listen to all projects and filter on client side
      return _firestore
          .collection('projects')
          .snapshots()
          .map<List<Project>>((snapshot) {
            try {
              final projects = <Project>[];
              
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdBy = data['createdBy'] as String? ?? '';
                  final collaborators = _parseCollaboratorsMap(
                    data['collaborators'],
                    docId: doc.id,
                  );
                  
                  // Include if user created it OR user is a collaborator
                  if (createdBy == authUser.uid || collaborators.containsKey(authUser.uid)) {
                    print('📁 Project ${doc.id} visible to ${authUser.uid}');
                    final project = _parseProject(doc);
                    projects.add(project);
                  }
                } catch (e) {
                  print('⚠️  Error parsing project ${doc.id}: $e');
                  // Skip broken documents, continue with others
                }
              }
              
              print('✅ Loaded ${projects.length} accessible projects');
              return projects;
            } catch (e) {
              print('❌ Error filtering projects: $e');
              return [];
            }
          });
    });
  }

  /// Get all public projects for discovery
  Stream<List<Project>> watchPublicProjects() {
    return _auth.authStateChanges().asyncExpand((authUser) {
      return _firestore
          .collection('projects')
          .where('visibility', isEqualTo: 'public')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .where((doc) {
              // Exclude projects where user is already a collaborator.
              if (authUser == null) return true;
              final data = doc.data();
              final createdBy = data['createdBy'] as String? ?? '';
              final collaborators = _parseCollaboratorsMap(
                data['collaborators'],
                docId: doc.id,
              );

              return createdBy != authUser.uid &&
                  !collaborators.containsKey(authUser.uid);
            })
            .map((doc) => _parseProject(doc))
            .toList();
      });
    });
  }

  /// Get a single project by ID
  Stream<Project?> watchProject(String projectId) {
    return _auth.authStateChanges().asyncExpand((authUser) {
      return _firestore.collection('projects').doc(projectId).snapshots().asyncMap((doc) async {
        if (!doc.exists) {
          return null;
        }

        final project = _parseProject(doc);
        if (project.levels.isEmpty && authUser != null && project.createdBy == authUser.uid) {
          await _ensureDefaultLevelsIfMissing(projectId);
          final refreshed = await _firestore.collection('projects').doc(projectId).get();
          if (!refreshed.exists) {
            return null;
          }
          return _parseProject(refreshed);
        }

        return project;
      });
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
    final uniqueUsernames = {...collaboratorUsernames}
        .where((u) => u.trim().isNotEmpty)
        .toList();

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
      'tasksCompleted': 0,
      'ideasAdded': 0,
      'meetingsConducted': 0,
      'messagesSent': 0,
    };

    try {
      await projectRef.set(projectData);
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
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can update settings');
    }

    final updateData = <String, dynamic>{
      'lastUpdated': Timestamp.now(),
    };

    if (visibility != null) updateData['visibility'] = visibility;
    if (isOpenForRequests != null) updateData['isOpenForRequests'] = isOpenForRequests;
    if (requiredCollaborators != null) updateData['requiredCollaborators'] = requiredCollaborators;
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

    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final createdBy = projectDoc.data()?['createdBy'] as String?;
    if (createdBy != authUser.uid) {
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

      if (currentLevels.any((level) => (level['title'] as String? ?? '').toLowerCase() == trimmedTitle.toLowerCase())) {
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

      final existingIndex = currentLevels.indexWhere((level) => level['id'] == levelId);
      if (existingIndex == -1) {
        throw Exception('Level not found');
      }

      if (currentLevels.any((level) =>
          level['id'] != levelId &&
          (level['title'] as String? ?? '').toLowerCase() == trimmedTitle.toLowerCase())) {
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
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final data = projectDoc.data()!;
    final createdBy = data['createdBy'] as String?;
    if (createdBy != authUser.uid) {
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
      throw Exception('User "@${collaboratorUsername}" is already a collaborator');
    }

    // Add to collaborators map
    collaborators[userId] = 'collaborator';

    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Remove collaborator from project (admin only)
  Future<void> removeCollaborator({
    required String projectId,
    required String userId,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final data = projectDoc.data()!;
    final createdBy = data['createdBy'] as String?;
    if (createdBy != authUser.uid) {
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

    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': DateTime.now().toIso8601String(),
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
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final projectData = projectDoc.data()!;
    final visibility = projectData['visibility'] as String?;
    final isOpenForRequests = projectData['isOpenForRequests'] as bool? ?? false;

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
      throw Exception('You already have a pending join request for this project');
    }

    // Get user info
    final userDoc = await _firestore.collection('users').doc(authUser.uid).get();
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
          final createdBy = projectDoc.data()?['createdBy'];
          
          if (createdBy != authUser.uid) {
            return []; // Non-admin gets empty list
          }

          return snapshot.docs
              .map((doc) => _parseJoinRequest(doc))
              .toList();
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
          return snapshot.docs
              .map((doc) => _parseJoinRequest(doc))
              .toList();
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
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can accept join requests');
    }

    // Add user as collaborator and update request atomically
    final batch = _firestore.batch();

    // Update project collaborators
    final collaborators = (projectDoc.data()?['collaborators'] 
        as Map<String, dynamic>? ?? {})
      ..cast<String, dynamic>();
    collaborators[requestedBy] = 'collaborator';

    batch.update(
      _firestore.collection('projects').doc(projectId),
      {
        'collaborators': collaborators,
        'lastUpdated': DateTime.now().toIso8601String(),
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
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
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
        requiredSkills = skillsData
            .whereType<String>()
            .toList();
      }
      
      final contactEmail = data['contactEmail'] as String? ?? '';
      final lastUpdated = _parseTimestampString(data['lastUpdated']) ?? 'Recently';
      final createdAt = _parseDateTime(data['createdAt']) ?? DateTime.now();
      
      // Safe levels parsing
      final levelsData = data['levels'];
      List<ProjectLevel> levels = [];
      if (levelsData is List) {
        levels = _parseProjectLevels(levelsData);
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
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
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
        id: levelData['id'] as String? ?? _firestore.collection('projects').doc().id,
        title: levelData['title'] as String? ?? levelData['name'] as String? ?? '',
        order: levelData['order'] as int? ?? 0,
        createdAt: _parseDateTime(levelData['createdAt']) ?? DateTime.now(),
      );
    }).toList();

    parsedLevels.sort((a, b) => a.order.compareTo(b.order));
    return parsedLevels;
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
    };
  }

  List<Map<String, dynamic>> _normalizeLevelEntries(List<Map<String, dynamic>>? levels) {
    final entries = (levels == null || levels.isEmpty)
        ? _defaultLevelTitles
            .asMap()
            .entries
            .map((entry) => _buildLevelEntry(title: entry.value, order: entry.key + 1))
            .toList()
        : levels
            .map((level) => {
                  'id': (level['id'] as String?) ?? _firestore.collection('projects').doc().id,
                  'title': (level['title'] as String?)?.trim().isNotEmpty == true
                      ? (level['title'] as String).trim()
                      : 'Untitled Level',
                  'order': level['order'] as int? ?? 0,
                  'createdAt': level['createdAt'] ?? Timestamp.now(),
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
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>> levels) updater,
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
      final createdBy = data['createdBy'] as String?;
      if (createdBy != authUser.uid) {
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
    final ordered = [...levels]
      ..sort((a, b) {
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
        final collaborators = data['collaborators'] as Map<String, dynamic>? ?? {};
        
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
}
