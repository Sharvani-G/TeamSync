import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

const weeklyReportSummary =
    'This week, the team has successfully completed the initial architecture phase. Backend services are now integrated with Firebase, and the UI is being migrated to use real-time data streams. Collaborator management is fully functional.';
const weeklyReportHighlights = [
  'Switched from mock data to Firestore real-time streams',
  'Implemented username-based collaborator search',
  'Set up secure Firestore rules for projects and requests',
  'Integrated Firebase Storage for portfolio uploads',
];

class AIReportScreen extends StatelessWidget {
  const AIReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'AI Weekly Report'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // AI Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.dpInfoBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'AI Generated Project Summary',
                        style: AppTheme.labelText.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Report Card
              Container(
                padding: const EdgeInsets.all(22),
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
                    Text('Executive Summary', style: AppTheme.heading2),
                    const SizedBox(height: 10),
                    Text(
                      weeklyReportSummary,
                      style: AppTheme.bodyLarge.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: AppTheme.rule),
                    const SizedBox(height: 18),
                    Text('Key Milestones & Highlights', style: AppTheme.heading3),
                    const SizedBox(height: 12),
                    ...weeklyReportHighlights.map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                h,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.ink,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Copy Button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: weeklyReportSummary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied to clipboard'),
                        backgroundColor: AppColors.dpSuccess,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy Summary to Clipboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share Report'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text('Email to Team'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Synthesized from milestone commits, idea boards, and collaboration logs',
                  textAlign: TextAlign.center,
                  style: AppTheme.metadataText,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
