import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class TrackScreen extends StatelessWidget {
  final String projectId;
  const TrackScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: SimpleAppBar(title: 'Track Progress'),
            body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            backgroundColor: AppTheme.ground,
            appBar: SimpleAppBar(title: 'Track Progress'),
            body: EmptyState(
              icon: Icons.error_outline,
              title: 'Project Not Found',
              subtitle: 'Progress data could not be loaded for this project.',
            ),
          );
        }

        final project = snapshot.data!;
        final orderedLevels = [...project.levels]..sort((a, b) => a.order.compareTo(b.order));
        final overallProgress = orderedLevels.isEmpty
            ? 0
            : orderedLevels.fold<int>(0, (sum, level) => sum + level.percentage) ~/ orderedLevels.length;

        final stats = [
          _Stat(
            icon: Icons.check_circle_outline,
            label: 'Tasks Completed',
            value: '${project.stats.tasksCompleted}',
            color: AppColors.dpSuccess,
            bg: AppColors.dpSuccessBg,
          ),
          _Stat(
            icon: Icons.lightbulb_outline,
            label: 'Ideas Added',
            value: '${project.stats.ideasAdded}',
            color: AppColors.dpWarning,
            bg: AppColors.dpWarningBg,
          ),
          _Stat(
            icon: Icons.videocam_outlined,
            label: 'Meetings Conducted',
            value: '${project.stats.meetingsConducted}',
            color: AppTheme.accent,
            bg: AppColors.dpInfoBg,
          ),
          _Stat(
            icon: Icons.chat_bubble_outline,
            label: 'Messages Sent',
            value: '${project.stats.messagesSent}',
            color: const Color(0xFF2563EB),
            bg: AppColors.dpInfoBg,
          ),
        ];

        return Scaffold(
          backgroundColor: AppTheme.ground,
          appBar: const SimpleAppBar(title: 'Track Progress'),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  // Stat Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width < 480 ? 2 : 4;
                      final childAspectRatio = width < 480 ? 1.3 : 1.25;

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: childAspectRatio,
                        children: stats.map((s) => _StatCard(stat: s)).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Overall Progress Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overall Progress', style: AppTheme.heading3),
                            Text(
                              '$overallProgress% complete',
                              style: AppTheme.heading3.copyWith(color: AppTheme.accent, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: overallProgress / 100,
                            minHeight: 8,
                            backgroundColor: AppTheme.groundMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Project Levels
                  Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Phases & Milestones', style: AppTheme.heading3),
                        const SizedBox(height: 16),
                        if (orderedLevels.isEmpty)
                          Text(
                            'No phase levels configured yet.',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.inkSecondary),
                          )
                        else
                          ...orderedLevels.map(
                            (level) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.groundMuted,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(color: AppTheme.rule),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: level.completed ? AppColors.dpSuccessBg : AppColors.dpInfoBg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: level.completed
                                                  ? AppColors.dpSuccess.withOpacity(0.3)
                                                  : AppTheme.accent.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${level.order}',
                                              style: TextStyle(
                                                color: level.completed ? AppColors.dpSuccess : AppTheme.accent,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            level.title,
                                            style: AppTheme.heading3.copyWith(fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: level.completed ? AppColors.dpSuccessBg : AppTheme.panel,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: level.completed ? AppColors.dpSuccess.withOpacity(0.3) : AppTheme.rule,
                                            ),
                                          ),
                                          child: Text(
                                            level.completed ? 'Completed' : '${level.percentage}%',
                                            style: AppTheme.labelText.copyWith(
                                              color: level.completed ? AppColors.dpSuccess : AppTheme.accent,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: level.percentage / 100,
                                        minHeight: 6,
                                        backgroundColor: AppTheme.panel,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          level.completed ? AppColors.dpSuccess : AppTheme.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // AI Report CTA
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/project/$projectId/ai-report'),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Generate Weekly AI Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: stat.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat.icon, color: stat.color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            stat.value,
            style: AppTheme.display2.copyWith(fontSize: 22, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: AppTheme.metadataText.copyWith(fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
