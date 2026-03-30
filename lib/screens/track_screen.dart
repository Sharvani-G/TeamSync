import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TrackScreen extends StatelessWidget {
  final String projectId;
  const TrackScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final project = projects.firstWhere((p) => p.id == projectId,
        orElse: () => projects.first);
    final overallProgress = project.levels.isEmpty
        ? 0
        : project.levels.map((l) => l.progress).reduce((a, b) => a + b) ~/
            project.levels.length;

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
          // Stats grid
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
          // Progress by level
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Progress by Level',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 14),
                  ...project.levels.map((level) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(level.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary))),
                                Text('${level.progress}%',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: level.progress / 100,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation(
                                    AppTheme.primary),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Overall progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Overall Progress',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ),
                    Text('$overallProgress%',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: overallProgress / 100,
                    backgroundColor: Colors.white,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // AI report button
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
          const SizedBox(height: 16),
        ],
      ),
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
