import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      imagePath: 'assets/images/entry_logo.png',
      title: 'Welcome To TeamSync',
      subtitle: 'Connect ideas, align teams, and launch projects faster.',
      bgStart: Color(0xFFFF5C78),
      bgEnd: Color(0xFFFF2D55),
      accent: Color(0xFFFFE5EC),
      button: Color(0xFF111827),
      titleColor: Colors.white,
      subtitleColor: Color(0xFFFCE7F0),
      cardBackground: Color(0x1FFFFFFF),
      cardBorder: Color(0x59FFFFFF),
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_second.jpg',
      title: 'Explore Projects\nEasily',
      subtitle: 'Find tasks, milestones, and updates in one clean timeline.',
      bgStart: Color(0xFFF5F6FA),
      bgEnd: Color(0xFFEDEFF6),
      accent: Color(0xFFFF6B80),
      button: Color(0xFF0B0D12),
      titleColor: Color(0xFF0B0D12),
      subtitleColor: Color(0xFF6B7280),
      cardBackground: Colors.white,
      cardBorder: Color(0xFFE5E7EB),
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_third.jpg',
      title: 'Collaborate.\nOrganize.\nBuild Together.',
      subtitle: 'Sync your ideas',
      bgStart: Color(0xFFF4F4F5),
      bgEnd: Color(0xFFEDEEEF),
      accent: Color(0xFFFF6B80),
      button: Color(0xFF111827),
      titleColor: Color(0xFF09090B),
      subtitleColor: Color(0xFF8B8B90),
      cardBackground: Color(0xFFF7F7F8),
      cardBorder: Color(0xFFE8E8EA),
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_fourth.jpg',
      title: 'Welcome back',
      subtitle: 'sign in to access your account',
      bgStart: Color(0xFFE6F0FF),
      bgEnd: Color(0xFFD7E9FF),
      accent: Color(0xFF3B82F6),
      button: Color(0xFF111827),
      titleColor: Color(0xFF111827),
      subtitleColor: Color(0xFF6B7280),
      cardBackground: Colors.white,
      cardBorder: Color(0xFFD1D5DB),
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_third.jpg',
      title: 'Get Started',
      subtitle: 'by creating a free account.',
      bgStart: Color(0xFFFFFFFF),
      bgEnd: Color(0xFFF8F9FB),
      accent: Color(0xFFEF4444),
      button: Color(0xFF111827),
      titleColor: Color(0xFF111827),
      subtitleColor: Color(0xFF6B7280),
      cardBackground: Colors.white,
      cardBorder: Color(0xFFE5E7EB),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _goToSignIn() async {
    if (!mounted) return;
    await _pageController.animateToPage(
      _pages.length - 2,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToRegister() async {
    if (!mounted) return;
    await _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [current.bgStart, current.bgEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -20,
                child: _GlowBlob(color: current.accent.withOpacity(0.25)),
              ),
              Positioned(
                bottom: -80,
                left: -40,
                child: _GlowBlob(color: current.accent.withOpacity(0.18)),
              ),
              PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  if (index == _pages.length - 2) {
                    return _SignInPane(
                      page: page,
                      floatAnimation: _floatAnimation,
                      currentPage: _currentPage,
                      totalPages: _pages.length,
                      onRegister: _goToRegister,
                    );
                  }
                  if (index == _pages.length - 1) {
                    return _RegisterPane(
                      page: page,
                      floatAnimation: _floatAnimation,
                      currentPage: _currentPage,
                      totalPages: _pages.length,
                      onRegistered: _goToSignIn,
                    );
                  }
                  return _OnboardingPane(
                    page: page,
                    floatAnimation: _floatAnimation,
                    currentPage: _currentPage,
                    totalPages: _pages.length,
                    onNext: _goNext,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPane extends StatelessWidget {
  const _OnboardingPane({
    required this.page,
    required this.floatAnimation,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });

  final _OnboardingData page;
  final Animation<double> floatAnimation;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: page.cardBackground,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: page.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, floatAnimation.value),
                        child: child,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        page.imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  page.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 42,
                    height: 1.06,
                    color: page.titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  page.subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    color: page.subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(totalPages, (index) {
                        final active = currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: active ? 24 : 8,
                          decoration: BoxDecoration(
                            color: active
                                ? page.accent
                                : page.accent.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                  GestureDetector(
                    onTap: onNext,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: page.button,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _SignInPane extends StatefulWidget {
  const _SignInPane({
    required this.page,
    required this.floatAnimation,
    required this.currentPage,
    required this.totalPages,
    required this.onRegister,
  });

  final _OnboardingData page;
  final Animation<double> floatAnimation;
  final int currentPage;
  final int totalPages;
  final VoidCallback onRegister;

  @override
  State<_SignInPane> createState() => _SignInPaneState();
}

class _SignInPaneState extends State<_SignInPane>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isSubmitting = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'Sign in failed. Please try again.';
      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.8 + (_fadeAnimation.value * 0.2),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      widget.page.imagePath,
                      fit: BoxFit.contain,
                      height: 180,
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.page.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 26,
                          height: 1.3,
                          color: widget.page.titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.page.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: widget.page.subtitleColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'Enter your email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              obscureText: true,
                              keyboardType: TextInputType.visiblePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() => _rememberMe = val ?? false);
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  activeColor: const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember me',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isSubmitting ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Next  >',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New Member? ',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onRegister,
                            child: Text(
                              'Register now',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        color: const Color(0xFF1F2937),
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFFD1D5DB), size: 20)
            : null,
        suffixIcon: obscureText
            ? const Icon(Icons.lock, color: Color(0xFFD1D5DB), size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

class _RegisterPane extends StatefulWidget {
  const _RegisterPane({
    required this.page,
    required this.floatAnimation,
    required this.currentPage,
    required this.totalPages,
    required this.onRegistered,
  });

  final _OnboardingData page;
  final Animation<double> floatAnimation;
  final int currentPage;
  final int totalPages;
  final Future<void> Function() onRegistered;

  @override
  State<_RegisterPane> createState() => _RegisterPaneState();
}

class _RegisterPaneState extends State<_RegisterPane>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeTerms = false;
  bool _isSubmitting = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        !_agreeTerms ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

      debugPrint(
        'Signup success: uid=${credential.user?.uid}, email=${credential.user?.email}',
      );

      unawaited(
        FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'uid': credential.user!.uid,
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((error) {
              debugPrint('Signup profile save failed: $error');
            }),
      );

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      await widget.onRegistered();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please sign in to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Signup failed [${e.code}]: ${e.message}');
      if (!mounted) return;
      var message = 'Sign up failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        message =
            'Email/Password sign-in is disabled in Firebase Authentication.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your connection and try again.';
      } else if ((e.message ?? '').isNotEmpty) {
        message = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: widget.floatAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, widget.floatAnimation.value),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      widget.page.imagePath,
                      fit: BoxFit.contain,
                      height: 180,
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.page.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 26,
                          height: 1.3,
                          color: widget.page.titleColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.page.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: widget.page.subtitleColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            buildTextField(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Full name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            buildTextField(
                              controller: _emailController,
                              label: 'Valid email',
                              hint: 'Valid email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            buildTextField(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: 'Phone number',
                              icon: Icons.phone_iphone,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.length < 8) {
                                  return 'Enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            buildTextField(
                              controller: _passwordController,
                              label: 'Strong password',
                              hint: 'Strong password',
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _agreeTerms,
                              onChanged: (val) {
                                setState(() => _agreeTerms = val ?? false);
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                              activeColor: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'By checking the box you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: const Color(0xFFEF4444),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _isSubmitting ? null : _submit,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Next  >',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                            ),
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

Widget buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  IconData? icon,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    style: GoogleFonts.dmSans(
      fontSize: 14,
      color: const Color(0xFF1F2937),
    ),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFFD1D5DB), size: 20)
          : null,
      suffixIcon: obscureText
          ? const Icon(Icons.lock, color: Color(0xFFD1D5DB), size: 20)
          : null,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      hintStyle: GoogleFonts.dmSans(
        fontSize: 14,
        color: const Color(0xFFD1D5DB),
      ),
    ),
  );
}

class _OnboardingData {
  const _OnboardingData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.bgStart,
    required this.bgEnd,
    required this.accent,
    required this.button,
    required this.titleColor,
    required this.subtitleColor,
    required this.cardBackground,
    required this.cardBorder,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final Color bgStart;
  final Color bgEnd;
  final Color accent;
  final Color button;
  final Color titleColor;
  final Color subtitleColor;
  final Color cardBackground;
  final Color cardBorder;
}
