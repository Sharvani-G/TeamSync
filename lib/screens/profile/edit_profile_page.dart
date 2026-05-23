import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/user_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class EditProfilePage extends StatefulWidget {
  final AppUser currentProfile;

  const EditProfilePage({super.key, required this.currentProfile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentProfile.name);
    _phoneController = TextEditingController(text: widget.currentProfile.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: 'Edit Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: AppTheme.danger,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Full Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Phone Number Field
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
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
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Full name cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await UserProfileService.instance.updateUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }
}
