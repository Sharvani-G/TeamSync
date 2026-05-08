import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/project_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChatHomeScreen extends StatelessWidget {
  final String projectId;
  const ChatHomeScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: ProjectService.instance.watchProject(projectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final project = snapshot.data;
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        return Scaffold(
          appBar: SimpleAppBar(
            title: project.title,
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Video call started'),
                        behavior: SnackBarBehavior.floating),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Voice call started'),
                        behavior: SnackBarBehavior.floating),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader(title: 'Channels'),
              // Mock channels since they are not fully in Firebase yet
              ...[
                {'id': 'general', 'name': 'general'},
                {'id': 'announcements', 'name': 'announcements'},
                {'id': 'design', 'name': 'design'},
              ].map((channel) {
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading:
                      const Icon(Icons.tag, size: 18, color: AppTheme.textMuted),
                  title: Text(
                    channel['name']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () => Navigator.pushNamed(
                      context, '/project/$projectId/chat/${channel['id']}'),
                  hoverColor: const Color(0xFFF3F4F6),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
