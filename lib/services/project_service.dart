import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class ProjectService {
  ProjectService._();

  static final ProjectService instance = ProjectService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ PROJECT STREAMS ============

  /// Get all projects for the current user (created by or collaborator)
  Stream<List<Project>> watchMyProjects() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      return Stream.value([]);
    }

    return _firestore.collection('projects').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final createdBy = data['createdBy'] as String? ?? '';
            final collaborators = data['collaborators'] as Map<String, dynamic>? ?? {};
            
            // Include if user is creator or collaborator
            return createdBy == authUser.uid || 
                   collaborators.containsKey(authUser.uid);
          })
          .map((doc) => _parseProject(doc))
          .toList();
    });
  }

  /// Get all public projects for discovery
  Stream<List<Project>> watchPublicProjects() {
    final authUser = _auth.currentUser;
    
    return _firestore
        .collection('projects')
        .where('visibility', isEqualTo: 'public')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            // Exclude projects where user is already a collaborator
            if (authUser == null) return true;
            final data = doc.data();
            final createdBy = data['createdBy'] as String? ?? '';
            final collaborators = data['collaborators'] as Map<String, dynamic>? ?? {};
            
            return createdBy != authUser.uid && 
                   !collaborators.containsKey(authUser.uid);
          })
          .map((doc) => _parseProject(doc))
          .toList();
    });
  }

  /// Get a single project by ID
  Stream<Project?> watchProject(String projectId) {
    return _firestore.collection('projects').doc(projectId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return _parseProject(doc);
    });
  }

  // ============ PROJECT CREATION ============

  /// Create a new project
  Future<String> createProject({
    required String title,
    required String description,
    required Map<String, String> collaborators, // Map<userId, role>
    required String visibility, // 'public' or 'private'
    required bool isOpenForRequests,
    required int requiredCollaborators,
    required List<String> requiredSkills,
    required String contactEmail,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in to create a project');
    }

    final projectRef = _firestore.collection('projects').doc();
    
    final projectData = {
      'id': projectRef.id,
      'title': title,
      'description': description,
      'createdBy': authUser.uid,
      'collaborators': collaborators,
      'visibility': visibility,
      'isOpenForRequests': isOpenForRequests,
      'requiredCollaborators': requiredCollaborators,
      'requiredSkills': requiredSkills,
      'contactEmail': contactEmail,
      'lastUpdated': DateTime.now().toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'levels': [],
      'tasksCompleted': 0,
      'ideasAdded': 0,
      'meetingsConducted': 0,
      'messagesSent': 0,
    };

    await projectRef.set(projectData);
    return projectRef.id;
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
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    if (visibility != null) updateData['visibility'] = visibility;
    if (isOpenForRequests != null) updateData['isOpenForRequests'] = isOpenForRequests;
    if (requiredCollaborators != null) updateData['requiredCollaborators'] = requiredCollaborators;
    if (requiredSkills != null) updateData['requiredSkills'] = requiredSkills;
    if (contactEmail != null) updateData['contactEmail'] = contactEmail;

    await _firestore.collection('projects').doc(projectId).update(updateData);
  }

  // ============ COLLABORATOR MANAGEMENT ============

  /// Add collaborator to project
  Future<void> addCollaborator({
    required String projectId,
    required String userId,
    required String role, // 'admin', 'collaborator', etc.
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can add collaborators');
    }

    final collaborators = (projectDoc.data()?['collaborators'] as Map<String, dynamic>? ?? {}) as Map<String, dynamic>;
    collaborators[userId] = role;

    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Remove collaborator from project
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
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can remove collaborators');
    }

    final collaborators = (projectDoc.data()?['collaborators'] as Map<String, dynamic>? ?? {}) as Map<String, dynamic>;
    collaborators.remove(userId);

    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  /// Add collaborator by username (email lookup)
  Future<void> addCollaboratorByUsername({
    required String projectId,
    required String email,
    required String role,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can add collaborators');
    }

    // Find user by email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('User with email "$email" not found');
    }

    final userId = userQuery.docs.first.id;

    // Check if already a collaborator
    final collaborators = (projectDoc.data()?['collaborators'] as Map<String, dynamic>? ?? {}) as Map<String, dynamic>;
    if (collaborators.containsKey(userId)) {
      throw Exception('User is already a collaborator');
    }

    // Add collaborator
    collaborators[userId] = role;
    await _firestore.collection('projects').doc(projectId).update({
      'collaborators': collaborators,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  // ============ JOIN REQUEST MANAGEMENT ============

  /// Send a join request to a project
  Future<void> requestToJoinProject(String projectId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    // Verify project exists and is public with requests open
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
    final collaborators = projectData['collaborators'] as Map<String, dynamic>? ?? {};
    
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

    // Create join request
    final requestRef = _firestore.collection('joinRequests').doc();
    await requestRef.set({
      'id': requestRef.id,
      'projectId': projectId,
      'requestedBy': authUser.uid,
      'requestedByEmail': userEmail,
      'requestedByName': userName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Get join requests for a project (admin only)
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
          final projectDoc = await _firestore.collection('projects').doc(projectId).get();
          final createdBy = projectDoc.data()?['createdBy'];
          
          if (createdBy != authUser.uid) {
            return [];
          }

          return snapshot.docs.map((doc) => _parseJoinRequest(doc)).toList();
        });
  }

  /// Accept a join request
  Future<void> acceptJoinRequest(String requestId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final requestDoc = await _firestore.collection('joinRequests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Join request not found');
    }

    final requestData = requestDoc.data()!;
    final projectId = requestData['projectId'] as String;
    final requestedBy = requestData['requestedBy'] as String;

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can accept join requests');
    }

    // Add user as collaborator
    await addCollaborator(
      projectId: projectId,
      userId: requestedBy,
      role: 'collaborator',
    );

    // Update request status
    await _firestore.collection('joinRequests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User must be logged in');
    }

    final requestDoc = await _firestore.collection('joinRequests').doc(requestId).get();
    if (!requestDoc.exists) {
      throw Exception('Join request not found');
    }

    final requestData = requestDoc.data()!;
    final projectId = requestData['projectId'] as String;

    // Verify user is admin
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final createdBy = projectDoc.data()?['createdBy'];
    if (createdBy != authUser.uid) {
      throw Exception('Only project admin can reject join requests');
    }

    // Update request status
    await _firestore.collection('joinRequests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // ============ HELPER METHODS ============

  /// Parse Firestore project document to Project model
  Project _parseProject(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    final collaboratorsData = data['collaborators'] as Map<String, dynamic>? ?? {};
    final collaboratorsMap = collaboratorsData.map(
      (key, value) => MapEntry(key, value as String),
    );

    return Project(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      collaborators: collaboratorsMap,
      visibility: data['visibility'] as String? ?? 'private',
      isOpenForRequests: data['isOpenForRequests'] as bool? ?? false,
      requiredCollaborators: data['requiredCollaborators'] as int? ?? 0,
      requiredSkills: List<String>.from(data['requiredSkills'] as List? ?? []),
      contactEmail: data['contactEmail'] as String? ?? '',
      lastUpdated: data['lastUpdated'] as String? ?? 'Recently',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
      levels: _parseProjectLevels(data['levels'] as List<dynamic>? ?? []),
      stats: ProjectStats(
        tasksCompleted: data['tasksCompleted'] as int? ?? 0,
        ideasAdded: data['ideasAdded'] as int? ?? 0,
        meetingsConducted: data['meetingsConducted'] as int? ?? 0,
        messagesSent: data['messagesSent'] as int? ?? 0,
      ),
    );
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
      status: data['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Helper method to parse project levels from Firestore data
  List<ProjectLevel> _parseProjectLevels(List<dynamic> levelsList) {
    return levelsList.map((level) {
      final levelData = level as Map<String, dynamic>? ?? {};
      return ProjectLevel(
        id: levelData['id'] as String? ?? '',
        name: levelData['name'] as String? ?? '',
        progress: levelData['progress'] as int? ?? 0,
        documents: _parseProjectDocuments(levelData['documents'] as List<dynamic>? ?? []),
      );
    }).toList();
  }

  /// Helper method to parse project documents from Firestore data
  List<ProjectDocument> _parseProjectDocuments(List<dynamic> documentsList) {
    return documentsList.map((doc) {
      final docData = doc as Map<String, dynamic>? ?? {};
      return ProjectDocument(
        id: docData['id'] as String? ?? '',
        title: docData['title'] as String? ?? '',
        content: docData['content'] as String? ?? '',
        attachments: _parseAttachments(docData['attachments'] as List<dynamic>? ?? []),
      );
    }).toList();
  }

  /// Helper method to parse attachments from Firestore data
  List<Attachment> _parseAttachments(List<dynamic> attachmentsList) {
    return attachmentsList.map((attachment) {
      final attData = attachment as Map<String, dynamic>? ?? {};
      return Attachment(
        id: attData['id'] as String? ?? '',
        name: attData['name'] as String? ?? '',
        type: attData['type'] as String? ?? '',
        uploadedBy: attData['uploadedBy'] as String? ?? '',
        uploadedAt: attData['uploadedAt'] as String? ?? '',
      );
    }).toList();
  }
}
