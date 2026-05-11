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
                onPressed: () => Navigator.pushNamed(context, '/project/$projectId/call'),
              ),
              IconButton(
                icon: const Icon(Icons.phone_outlined),
                onPressed: () => Navigator.pushNamed(context, '/project/$projectId/call'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Room',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Realtime chat is isolated by project, persisted in Firestore, and synchronized across collaborators.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.78),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _RoomChip(icon: Icons.people_outline, label: '${project.collaboratorCount} collaborators'),
                        _RoomChip(icon: Icons.lock_outline, label: project.visibility == 'public' ? 'Public view' : 'Private room'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<int>(
                stream: ProjectService.instance.watchProjectUnreadCount(projectId),
                builder: (context, unreadSnapshot) {
                  final unreadCount = unreadSnapshot.data ?? 0;
                  return ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/project/$projectId/chat/general'),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_bubble_outline),
                        if (unreadCount > 0)
                          Positioned(
                            right: -10,
                            top: -10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: Text(unreadCount > 0 ? 'Open Project Chat ($unreadCount unread)' : 'Open Project Chat'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/project/$projectId/call'),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Start or Join Call'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoomChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoomChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
