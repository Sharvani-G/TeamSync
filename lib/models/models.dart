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
  final String name;
  final int progress;
  final List<ProjectDocument> documents;

  const ProjectLevel({
    required this.id,
    required this.name,
    required this.progress,
    required this.documents,
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
  final String name;
  final String email;
  final int projectsJoined;
  final int tasksCompleted;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.projectsJoined,
    required this.tasksCompleted,
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
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  const JoinRequest({
    required this.id,
    required this.projectId,
    required this.requestedBy,
    required this.requestedByEmail,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
  });
}
