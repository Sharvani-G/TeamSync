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

  const ProjectLevel({
    required this.id,
    required this.title,
    required this.order,
    required this.createdAt,
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
  });

  // Helper to check if user is admin of this project
  bool isAdmin(String userId) => createdBy == userId;

  // Helper to check if user is collaborator
  bool isCollaborator(String userId) =>
      collaborators.containsKey(userId) || createdBy == userId;

  // Helper to get collaborator count
  int get collaboratorCount => collaborators.length + 1; // +1 for creator

  // Helper to check if project is private
  bool get isPrivate => visibility == 'private';

  // Helper to check if requests are allowed
  bool get acceptingRequests => isOpenForRequests && visibility == 'public';

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
  final int projectsJoined;
  final int tasksCompleted;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.projectsJoined,
    required this.tasksCompleted,
    required this.createdAt,
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
