import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/user_profile_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class UsernameRepairScreen extends StatefulWidget {
  final User authUser;
  final AppUser? existingUser;

  const UsernameRepairScreen({
    super.key,
    required this.authUser,
    required this.existingUser,
  });

  @override
  State<UsernameRepairScreen> createState() => _UsernameRepairScreenState();
}

class _UsernameRepairScreenState extends State<UsernameRepairScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.existingUser?.username.trim().isNotEmpty == true
          ? widget.existingUser!.username.trim()
          : '',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await UserProfileService.instance.updateCurrentUserUsername(_usernameController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: AppTheme.bodyFont(color: Colors.white)),
          backgroundColor: AppTheme.field,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.existingUser;

    return Scaffold(
      backgroundColor: AppTheme.ground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.rule, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    name: profile?.name ?? widget.authUser.displayName ?? 'User',
                    username: profile?.username,
                    size: 64,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choose your username',
                    style: AppTheme.displayFont(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account needs a unique username handle before you can collaborate on projects.',
                    style: AppTheme.bodyFont(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.inkSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username',
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                          decoration: InputDecoration(
                            hintText: 'e.g. alex_rivera',
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                            fillColor: AppTheme.groundMuted,
                            filled: true,
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Please enter a username';
                            }
                            if (!UserService.isValidUsernameFormat(text)) {
                              return 'Username must start with a letter and contain 3-20 characters.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save and Continue',
                              style: AppTheme.bodyFont(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
