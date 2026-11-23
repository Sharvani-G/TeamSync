import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'idea_board_screen.dart';
import 'chat_home_screen.dart';
import 'calls_screen.dart';
import 'track_screen.dart';
import 'project_admin_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final String projectId;
  final int initialTabIndex;

  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    this.initialTabIndex = 0,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  bool _hasAutoNavigated = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatHomeScreen(projectId: widget.projectId)),
          );
        }
      });
    } else if (widget.initialTabIndex == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CallsScreen(projectId: widget.projectId)),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: SimpleAppBar(title: 'Project Workspace'),
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Project not found',
              subtitle: 'This project might not exist or access is restricted.',
            ),
          );
        }

        if (!_hasAutoNavigated) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          if (widget.initialTabIndex == 3 || (args != null && args['type'] == 'join_request')) {
            _hasAutoNavigated = true;
            final currentUser = FirebaseAuth.instance.currentUser;
            final isAdmin = project.createdBy == currentUser?.uid;
            if (isAdmin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectAdminScreen(
                        projectId: widget.projectId,
                        project: project,
                        initialTab: 'join_requests',
                      ),
                    ),
                  );
                }
              });
            }
          }
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final role = getMyRole(
          currentUid: currentUser?.uid ?? '',
          adminUid: project.createdBy,
          collaboratorUids: project.collaborators.keys.toList(),
        );
        final isAdmin = role == ProjectRole.admin;

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: project.title,
            actions: [
              IconButton(
                tooltip: 'Track Progress',
                icon: const Icon(Icons.insights_outlined, color: AppTheme.ink, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackScreen(projectId: widget.projectId),
                    ),
                  );
                },
              ),
              if (isAdmin)
                IconButton(
                  tooltip: 'Project Administration',
                  icon: const Icon(Icons.settings_outlined, color: AppTheme.ink, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectAdminScreen(projectId: widget.projectId, project: project),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview Banner
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.panel,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                          border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0616191F),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.dpInfoBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.folder_open, color: AppTheme.accent, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(project.displayTitle, style: AppTheme.heading3),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${project.safeCollaboratorCount} collaborators • ${project.visibility.toUpperCase()}',
                                    style: AppTheme.metadataText,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      const SectionHeader(title: 'Workspaces & Modules'),
                      const SizedBox(height: 10),

                      // Module 1: Idea Board
                      _WorkspaceModuleCard(
                        title: 'Idea Board',
                        subtitle: 'Structured milestone levels, research documents & file attachments',
                        icon: Icons.lightbulb_outline,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => IdeaBoardScreen(projectId: widget.projectId)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Module 2: Chat
                      _WorkspaceModuleCard(
                        title: 'Team Channels',
                        subtitle: 'Real-time project discussions, media attachments & announcements',
                        icon: Icons.chat_bubble_outline,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatHomeScreen(projectId: widget.projectId)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Module 3: Calls
                      _WorkspaceModuleCard(
                        title: 'Video Meetings & Calls',
                        subtitle: 'Instant video sessions, scheduled conferences & agenda tracking',
                        icon: Icons.videocam_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CallsScreen(projectId: widget.projectId)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Module 4: Track Progress
                      _WorkspaceModuleCard(
                        title: 'Progress Tracking',
                        subtitle: 'Task completion metrics, idea additions & collaboration statistics',
                        icon: Icons.track_changes_outlined,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => TrackScreen(projectId: widget.projectId)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _WorkspaceModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
          border: Border.all(color: AppTheme.rule, width: AppTheme.borderHairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0616191F),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.dpInfoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
              ),
              child: Icon(icon, size: 24, color: AppTheme.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.heading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.inkSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.inkSecondary),
          ],
        ),
      ),
    );
  }
}
