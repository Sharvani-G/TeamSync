import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_FaqItem>[
      const _FaqItem(
        'How do join requests work?',
        'Project owners can review, accept, or decline collaboration requests directly from the project admin page. Once approved, you are immediately enrolled as a project collaborator and gain access to the Idea Board, Team Channels, and Video Calls.',
      ),
      const _FaqItem(
        'Where do notifications appear?',
        'Notifications appear in your real-time notification inbox and update the badge on the shell navigation bar. You will receive alerts when requests are accepted, meetings are scheduled, or teammates start calls.',
      ),
      const _FaqItem(
        'How do I edit my profile or change privacy?',
        'Navigate to My Profile in the bottom tab bar. Tap the edit icon next to your name to update your display name, or tap Privacy Controls to toggle visibility and active online status.',
      ),
      const _FaqItem(
        'What permissions do collaborators have vs project admins?',
        'Admins manage core project settings, approve/reject incoming join requests, edit required skills, and delete workspaces. Collaborators have full access to create & edit idea board documents, message in chat channels, and join video calls.',
      ),
      const _FaqItem(
        'How do video meetings and calls work in TeamSync?',
        'TeamSync features built-in instant meetings powered by Jitsi Meet alongside direct WebRTC video calls. You can schedule upcoming meetings with set dates and times or launch an instant conference room directly from the Calls workspace.',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: const SimpleAppBar(title: 'Frequently Asked Questions'),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.rule, width: 1),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                iconColor: AppTheme.accent,
                collapsedIconColor: AppTheme.inkSecondary,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(
                  item.question,
                  style: AppTheme.bodyFont(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.ink,
                  ),
                ),
                children: [
                  Text(
                    item.answer,
                    style: AppTheme.bodyFont(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}
