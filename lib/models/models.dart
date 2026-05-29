import 'package:cloud_firestore/cloud_firestore.dart';

class Attachment {
  final String id;
  final String name;
  final String type;
  final String uploadedBy;
  final String uploadedAt;

  const Attachment({
    required this.id,
    required this.name,
    required this.type,
    required this.uploadedBy,
    required this.uploadedAt,
  });
}

class ProjectDocument {
  final String id;
  final String title;
  final String content;
  final List<Attachment> attachments;

  const ProjectDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.attachments,
  });
}

class ProjectLevel {
  final String id;
  final String title;
  final int order;
  final DateTime createdAt;
  final bool completed;
  final int percentage;
  final String updatedBy;
  final DateTime? updatedAt;

  const ProjectLevel({
    required this.id,
    required this.title,
    required this.order,
    required this.createdAt,
    this.completed = false,
    this.percentage = 0,
    this.updatedBy = '',
    this.updatedAt,
  });
}

class ProjectStats {
  final int tasksCompleted;
  final int ideasAdded;
  final int meetingsConducted;
  final int messagesSent;

  const ProjectStats({
    required this.tasksCompleted,
    required this.ideasAdded,
    required this.meetingsConducted,
    required this.messagesSent,
  });
}

class IdeaBoardFile {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final String uploadedBy;
  final String uploadedByUsername;
  final DateTime uploadedAt;
  final String storagePath;
  final String projectId;
  final String blockId;

  const IdeaBoardFile({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedBy,
    this.uploadedByUsername = '',
    required this.uploadedAt,
    this.storagePath = '',
    this.projectId = '',
    this.blockId = '',
  });

  factory IdeaBoardFile.fromMap(Map<String, dynamic> map) {
    final uploadedAtValue = map['uploadedAt'];
    DateTime uploadedAt;
    if (uploadedAtValue is DateTime) {
      uploadedAt = uploadedAtValue;
    } else if (uploadedAtValue is Timestamp) {
      uploadedAt = uploadedAtValue.toDate();
    } else {
      uploadedAt = DateTime.tryParse(uploadedAtValue?.toString() ?? '') ?? DateTime.now();
    }

    return IdeaBoardFile(
      id: map['id'] as String? ?? '',
      fileName: map['fileName'] as String? ?? map['name'] as String? ?? 'Attachment',
      fileUrl: map['fileUrl'] as String? ?? map['url'] as String? ?? map['downloadUrl'] as String? ?? '',
      fileType: map['fileType'] as String? ?? map['type'] as String? ?? map['mimeType'] as String? ?? 'file',
      fileSize: map['fileSize'] as int? ?? map['sizeBytes'] as int? ?? map['size'] as int? ?? 0,
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedByUsername: map['uploadedByUsername'] as String? ?? '',
      uploadedAt: uploadedAt,
      storagePath: map['storagePath'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      blockId: map['blockId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedBy': uploadedBy,
      'uploadedByUsername': uploadedByUsername,
      'uploadedAt': uploadedAt.toIso8601String(),
      'storagePath': storagePath,
      'projectId': projectId,
      'blockId': blockId,
      'name': fileName,
      'url': fileUrl,
      'type': fileType,
      'sizeBytes': fileSize,
    };
  }

  String get name => fileName;
  String get url => fileUrl;
  String get type => fileType;
  int get sizeBytes => fileSize;
}

  class IdeaBoardBlock {
    final String id;
    final String levelId;
    final String type; // title | paragraph | file
    final String content;
    final List<IdeaBoardFile> files;
    final String createdBy;
    final DateTime createdAt;

    const IdeaBoardBlock({
      required this.id,
      required this.levelId,
      required this.type,
      required this.content,
      required this.files,
      required this.createdBy,
      required this.createdAt,
    });
  }

class Project {
  final String id;
  final String title;
  final String description;
  final String createdBy; // userId of creator
  final Map<String, String> collaborators; // Map<userId, role>
  final String visibility; // "public" or "private"
  final bool isOpenForRequests; // Allow join requests?
  final int requiredCollaborators;
  final List<String> requiredSkills;
  final String contactEmail;
  final String lastUpdated;
  final DateTime createdAt;
  final List<ProjectLevel> levels;
  final List<IdeaBoardBlock> ideaBoardBlocks;
  final ProjectStats stats;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.collaborators,
    required this.visibility,
    required this.isOpenForRequests,
    required this.requiredCollaborators,
    required this.requiredSkills,
    required this.contactEmail,
    required this.lastUpdated,
    required this.createdAt,
    required this.levels,
    required this.stats,
    required this.ideaBoardBlocks,
  });

