import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isChanging = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: 'Change Password'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: const Color(0xFFF0FDF4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use a strong password with letters, numbers, and symbols',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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

            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_errorMessage == null && _successMessage == null)
              const SizedBox(height: 16),

            // Current Password
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Current Password',
                hintText: 'Enter your current password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showCurrentPassword = !_showCurrentPassword;
                    });
                  },
                  child: Icon(
                    _showCurrentPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isChanging,
            ),
            const SizedBox(height: 16),

            // New Password
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                hintText: 'Enter your new password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showNewPassword = !_showNewPassword;
                    });
                  },
                  child: Icon(
                    _showNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isChanging,
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your new password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                  child: Icon(
                    _showConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isChanging,
            ),
            const SizedBox(height: 24),

            // Change Password Button
            ElevatedButton.icon(
              onPressed: _isChanging ? null : _changePassword,
              icon: _isChanging
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
              label: Text(_isChanging ? 'Changing...' : 'Change Password'),
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

  Future<void> _changePassword() async {
    // Validation
    if (_currentPasswordController.text.isEmpty) {
      _setError('Current password is required');
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      _setError('New password is required');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _setError('Password must be at least 6 characters');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _setError('Passwords do not match');
      return;
    }

    if (_newPasswordController.text == _currentPasswordController.text) {
      _setError('New password must be different from current password');
      return;
    }

    setState(() {
      _isChanging = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _setError('No authenticated user found');
        return;
      }

      // Reauthenticate with current password
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        ),
      );

      // Update password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        setState(() {
          _isChanging = false;
          _successMessage = 'Password changed successfully';
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });

        // Show success and navigate back after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to change password';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = 'New password is too weak';
      } else if (e.code == 'user-mismatch') {
        errorMessage = 'User mismatch error';
      }
      _setError(errorMessage);
    } catch (e) {
      _setError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChanging = false;
        });
      }
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
      _isChanging = false;
    });
  }
}
