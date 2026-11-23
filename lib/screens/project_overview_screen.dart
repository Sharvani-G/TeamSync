import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
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
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: const SimpleAppBar(title: 'Project Details'),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: 'Project not found',
              subtitle: 'This project might have been deleted or moved.',
            ),
          );
        }

        final currentUser = FirebaseAuth.instance.currentUser;
        final isAdmin = currentUser != null && project.isAdmin(currentUser.uid);
        final memberIds = <String>{project.createdBy, ...project.collaborators.keys}.toList();

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: project.title,
            actions: [
              if (isAdmin)
                IconButton(
                  tooltip: 'Project Settings',
                  icon: const Icon(Icons.settings_outlined, color: AppTheme.ink, size: 20),
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
                      // Section 1: Overview
                      const SectionHeader(title: 'Project Overview'),
                      const SizedBox(height: 8),
                      _OverviewCard(
                        children: [
                          _OverviewRow(
                            label: 'Description',
                            value: project.description,
                            isMultiline: true,
                          ),
                          const Divider(color: AppTheme.rule, height: 1),
                          _OverviewRow(
                            label: 'Visibility',
                            value: project.visibility.toUpperCase(),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: project.isPrivate ? AppTheme.groundMuted : AppColors.dpSuccessBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: project.isPrivate ? AppTheme.rule : AppColors.dpSuccess.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                project.visibility.toUpperCase(),
                                style: AppTheme.labelText.copyWith(
                                  color: project.isPrivate ? AppTheme.inkSecondary : AppColors.dpSuccess,
                                ),
                              ),
                            ),
                          ),
                          const Divider(color: AppTheme.rule, height: 1),
                          _OverviewRow(
                            label: 'Created Date',
                            value: DateFormat.yMMMd().format(project.createdAt),
                          ),
                          if (project.contactEmail.isNotEmpty) ...[
                            const Divider(color: AppTheme.rule, height: 1),
                            _OverviewRow(
                              label: 'Contact Email',
                              value: project.contactEmail,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Section 2: Collaborators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SectionHeader(title: 'Collaborators'),
                          Text(
                            '${memberIds.length} members',
                            style: AppTheme.metadataText,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, AppUser>>(
                        future: UserService.instance.getUsersByIds(memberIds),
                        builder: (context, memberSnapshot) {
                          final members = memberSnapshot.data ?? {};
                          return _OverviewCard(
                            padding: EdgeInsets.zero,
                            children: memberIds.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final userId = entry.value;
                              final user = members[userId];
                              final isOwner = project.isAdmin(userId);
                              final displayName = user?.name ?? 'Unknown User';
                              final isLast = idx == memberIds.length - 1;

                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                          name: displayName,
                                          username: user?.username,
                                          size: 36,
                                          imageUrl: user?.photoUrl,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: AppTheme.heading3.copyWith(fontSize: 14.5),
                                              ),
                                              if (user?.username != null && user!.username.isNotEmpty)
                                                Text(
                                                  '@${user.username}',
                                                  style: AppTheme.metadataText,
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isOwner)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.dpInfoBg,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                                            ),
                                            child: Text(
                                              'ADMIN',
                                              style: AppTheme.labelText.copyWith(
                                                color: AppTheme.accent,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast) const Divider(color: AppTheme.rule, height: 1),
                                ],
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 36),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/project/$projectId/workspace'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Open Project Workspace',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

class _OverviewCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const _OverviewCard({
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMultiline;
  final Widget? trailing;

  const _OverviewRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.labelText.copyWith(color: AppTheme.inkSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w500,
                height: isMultiline ? 1.45 : null,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