  // Helper to check if user is admin of this project
  bool isAdmin(String userId) => createdBy == userId || collaborators[userId] == 'admin';

  // Helper to check if user is collaborator
  bool isCollaborator(String userId) =>
      collaborators.containsKey(userId) || createdBy == userId;

  // Helper to get collaborator count
  int get collaboratorCount => safeCollaboratorCount;

  int get currentCollaborators => safeCollaboratorCount;

  int get collaboratorsRequired => requiredCollaborators;

  // Helper to check if project is private
  bool get isPrivate => visibility == 'private';

  // Helper to check if requests are allowed
  bool get acceptingRequests => isOpenForRequests && visibility == 'public';

  bool get isOpenToRequests => isOpenForRequests;

  int get safeCollaboratorCount =>
      collaborators.length + (collaborators.containsKey(createdBy) ? 0 : 1);
}

extension ProjectDisplayValues on Project {
  String get displayTitle =>
      title.trim().isNotEmpty ? title.trim() : 'Untitled Project';

  String get displayDescription =>
      description.trim().isNotEmpty ? description.trim() : 'No description added yet.';

  String get displayVisibility =>
      visibility.trim().isNotEmpty ? visibility.trim() : 'private';

  String get displayLastUpdated =>
      lastUpdated.trim().isNotEmpty ? lastUpdated.trim() : 'Recently';

  double get progressValue {
    if (stats.tasksCompleted <= 0) {
      return 0;
    }

    return (stats.tasksCompleted % 100) / 100;
  }
}

class ProjectAttachment {
  final String id;
  final String name;
  final String mimeType;
  final int size;
  final String downloadUrl;
  final String uploadedBy;
  final DateTime createdAt;
  final String storagePath;

  const ProjectAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.downloadUrl,
    required this.uploadedBy,
    required this.createdAt,
    required this.storagePath,
  });

  factory ProjectAttachment.fromMap(Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];
    final createdAt = createdAtValue is DateTime
        ? createdAtValue
        : createdAtValue is Timestamp
            ? createdAtValue.toDate()
            : DateTime.tryParse(createdAtValue?.toString() ?? '') ?? DateTime.now();

    return ProjectAttachment(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? map['fileName'] as String? ?? 'Attachment',
      mimeType: map['mimeType'] as String? ?? map['fileType'] as String? ?? map['type'] as String? ?? 'application/octet-stream',
      size: map['size'] as int? ?? map['fileSize'] as int? ?? map['sizeBytes'] as int? ?? 0,
      downloadUrl: map['downloadUrl'] as String? ?? map['fileUrl'] as String? ?? map['url'] as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      createdAt: createdAt,
      storagePath: map['storagePath'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mimeType': mimeType,
      'size': size,
      'downloadUrl': downloadUrl,
      'uploadedBy': uploadedBy,
      'createdAt': createdAt.toIso8601String(),
      'storagePath': storagePath,
      'fileName': name,
      'fileUrl': downloadUrl,
      'fileType': mimeType,
      'fileSize': size,
      'url': downloadUrl,
      'type': mimeType,
      'sizeBytes': size,
    };
  }

  String get fileName => name;
  String get fileUrl => downloadUrl;
  String get fileType => mimeType;
  int get fileSize => size;
}

