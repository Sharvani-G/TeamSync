import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../services/user_profile_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userProfileService = UserProfileService.instance;
  final _authService = AuthService.instance;
  bool _isUploadingImage = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: SimpleAppBar(title: 'Profile'),
        body: const Center(
          child: Text('Not authenticated'),
        ),
      );
    }

    return Scaffold(
      appBar: SimpleAppBar(title: 'My Profile'),
      body: StreamBuilder<AppUser?>(
        stream: _userProfileService.watchUserProfile(currentUser.uid),
        builder: (context, snapshot) {
          final userProfile = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userProfile == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Profile not found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header with Avatar
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.1),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: userProfile.photoUrl != null && userProfile.photoUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      userProfile.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildAvatarPlaceholder(userProfile.username);
                                      },
                                    ),
                                  )
                                : _buildAvatarPlaceholder(userProfile.username),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingImage ? null : _uploadProfileImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primary,
                                ),
                                child: _isUploadingImage
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userProfile.username,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email ?? 'No email',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Edit Profile Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(
                          currentProfile: userProfile,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Information Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _ProfileInfoRow(
                          label: 'Full Name',
                          value: userProfile.name,
                          icon: Icons.person_outline,
                        ),
                        const Divider(height: 24),
                        _ProfileInfoRow(
                          label: 'Email',
                          value: currentUser.email ?? 'Not set',
                          icon: Icons.email_outlined,
                        ),
                        const Divider(height: 24),
                        _ProfileInfoRow(
                          label: 'Phone',
                          value: userProfile.phone.isNotEmpty ? userProfile.phone : 'Not set',
                          icon: Icons.phone_outlined,
                        ),
                        const Divider(height: 24),
                        _ProfileInfoRow(
                          label: 'Member Since',
                          value: _formatDate(userProfile.createdAt),
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_outlined),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your password regularly'),
                          trailing: const Icon(Icons.arrow_forward_ios_outlined, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Account Status
                Card(
                  color: const Color(0xFFF0FDF4),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outlined,
                          color: Color(0xFF16A34A),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Account Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your account is verified and active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String username) {
    return Container(
      color: AppTheme.primary.withOpacity(0.15),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _uploadProfileImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (image == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
        return;
      }

      // Upload image to Firebase Storage
      final imageUrl = await UserProfileService.instance.uploadProfileImage(
        userId: _authService.currentUser!.uid,
        imagePath: image.path,
      );

      // Update user profile
      if (mounted) {
        await UserProfileService.instance.updateUserProfile(
          photoUrl: imageUrl,
        );

        setState(() {
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
