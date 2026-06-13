import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/user_profile_service.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.signOutAndClearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _editName(BuildContext context, AppUser user) async {
    final controller = TextEditingController(text: user.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;
    await UserProfileService.instance.updateCurrentUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: StreamBuilder<AppUser?>(
        stream: UserProfileService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(
              child: Text('User not found', style: TextStyle(color: Colors.white)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(user.email, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('@${user.username}', style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ActionCard(
                icon: Icons.edit_outlined,
                title: 'Edit profile name',
                subtitle: 'Update the display name used across TeamSync.',
                onTap: () => _editName(context, user),
              ),
              _ActionCard(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Review your notification preferences and inbox.',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              _ActionCard(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Alert controls and notification settings.',
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              _ActionCard(
                icon: Icons.help_outline,
                title: 'FAQ',
                subtitle: 'Answers to common TeamSync questions.',
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
              _ActionCard(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'App version, mission, and support details.',
                onTap: () => Navigator.pushNamed(context, '/about'),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: SettingsService.instance.profilePrivate,
                builder: (context, value, _) {
                  return SwitchListTile(
                    value: value,
                    onChanged: SettingsService.instance.setProfilePrivate,
                    title: const Text(
                      'Private profile',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Hide contact details from non-collaborators',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF111827),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF60A5FA)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      ),
    );
  }
}