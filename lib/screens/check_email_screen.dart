import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class CheckEmailScreen extends StatefulWidget {
  final String email;

  const CheckEmailScreen({super.key, required this.email});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const _androidPackageName = 'com.example.teamsync';
  static const _resetContinueUrl = 'https://teamsync-6a35e.firebaseapp.com';

  bool _isResending = false;

  Future<void> _resendResetEmail() async {
    if (_isResending) return;

    setState(() => _isResending = true);
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: _resetContinueUrl,
        handleCodeInApp: false,
        androidPackageName: _androidPackageName,
        androidInstallApp: true,
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: widget.email,
        actionCodeSettings: actionCodeSettings,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset link resent. Please check your inbox or spam.', style: AppTheme.bodyFont(color: Colors.white)),
          backgroundColor: AppTheme.field,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'Unable to resend reset email. Please try again.';
      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
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
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
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
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.mark_email_read_rounded, color: AppTheme.accent, size: 28),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Check your email',
                      textAlign: TextAlign.center,
                      style: AppTheme.displayFont(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTheme.bodyFont(
                          fontSize: 14,
                          height: 1.5,
                          color: AppTheme.inkSecondary,
                        ),
                        children: [
                          const TextSpan(text: "We've sent a password reset link to\n"),
                          TextSpan(
                            text: widget.email,
                            style: AppTheme.bodyFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink,
                            ),
                          ),
                          const TextSpan(text: "\nClick the link inside to set a new password."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Back to Sign In',
                          style: AppTheme.bodyFont(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the email? ",
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            color: AppTheme.inkSecondary,
                          ),
                        ),
                        _isResending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : GestureDetector(
                                onTap: _resendResetEmail,
                                child: Text(
                                  'Resend',
                                  style: AppTheme.bodyFont(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                      ],
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
