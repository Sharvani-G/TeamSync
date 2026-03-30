import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProjectOverviewScreen extends StatelessWidget {
  final String projectId;
  const ProjectOverviewScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final project = projects.firstWhere((p) => p.id == projectId,
        orElse: () => projects.first);

    return Scaffold(
      appBar: SimpleAppBar(
        title: project.title,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: List.generate(
                project.collaborators.clamp(0, 4),
                (i) => Transform.translate(
                  offset: Offset(-i * 8.0, 0),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: [
                        const Color(0xFF3B82F6),
                        const Color(0xFF7C3AED),
                        const Color(0xFF10B981),
                        const Color(0xFFF59E0B),
                      ][i % 4],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        String.fromCharCode(65 + i),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _NavCard(
            icon: Icons.lightbulb_outline,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
            title: 'Idea Board',
            subtitle: 'Organize ideas and documents by project stages',
            onTap: () =>
                Navigator.pushNamed(context, '/project/$projectId/idea-board'),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.bar_chart_rounded,
            gradientColors: const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
            title: 'Track',
            subtitle: 'Monitor progress and view analytics',
            onTap: () =>
                Navigator.pushNamed(context, '/project/$projectId/track'),
          ),
          const SizedBox(height: 12),
          _NavCard(
            icon: Icons.chat_bubble_outline,
            gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
            title: 'Chat',
            subtitle: 'Communicate with your team',
            onTap: () =>
                Navigator.pushNamed(context, '/project/$projectId/chat'),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
