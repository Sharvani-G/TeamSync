import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_FaqItem>[
      const _FaqItem(
        'How do join requests work?',
        'Project owners can accept or reject requests from the project page. Approved users are added as collaborators immediately.',
      ),
      const _FaqItem(
        'Where do notifications appear?',
        'Notifications are stored in the inbox and mirrored as unread badges in the shell.',
      ),
      const _FaqItem(
        'How do I change my profile?',
        'Open My Profile, tap edit name, or go into Settings for privacy controls.',
      ),
      const _FaqItem(
        'How do I log out?',
        'Use the Logout button from My Profile. Your session is cleared locally.',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            color: const Color(0xFF111827),
            child: ExpansionTile(
              iconColor: Colors.white70,
              collapsedIconColor: Colors.white70,
              title: Text(item.question, style: const TextStyle(color: Colors.white)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(item.answer, style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
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