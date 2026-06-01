import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AboutCard(
            title: 'TeamSync',
            body: 'A collaborative project workspace for teams to manage ideas, chats, meetings, and join requests in one place.',
          ),
          SizedBox(height: 12),
          _AboutCard(
            title: 'What changed',
            body: 'Notifications now flow through a root-level Firestore collection and the app shell exposes the new profile and settings surfaces.',
          ),
          SizedBox(height: 12),
          _AboutCard(
            title: 'Support',
            body: 'If something looks wrong, open Settings, review your privacy preferences, and use the notification inbox to inspect recent activity.',
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final String title;
  final String body;

  const _AboutCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: Colors.white70, height: 1.45)),
          ],
        ),
      ),
    );
  }
}