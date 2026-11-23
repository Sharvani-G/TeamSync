import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class DemoWorkspaceScreen extends StatelessWidget {
  const DemoWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Workspace Preview'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.rule, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demo Workspace',
                            style: AppTheme.displayFont(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Explore layout hierarchy and component specifications.',
                            style: AppTheme.bodyFont(
                              fontSize: 13,
                              color: AppTheme.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Key Metrics',
                style: AppTheme.displayFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _StatTile(icon: Icons.folder_outlined, value: '1', label: 'Active Projects'),
                  _StatTile(icon: Icons.splitscreen_rounded, value: '5', label: 'Board Phases'),
                  _StatTile(icon: Icons.forum_outlined, value: '4', label: 'Channels'),
                  _StatTile(icon: Icons.videocam_outlined, value: '2', label: 'Meetings'),
                ],
              ),
              const SizedBox(height: 24),

              Text(
                'Phases Overview',
                style: AppTheme.displayFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.rule, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Overall Completion', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                        Text('60%', style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        value: 0.6,
                        minHeight: 8,
                        backgroundColor: AppTheme.groundMuted,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '3 of 5 milestone phases completed on schedule.',
                      style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTheme.displayFont(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.inkSecondary),
          ),
        ],
      ),
    );
  }
}
