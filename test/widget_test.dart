import 'package:flutter_test/flutter_test.dart';
import 'package:teamsync/models/models.dart';

void main() {
  test('Project collaborator access and counts are correct', () {
    final project = Project(
      id: 'project-1',
      title: 'Realtime board',
      description: 'Collaboration test',
      createdBy: 'admin-1',
      collaborators: const {
        'admin-1': 'admin',
        'user-2': 'collaborator',
      },
      visibility: 'private',
      isOpenForRequests: false,
      requiredCollaborators: 2,
      requiredSkills: const ['flutter', 'firebase'],
      contactEmail: 'owner@example.com',
      lastUpdated: 'now',
      createdAt: DateTime(2026, 5, 10),
      levels: const [],
      stats: const ProjectStats(
        tasksCompleted: 35,
        ideasAdded: 4,
        meetingsConducted: 1,
        messagesSent: 8,
      ),
      ideaBoardBlocks: const [],
    );

    expect(project.isAdmin('admin-1'), isTrue);
    expect(project.isCollaborator('user-2'), isTrue);
    expect(project.isCollaborator('outsider'), isFalse);
    expect(project.collaboratorCount, 2);
    expect(project.safeCollaboratorCount, 2);
  });

  test('Project visibility flags behave as expected', () {
    final publicProject = Project(
      id: 'project-2',
      title: 'Public workspace',
      description: 'Discovery',
      createdBy: 'admin-1',
      collaborators: const {'user-2': 'collaborator'},
      visibility: 'public',
      isOpenForRequests: true,
      requiredCollaborators: 0,
      requiredSkills: const [],
      contactEmail: 'owner@example.com',
      lastUpdated: 'now',
      createdAt: DateTime(2026, 5, 10),
      levels: const [],
      stats: const ProjectStats(
        tasksCompleted: 0,
        ideasAdded: 0,
        meetingsConducted: 0,
        messagesSent: 0,
      ),
      ideaBoardBlocks: const [],
    );

    expect(publicProject.isPrivate, isFalse);
    expect(publicProject.acceptingRequests, isTrue);
  });
}
