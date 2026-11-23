import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/settings_service.dart';
import '../../services/user_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto(AppUser user) async {
    try {
      final result = await picker.FilePicker.pickFiles(
        type: picker.FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      setState(() => _isUploadingPhoto = true);

      final photoUrl = await FileService.instance.uploadProfilePhoto(
        userId: user.id,
        file: file,
      );

      await UserProfileService.instance.updateCurrentUserPhoto(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.rule),
        ),
        title: Text(
          'Log out of TeamSync',
          style: AppTheme.displayFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        content: Text(
          'Are you sure you want to log out? You will need to sign in again to access your projects.',
          style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.bodyFont(color: AppTheme.inkSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Log out', style: AppTheme.bodyFont(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
          backgroundColor: AppTheme.panel,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.rule),
          ),
          title: Text(
            'Edit display name',
            style: AppTheme.displayFont(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
            decoration: InputDecoration(
              labelText: 'Full name',
              labelStyle: AppTheme.bodyFont(fontSize: 13, color: AppTheme.inkSecondary),
              fillColor: AppTheme.groundMuted,
              filled: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: AppTheme.bodyFont(color: AppTheme.inkSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Save', style: AppTheme.bodyFont(fontWeight: FontWeight.w600, color: Colors.white)),
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
      backgroundColor: AppTheme.ground,
      appBar: SimpleAppBar(
        title: 'My Profile',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.inkSecondary),
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
            return Center(
              child: Text(
                'User profile not found',
                style: AppTheme.bodyFont(color: AppTheme.inkSecondary),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Hero Profile Card
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
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : () => _pickAndUploadPhoto(user),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          UserAvatar(
                            name: user.name,
                            username: user.username,
                            imageUrl: user.photoUrl,
                            size: 64,
                            color: AppTheme.accent,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.panel, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name.isNotEmpty ? user.name : 'TeamSync User',
                                  style: AppTheme.displayFont(
                                    color: AppTheme.ink,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _editName(context, user),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user.email,
                            style: AppTheme.bodyFont(
                              color: AppTheme.inkSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.groundMuted,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.rule),
                            ),
                            child: Text(
                              '@${user.username}',
                              style: AppTheme.bodyFont(
                                color: AppTheme.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Navigation & Quick Settings
              Text(
                'Account & Preferences',
                style: AppTheme.displayFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),

              _ActionCard(
                icon: Icons.notifications_outlined,
                title: 'Notification Inbox',
                subtitle: 'Review recent project invitations and alerts',
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
              _ActionCard(
                icon: Icons.history_rounded,
                title: 'Activity & History',
                subtitle: 'View your submitted join requests and project actions',
                onTap: () => Navigator.pushNamed(context, '/transactions'),
              ),
              _ActionCard(
                icon: Icons.tune_rounded,
                title: 'Settings',
                subtitle: 'Push alerts and preference toggles',
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              _ActionCard(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy Controls',
                subtitle: 'Online presence and collaborator visibility',
                onTap: () => Navigator.pushNamed(context, '/settings/privacy'),
              ),

              const SizedBox(height: 16),
              Text(
                'Support & About',
                style: AppTheme.displayFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),

              _ActionCard(
                icon: Icons.help_outline_rounded,
                title: 'Frequently Asked Questions',
                subtitle: 'Find answers about projects, roles, and tools',
                onTap: () => Navigator.pushNamed(context, '/faq'),
              ),
              _ActionCard(
                icon: Icons.info_outline_rounded,
                title: 'About TeamSync',
                subtitle: 'Version details, mission, and architecture',
                onTap: () => Navigator.pushNamed(context, '/about'),
              ),

              const SizedBox(height: 16),
              // Private profile switch card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.rule, width: 1),
                ),
                child: ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.instance.profilePrivate,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      value: value,
                      activeColor: AppTheme.accent,
                      onChanged: SettingsService.instance.setProfilePrivate,
                      title: Text(
                        'Private Profile',
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Hide contact information from non-collaborators',
                        style: AppTheme.bodyFont(
                          fontSize: 12,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.danger),
                  label: Text(
                    'Log Out',
                    style: AppTheme.bodyFont(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.danger,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    backgroundColor: const Color(0xFFFFF1F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.rule, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
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
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTheme.bodyFont(
                          fontSize: 12,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.inkSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
