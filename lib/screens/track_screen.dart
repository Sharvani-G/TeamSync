import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TrackScreen extends StatelessWidget {
  final String projectId;
  const TrackScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: const SimpleAppBar(title: 'Track Progress'),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle error or no project found
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: const SimpleAppBar(title: 'Track Progress'),
            body: const Center(
              child: Text('Project not found'),
            ),
          );
        }

        final project = snapshot.data!;
        final orderedLevels = [...project.levels]
          ..sort((a, b) => a.order.compareTo(b.order));
        final overallProgress = orderedLevels.isEmpty
            ? 0
            : orderedLevels.fold<int>(0, (sum, level) => sum + level.percentage) ~/ orderedLevels.length;

        final stats = [
          _Stat(
              icon: Icons.check_circle_outline,
              label: 'Tasks Completed',
              value: '${project.stats.tasksCompleted}',
              color: const Color(0xFF16A34A),
              bg: const Color(0xFFDCFCE7)),
          _Stat(
              icon: Icons.lightbulb_outline,
              label: 'Ideas Added',
              value: '${project.stats.ideasAdded}',
              color: const Color(0xFFCA8A04),
              bg: const Color(0xFFFEF9C3)),
          _Stat(
              icon: Icons.people_outline,
              label: 'Meetings Conducted',
              value: '${project.stats.meetingsConducted}',
              color: AppTheme.primary,
              bg: const Color(0xFFEFF6FF)),
          _Stat(
              icon: Icons.chat_bubble_outline,
              label: 'Messages Sent',
              value: '${project.stats.messagesSent}',
              color: AppTheme.secondary,
              bg: const Color(0xFFF5F3FF)),
        ];

        return Scaffold(
          appBar: const SimpleAppBar(title: 'Track Progress'),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: stats.map((s) => _StatCard(stat: s)).toList(),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: overallProgress / 100,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$overallProgress% complete',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Levels',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (orderedLevels.isEmpty)
                        const Text(
                          'No levels have been created yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        )
                      else
                        ...orderedLevels.map((level) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: level.completed
                                              ? const Color(0xFFDCFCE7)
                                              : AppTheme.primary.withOpacity(0.12),
                                          foregroundColor: level.completed
                                              ? const Color(0xFF15803D)
                                              : AppTheme.primary,
                                          child: Text('${level.order}'),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                level.title,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Updated ${level.updatedAt != null ? '${level.updatedAt!.month}/${level.updatedAt!.day}/${level.updatedAt!.year}' : '${level.createdAt.month}/${level.createdAt.day}/${level.createdAt.year}'}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: level.completed ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            level.completed ? 'Completed' : '${level.percentage}%',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: level.completed ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: level.percentage / 100,
                                        minHeight: 8,
                                        backgroundColor: const Color(0xFFE5E7EB),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          level.completed ? const Color(0xFF16A34A) : AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/project/$projectId/ai-report'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate Weekly AI Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
              ),
            ],
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
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      required this.bg});
}

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: stat.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(stat.icon, color: stat.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(stat.value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(stat.label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
