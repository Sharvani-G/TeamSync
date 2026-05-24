import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'project_admin_screen.dart';

class ProjectOverviewScreen extends StatelessWidget {
  final String projectId;
  const ProjectOverviewScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Project not found')),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final isAdmin = currentUser != null && project.isAdmin(currentUser.uid);
        final isCollaborator =
            currentUser != null && project.isCollaborator(currentUser.uid);
        final canEditWorkspace = isCollaborator;

        final memberIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

        return Scaffold(
          appBar: SimpleAppBar(
            title: project.title,
            actions: [
              if (isAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectAdminScreen(
                            projectId: projectId,
                            project: project,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      backgroundColor: AppTheme.primary.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Manage Project'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    if (project.collaborators.isNotEmpty)
                      ...project.collaborators.entries
                          .take(3)
                          .map((entry) => _CollaboratorAvatar(
                                userId: entry.key,
                                role: entry.value,
                              ))
                          .toList(),
                    if (project.collaborators.length > 3)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '+${project.collaborators.length - 3}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Project Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Project Info',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: project.visibility == 'public'
                                  ? Colors.blue[100]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              project.visibility.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: project.visibility == 'public'
                                    ? Colors.blue[700]
                                    : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        project.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.people,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            '${project.collaboratorCount} members',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(project.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (project.requiredSkills.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: project.requiredSkills
                              .map((skill) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      skill,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<Map<String, AppUser>>(
                future: UserService.instance.getUsersByIds(memberIds),
                builder: (context, memberSnapshot) {
                  final members = memberSnapshot.data ?? {};
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collaborators',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...memberIds.map((userId) {
                            final user = members[userId];
                            final isAdmin = project.isAdmin(userId);
                            final username = user?.username.trim().isNotEmpty == true ? user!.username : '';
                            final displayName = user?.name.trim().isNotEmpty == true
                                ? user!.name
                                : (username.isNotEmpty ? username : 'Unknown');
                            final photoUrl = user?.photoUrl ?? '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: displayName,
                                    username: username,
                                    size: 38,
                                    imageUrl: photoUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '@${username.isNotEmpty ? username : '?'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isAdmin ? 'ADMIN' : 'Collaborator',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: isAdmin ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Project Levels Section
              if (project.levels.isNotEmpty) ...[
                const Text(
                  'Project Stages',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ...project.levels.asMap().entries.map((entry) {
                          final index = entry.key;
                          final level = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary.withOpacity(0.12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    level.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Collaborative Workspace',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_clock, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            canEditWorkspace
                                ? 'You can edit this workspace'
                                : 'You have view-only access',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Blocks in idea board: ${project.ideaBoardBlocks.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Workflow levels: ${project.levels.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Collaborators: ${project.collaboratorCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/project/$projectId/workspace'),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.folder_open_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Open Project Workspace', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _CollaboratorAvatar extends StatelessWidget {
  final String userId;
  final String role;

  const _CollaboratorAvatar({
    required this.userId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-8.0, 0),
      child: FutureBuilder<AppUser?>(
        future: UserService.instance.getUserById(userId),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Tooltip(
            message: user?.username.isNotEmpty == true
                ? '@${user!.username} · $role'
                : role,
            child: UserAvatar(
              name: user?.name ?? '',
              username: user?.username,
              size: 28,
              imageUrl: user?.photoUrl,
              color: role == 'admin'
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF7C3AED),
            ),
          );
        },
      ),
    );
  }
}

