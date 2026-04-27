import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

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
          content: Text(
            'Reset link sent again. Please check Inbox or Spam.',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          content: Text(message, style: GoogleFonts.dmSans()),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  size: 42,
                  color: Color(0xFFFF2D55),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Check your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'We\'ve sent a password reset link to\n${widget.email}\nPlease open it to reset your password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  height: 1.7,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Didn\'t get it? Check Spam/Promotions and tap Resend.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isResending ? null : _resendResetEmail,
                child: _isResending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Resend Link',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF2D55),
                        ),
                      ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5C78), Color(0xFFFF2D55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withOpacity(0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Back to Login',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}
