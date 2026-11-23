import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _androidPackageName = 'com.example.teamsync';
  static const _resetContinueUrl = 'https://teamsync-6a35e.firebaseapp.com';

  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    final email = _emailController.text.trim();
    final actionCodeSettings = ActionCodeSettings(
      url: _resetContinueUrl,
      handleCodeInApp: false,
      androidPackageName: _androidPackageName,
      androidInstallApp: true,
    );

    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/check-email', arguments: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset link sent successfully.', style: AppTheme.bodyFont(color: Colors.white)),
          backgroundColor: AppTheme.field,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'Unable to send reset email. Please try again.';
      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'user-not-found') {
        message = 'No account found for this email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: AppTheme.bodyFont(color: Colors.white)),
          backgroundColor: AppTheme.field,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock_reset_rounded, color: AppTheme.accent, size: 24),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Forgot password?',
                      style: AppTheme.displayFont(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "No worries, we'll send you instructions to reset your password.",
                      style: AppTheme.bodyFont(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email Address',
                            style: AppTheme.bodyFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Email is required.';
                              final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                              if (!isValid) return 'Please enter a valid email address.';
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'name@example.com',
                              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                              fillColor: AppTheme.groundMuted,
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Send Reset Link',
                                style: AppTheme.bodyFont(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.inkSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Back to sign in',
                              style: AppTheme.bodyFont(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
