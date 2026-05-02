import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/user_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showAction(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label tapped'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showAction(context, 'Settings'),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: StreamBuilder<AppUser>(
        stream: UserProfileService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data ?? currentUser;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user.name,
                      size: 54,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ProfileMenuItem(
                icon: Icons.person_outline,
                label: 'My Profile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyProfileDetailsScreen(),
                    ),
                  );
                },
              ),
              _ProfileMenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => _showAction(context, 'Settings'),
              ),
              _ProfileMenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () => _showAction(context, 'Notifications'),
              ),
              _ProfileMenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Transaction History',
                onTap: () => _showAction(context, 'Transaction History'),
              ),
              _ProfileMenuItem(
                icon: Icons.help_outline,
                label: 'FAQ',
                onTap: () => _showAction(context, 'FAQ'),
              ),
              _ProfileMenuItem(
                icon: Icons.info_outline,
                label: 'About App',
                onTap: () => _showAction(context, 'About App'),
              ),
              const SizedBox(height: 18),
              _ProfileMenuItem(
                icon: Icons.logout,
                label: 'Logout',
                iconColor: AppTheme.danger,
                labelColor: AppTheme.danger,
                onTap: () => _showAction(context, 'Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyProfileDetailsScreen extends StatefulWidget {
  const MyProfileDetailsScreen({super.key});

  @override
  State<MyProfileDetailsScreen> createState() => _MyProfileDetailsScreenState();
}

class _MyProfileDetailsScreenState extends State<MyProfileDetailsScreen> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  bool _isInitialized = false;
  bool _isPhotoVisible = true;
  bool _hasCustomPhoto = true;
  String _gender = 'Male';

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _syncUser(AppUser user) {
    if (_isInitialized) return;

    _nameController.text = user.name;
    _emailController.text = user.email;
    _mobileController.text = '';
    _dobController.text = '7 July 2002';
    _weightController.text = '64';
    _heightController.text = '175,5';
    _isInitialized = true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickDob() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(2002, 7, 7),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    setState(() {
      _dobController.text = '${selected.day} ${_monthName(selected.month)} ${selected.year}';
    });
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showMessage('Please enter a full name');
      return;
    }

    await UserProfileService.instance.updateCurrentUserName(newName);

    if (!mounted) return;
    _showMessage('Profile saved');
  }

  void _updatePhoto() {
    setState(() {
      _hasCustomPhoto = true;
      _isPhotoVisible = true;
    });
    _showMessage('Upload photo action is active');
  }

  void _deletePhoto() {
    setState(() {
      _hasCustomPhoto = false;
      _isPhotoVisible = true;
    });
    _showMessage('Delete photo action is active');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: StreamBuilder<AppUser>(
        stream: UserProfileService.instance.watchCurrentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data ?? currentUser;
          _syncUser(user);

          final avatarLabel = _isPhotoVisible
              ? (_hasCustomPhoto ? user.name : 'No photo')
              : 'Hidden';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isPhotoVisible
                                ? const LinearGradient(
                                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFE5E7EB), Color(0xFFF3F4F6)],
                                  ),
                          ),
                          child: Center(
                            child: _isPhotoVisible
                                ? (_hasCustomPhoto
                                    ? UserAvatar(
                                        name: user.name,
                                        size: 64,
                                        color: Colors.white,
                                      )
                                    : const Icon(
                                        Icons.person_outline,
                                        size: 34,
                                        color: Colors.white,
                                      ))
                                : const Icon(
                                    Icons.visibility_off_outlined,
                                    size: 30,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_outlined, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _ActionChipButton(
                          icon: Icons.photo_camera_outlined,
                          label: 'Upload Photo',
                          onTap: _updatePhoto,
                        ),
                        _ActionChipButton(
                          icon: Icons.delete_outline,
                          label: 'Delete Photo',
                          onTap: _deletePhoto,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      avatarLabel,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SectionHeader(title: 'Basic Detail'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  suffixIcon: Icon(Icons.keyboard_arrow_down),
                ),
              ),
              const SizedBox(height: 12),
              _GenderToggleRow(
                value: _gender,
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 18),
              _SectionHeader(title: 'Contact Detail'),
              const SizedBox(height: 8),
              TextField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
              const SizedBox(height: 18),
              _SectionHeader(title: 'Personal Detail'),
              const SizedBox(height: 8),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _GenderToggleRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _GenderToggleRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderOption(
            label: 'Male',
            selected: value == 'Male',
            onTap: () => onChanged('Male'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderOption(
            label: 'Female',
            selected: value == 'Female',
            onTap: () => onChanged('Female'),
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppTheme.primary : Colors.grey[400],
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: iconColor ?? Colors.grey[700],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: labelColor ?? AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}