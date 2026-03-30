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
  final int collaborators;
  final bool isPrivate;
  final String lastUpdated;
  final List<ProjectLevel> levels;
  final ProjectStats stats;

  const Project({
    required this.id,
    required this.title,
    required this.description,
    required this.collaborators,
    required this.isPrivate,
    required this.lastUpdated,
    required this.levels,
    required this.stats,
  });
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
