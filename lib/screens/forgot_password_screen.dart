import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final TextEditingController _codeController;
  bool _isCodeValid = true;
  bool _isResendLocked = true;
  int _resendSeconds = 30;
  late String _verificationCode;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _codeController = TextEditingController();
    _verificationCode = '123456';
    _startResendTimer();
  }

  void _startResendTimer() {
    _isResendLocked = true;
    _resendSeconds = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendSeconds -= 1;
      });
      return _resendSeconds > 0;
    }).then((_) {
      if (!mounted) return;
      setState(() {
        _isResendLocked = false;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _verifyCode() {
    final text = _codeController.text.trim();
    setState(() {
      _isCodeValid = text == _verificationCode;
    });
    if (_isCodeValid) {
      Navigator.pushReplacementNamed(context, '/reset-password');
    }
  }

  void _resendCode() {
    if (_isResendLocked) return;
    setState(() {
      _isCodeValid = true;
      _codeController.clear();
      _verificationCode = '123456';
      _startResendTimer();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'A new OTP has been sent to your email and phone.',
          style: GoogleFonts.dmSans(),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF111827),
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5C78), Color(0xFFFF2D55)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2D55).withOpacity(0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Almost there',
                        style: GoogleFonts.dmSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please enter the 6-digit code sent to your email',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          height: 1.7,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            height: 1.7,
                            color: const Color(0xFF6B7280),
                          ),
                          children: [
                            const TextSpan(text: 'Please enter the 6-digit code sent to your email '),
                            TextSpan(
                              text: 'contact.uiuxexperts@gmail.com',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                            const TextSpan(text: ' and phone number for verification.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final digits = _codeController.text.padRight(6).split('');
                          final showDigit = digits[index] != ' ';
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 48,
                            height: 58,
                            decoration: BoxDecoration(
                              color: showDigit ? const Color(0xFFFEE4E2) : const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _isCodeValid ? const Color(0xFFE5E7EB) : const Color(0xFFEF4444),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              showDigit ? digits[index] : '',
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (_) {
                          setState(() {});
                        },
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          color: const Color(0xFF111827),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Enter code here',
                          filled: true,
                          fillColor: const Color(0xFFF7F7F8),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      if (!_isCodeValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Please enter a valid 6-digit code.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _verifyCode,
                        child: Container(
                          width: double.infinity,
                          height: 52,
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
                              'Verify',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              "Didn't receive any code?",
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _isResendLocked ? null : _resendCode,
                              child: Text(
                                _isResendLocked
                                    ? 'Request a new code in 00:${_resendSeconds.toString().padLeft(2, '0')}'
                                    : 'Resend Again',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _isResendLocked ? const Color(0xFF9CA3AF) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
