import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class IdeaBoardScreen extends StatefulWidget {
  final String projectId;

  const IdeaBoardScreen({super.key, required this.projectId});

  @override
  State<IdeaBoardScreen> createState() => _IdeaBoardScreenState();
}

class _IdeaBoardScreenState extends State<IdeaBoardScreen> {
  late Stream<Project?> _projectStream;

  @override
  void initState() {
    super.initState();
    _projectStream = ProjectService.instance.watchProject(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: _projectStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: const SimpleAppBar(title: 'Idea Board'),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Access Restricted',
                  subtitle: 'You do not have access to this project or the idea board could not be loaded.',
                ),
              ),
            ),
          );
        }

        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: SimpleAppBar(title: 'Idea Board'),
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Project Not Found',
              subtitle: 'The requested project could not be located.',
            ),
          );
        }

        final sections = project.ideaBoardSections.isNotEmpty
            ? project.ideaBoardSections
            : ["Problem Statement", "Research", "Design", "Development", "Testing"];

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: SimpleAppBar(
            title: '${project.title} • Idea Board',
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final sectionTitle = sections[index];

                  return InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/project/${widget.projectId}/idea-board/$sectionTitle',
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.dpInfoBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTheme.labelText.copyWith(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              sectionTitle,
                              style: AppTheme.heading3.copyWith(fontSize: 15.5),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.inkSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