typedef ProjectMessageAttachment = ProjectAttachment;

class ChatMessage {
  final String id;
  final String userId;
  final String username;
  final String timestamp;
  final String message;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.username,
    required this.timestamp,
    required this.message,
  });
}

class ChatChannel {
  final String id;
  final String name;
  final List<ChatMessage> messages;

  const ChatChannel({
    required this.id,
    required this.name,
    required this.messages,
  });
}

class AppNotification {
  final String id;
  final String text;
  final String time;
  final bool read;

  const AppNotification({
    required this.id,
    required this.text,
    required this.time,
    required this.read,
  });
}

class AppUser {
  final String id;
  final String username; // For @ mentions and lookups
  final String name;
  final String email;
  final String photoUrl;
  final int projectsJoined;
  final int tasksCompleted;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.photoUrl = '',
    required this.projectsJoined,
    required this.tasksCompleted,
    required this.createdAt,
  });
}

/// Represents a channel within a project (Discord/Slack-style)
class ProjectChannel {
  final String id;
  final String projectId;
  final String name;
  final String createdBy;
  final List<String> members; // For private channels; empty = all collaborators can see
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int messageCount;

  const ProjectChannel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.createdBy,
    this.members = const [],
    this.isPrivate = false,
    required this.createdAt,
    this.lastMessageAt,
    this.messageCount = 0,
  });

  factory ProjectChannel.fromMap(Map<String, dynamic> map) {
    final lastMessageAtValue = map['lastMessageAt'];
    DateTime? lastMessageAt;
    if (lastMessageAtValue is DateTime) {
      lastMessageAt = lastMessageAtValue;
    } else if (lastMessageAtValue is Timestamp) {
      lastMessageAt = lastMessageAtValue.toDate();
    } else if (lastMessageAtValue != null) {
      lastMessageAt = DateTime.tryParse(lastMessageAtValue.toString());
    }

    final createdAtValue = map['createdAt'];
    DateTime createdAt;
    if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    } else if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else {
      createdAt = DateTime.tryParse(createdAtValue?.toString() ?? '') ?? DateTime.now();
    }

    return ProjectChannel(
      id: map['id'] as String? ?? '',
      projectId: map['projectId'] as String? ?? '',
      name: map['name'] as String? ?? 'general',
      createdBy: map['createdBy'] as String? ?? '',
      members: List<String>.from((map['members'] as List? ?? []).cast<String>()),
      isPrivate: map['isPrivate'] as bool? ?? false,
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
      messageCount: map['messageCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'isPrivate': isPrivate,
      'createdAt': createdAt,
      'lastMessageAt': lastMessageAt,
      'messageCount': messageCount,
    };
  }
}

class ProjectChatMessage {
  final String id;
  final String projectId;
  final String channelId; // New: which channel this message belongs to
  final String senderId;
  final String senderUsername;
  final String senderPhoto;
  final String text;
  final String fileUrl;
  final String downloadUrl;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String replyToMessageId;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, List<String>> reactions;
  final List<ProjectAttachment> attachments;

  const ProjectChatMessage({
    required this.id,
    required this.projectId,
    required this.channelId,
    required this.senderId,
    required this.senderUsername,
    required this.senderPhoto,
    required this.text,
    this.fileUrl = '',
    this.downloadUrl = '',
    this.fileName = '',
    this.fileType = '',
    this.fileSize = 0,
    required this.replyToMessageId,
    required this.edited,
    required this.deleted,
    required this.createdAt,
    required this.updatedAt,
    this.reactions = const {},
    this.attachments = const [],
  });

  bool get hasReply => replyToMessageId.trim().isNotEmpty;
  bool get hasFileLink => fileUrl.trim().isNotEmpty || downloadUrl.trim().isNotEmpty;
}

