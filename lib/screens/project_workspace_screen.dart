import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'idea_board_screen.dart';
import 'chat_home_screen.dart';
import 'project_call_screen.dart';

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
  late int _currentIndex = widget.initialTabIndex.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            body: Center(child: Text('Project not found')),
          );
        }

        final sections = [
          _WorkspaceSection(
            label: 'Idea Board',
            icon: Icons.space_dashboard_outlined,
          ),
          _WorkspaceSection(
            label: 'Chat',
            icon: Icons.chat_bubble_outline,
          ),
          _WorkspaceSection(
            label: 'Calls',
            icon: Icons.call_outlined,
          ),
        ];

        final screens = [
          IdeaBoardScreen(projectId: widget.projectId),
          ChatHomeScreen(projectId: widget.projectId),
          ProjectCallScreen(projectId: widget.projectId),
        ];

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: AppTheme.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(sections.length, (index) {
                          final section = sections[index];
                          final selected = _currentIndex == index;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 6,
                              ),
                              child: GestureDetector(
                                    onTap: () => setState(() => _currentIndex = index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: selected ? AppTheme.primaryGradientStart : const Color(0xFFF6F7FB),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: selected ? AppTheme.primaryGradientStart : AppTheme.border,
                                          width: selected ? 0 : 1,
                                        ),
                                        boxShadow: selected
                                            ? [BoxShadow(color: AppTheme.primaryGradientStart.withOpacity(0.18), blurRadius: 14, offset: const Offset(0, 8))]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            section.icon,
                                            size: 18,
                                            color: selected ? Colors.white : AppTheme.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              section.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: selected ? Colors.white : AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_currentIndex),
                      child: screens[_currentIndex],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceSection {
  final String label;
  final IconData icon;

  const _WorkspaceSection({required this.label, required this.icon});
}