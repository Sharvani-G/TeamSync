import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'About TeamSync'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // App Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.rule, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.sync_alt_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TeamSync',
                          style: AppTheme.displayFont(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Version 2.0.0 • SaaS Production Edition',
                          style: AppTheme.bodyFont(
                            fontSize: 12,
                            color: AppTheme.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'A cohesive, high-performance collaborative project management platform designed for student teams, startup creators, and agile builders to manage ideas, real-time messaging, video meetings, and deliverable milestones in one unified workspace.',
                  style: AppTheme.bodyFont(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _AboutCard(
            title: 'Unified Workspaces',
            body: 'Manage team ideation through structured document-based Idea Boards, synchronized live channel communications, instant video meetings, and milestone progress tracking.',
            icon: Icons.dashboard_outlined,
          ),
          const SizedBox(height: 10),

          _AboutCard(
            title: 'Real-Time Architecture',
            body: 'Integrated with Cloud Firestore snapshots for reactive state synchronization, Firebase Authentication for secure identity, and live WebRTC + Jitsi Meet for low-latency conferencing.',
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: 10),

          _AboutCard(
            title: 'Collaboration & Discovery',
            body: 'Explore open projects across the platform, filter by skill sets, submit detailed join requests with your portfolio, and coordinate team roles effortlessly.',
            icon: Icons.groups_outlined,
          ),
          const SizedBox(height: 20),

          // Tech Stack Section
          Text(
            'Technology Stack',
            style: AppTheme.displayFont(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.inkSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TechChip('Flutter Web & Mobile'),
              _TechChip('Firebase Auth'),
              _TechChip('Cloud Firestore'),
              _TechChip('Cloudinary CDN'),
              _TechChip('WebRTC Signaling'),
              _TechChip('Jitsi Meet Conferencing'),
              _TechChip('Host Grotesk Typography'),
              _TechChip('Instrument Sans UI'),
            ],
          ),
          const SizedBox(height: 28),

          Center(
            child: Text(
              'TeamSync • Built for seamless collaborative development',
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont(
                fontSize: 12,
                color: AppTheme.inkSecondary.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _AboutCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rule, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: AppTheme.accent, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTheme.bodyFont(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;

  const _TechChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.groundMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.rule),
      ),
      child: Text(
        label,
        style: AppTheme.bodyFont(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}