class ProjectCallSession {
  final String id;
  final String projectId;
  final String startedBy;
  final List<String> participants;
  final bool active;
  final String type;
  final List<String> invitedParticipants;
  final String callMode;
  final bool historyVisible;
  final String sessionToken;
  final String scheduleId;
  final String meetingTitle;
  final String agenda;
  final int durationMinutes;
  final String timeZone;
  final String hostDisplayName;
  final String roomName;
  final String roomUrl;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool audioEnabled;
  final bool videoEnabled;
  final bool screenSharing;

  const ProjectCallSession({
    required this.id,
    required this.projectId,
    required this.startedBy,
    required this.participants,
    required this.active,
    required this.type,
    required this.invitedParticipants,
    this.callMode = 'instant',
    this.historyVisible = false,
    this.sessionToken = '',
    this.scheduleId = '',
    this.meetingTitle = '',
    this.agenda = '',
    this.durationMinutes = 0,
    this.timeZone = '',
    this.hostDisplayName = '',
    this.roomName = '',
    this.roomUrl = '',
    required this.startedAt,
    this.endedAt,
    this.audioEnabled = true,
    this.videoEnabled = true,
    this.screenSharing = false,
  });
}

class ProjectCallSchedule {
  final String id;
  final String projectId;
  final String title;
  final String agenda;
  final String description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final List<String> invitedParticipants;
  final String createdBy;
  final String hostDisplayName;
  final String timeZone;
  final String sessionId;
  final DateTime createdAt;
  final DateTime reminderAt;
  final String status;

  const ProjectCallSchedule({
    required this.id,
    required this.projectId,
    required this.title,
    required this.agenda,
    required this.description,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.invitedParticipants,
    required this.createdBy,
    this.hostDisplayName = '',
    this.timeZone = '',
    this.sessionId = '',
    required this.createdAt,
    required this.reminderAt,
    required this.status,
  });
}

class ProjectMeetingItem {
  final String id;
  final String projectId;
  final String projectTitle;
  final String title;
  final String agenda;
  final DateTime scheduledAt;
  final int durationMinutes;
  final List<String> invitedParticipants;
  final String createdBy;
  final String hostDisplayName;
  final String timeZone;
  final String status;
  final String sessionId;
  final String roomName;
  final DateTime createdAt;

  const ProjectMeetingItem({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.title,
    required this.agenda,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.invitedParticipants,
    required this.createdBy,
    required this.hostDisplayName,
    required this.timeZone,
    required this.status,
    this.sessionId = '',
    this.roomName = '',
    required this.createdAt,
  });
}

class ProjectNotificationItem {
  final String id;
  final String userId;
  final String projectId;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final DateTime? deliverAt;
  final Map<String, dynamic> data;

  const ProjectNotificationItem({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.deliverAt,
    this.data = const {},
  });
}

class Meeting {
  final String id;
  final String title;
  final String time;
  final List<String> participants;
  final String projectId;
  final bool isActive;

  const Meeting({
    required this.id,
    required this.title,
    required this.time,
    required this.participants,
    required this.projectId,
    required this.isActive,
  });
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final String type; // 'meeting', 'chat', 'deadline'
  final String time;
  final bool isRead;
  final dynamic data; // Can contain Meeting or Chat info

  const Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.time,
    required this.isRead,
    required this.data,
  });
}

class JoinRequest {
  final String id;
  final String projectId;
  final String requestedBy; // userId
  final String requestedByEmail;
  final String requestedByName;
  final String requestedByUsername;
  final List<String> skills; // User's skills
  final String message; // Cover letter / motivation
  final String? githubLink;
  final String? linkedinLink;
  final List<String> fileUrls; // Portfolio files from Firebase Storage
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime? respondedAt;

  const JoinRequest({
    required this.id,
    required this.projectId,
    required this.requestedBy,
    required this.requestedByEmail,
    required this.requestedByName,
    required this.requestedByUsername,
    required this.skills,
    required this.message,
    this.githubLink,
    this.linkedinLink,
    required this.fileUrls,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });
}
