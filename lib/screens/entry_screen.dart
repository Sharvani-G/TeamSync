import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

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
      imagePath: 'assets/images/onboarding_1.jpg',
      badge: 'Welcome to TeamSync',
      title: 'Connect ideas, align teams, and build faster.',
      subtitle: 'The collaborative project management space built for high-performing teams.',
      buttonLabel: 'Get Started',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_2.png',
      badge: 'Project Tracking',
      title: 'Explore projects & milestones in one timeline.',
      subtitle: 'Track team phases, deliverable completion, and updates in real-time.',
      buttonLabel: 'Continue',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_3.jpg',
      badge: 'Team Collaboration',
      title: 'Collaborate. Organize. Build together.',
      subtitle: 'Seamlessly coordinate idea boards, live chat channels, and video calls.',
      buttonLabel: 'Next',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_fourth.jpg',
      badge: 'Member Access',
      title: 'Welcome back to TeamSync',
      subtitle: 'Sign in with your email to access your projects and workspaces.',
      buttonLabel: 'Sign In',
    ),
    _OnboardingData(
      imagePath: 'assets/images/onboarding_fifth.png',
      badge: 'Create Account',
      title: 'Join TeamSync today',
      subtitle: 'Create a free account to collaborate on projects and launch faster.',
      buttonLabel: 'Create Account',
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

    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
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
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _goToSignIn() async {
    if (!mounted) return;
    await _pageController.animateToPage(
      _pages.length - 2,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToRegister() async {
    if (!mounted) return;
    await _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ground,
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          physics: _currentPage == _pages.length - 1
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
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
              onSkipToSignIn: _goToSignIn,
            );
          },
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
    required this.onSkipToSignIn,
  });

  final _OnboardingData page;
  final Animation<double> floatAnimation;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkipToSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                      ),
                      child: Text(
                        page.badge,
                        style: AppTheme.bodyFont(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onSkipToSignIn,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'Sign In',
                        style: AppTheme.bodyFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 180,
                  width: double.infinity,
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
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          page.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppTheme.groundMuted,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, size: 48, color: AppTheme.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  page.title,
                  style: AppTheme.displayFont(
                    fontSize: 26,
                    height: 1.25,
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  page.subtitle,
                  style: AppTheme.bodyFont(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.inkSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(totalPages, (index) {
                        final active = currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          height: 6,
                          width: active ? 22 : 6,
                          decoration: BoxDecoration(
                            color: active ? AppTheme.accent : AppTheme.rule,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            page.buttonLabel,
                            style: AppTheme.bodyFont(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

class _SignInPaneState extends State<_SignInPane> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      });
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: AppTheme.bodyFont(color: Colors.white)),
            backgroundColor: AppTheme.field,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/entry_logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'TeamSync',
                      style: AppTheme.displayFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'Sign in to your account',
                  style: AppTheme.displayFont(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back! Please enter your details.',
                  style: AppTheme.bodyFont(
                    fontSize: 14,
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
                        'Email',
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
                        style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                          fillColor: AppTheme.groundMuted,
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Password',
                        style: AppTheme.bodyFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: AppTheme.inkSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          fillColor: AppTheme.groundMuted,
                          filled: true,
                        ),
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
                            activeColor: AppTheme.accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) => setState(() => _rememberMe = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            color: AppTheme.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: AppTheme.bodyFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
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
                            'Sign In',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTheme.bodyFont(
                          fontSize: 13,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onRegister,
                        child: Text(
                          'Create one now',
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
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

class _RegisterPaneState extends State<_RegisterPane> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeTerms = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_agreeTerms || _isSubmitting) {
      if (!_agreeTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please accept the Terms and Conditions to proceed', style: AppTheme.bodyFont(color: Colors.white)),
            backgroundColor: AppTheme.field,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (!UserService.isValidUsernameFormat(username)) {
        throw Exception('Username must start with a letter and use only letters, numbers, or underscores');
      }

      final usernameAvailable = await UserService.instance.isUsernameAvailable(username);
      if (!usernameAvailable) {
        throw Exception('Username is already taken');
      }

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(_nameController.text.trim());

      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'username': username,
        'usernameLower': username.toLowerCase(),
        'name': _nameController.text.trim(),
        'display_name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'projectsJoined': 0,
        'tasksCompleted': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = 'Sign up failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if ((e.message ?? '').isNotEmpty) {
        message = e.message!;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: AppTheme.bodyFont(color: Colors.white)),
            backgroundColor: AppTheme.field,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''), style: AppTheme.bodyFont(color: Colors.white)),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/entry_logo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Create Account',
                      style: AppTheme.displayFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  'Join TeamSync',
                  style: AppTheme.displayFont(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign up with your credentials to start collaborating.',
                  style: AppTheme.bodyFont(
                    fontSize: 14,
                    color: AppTheme.inkSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                        label: 'Username',
                        controller: _usernameController,
                        hint: 'e.g. alex_rivera',
                        icon: Icons.alternate_email_rounded,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Please choose a username';
                          if (!UserService.isValidUsernameFormat(text)) {
                            return 'Use 3-20 letters, numbers, or underscores';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        label: 'Full Name',
                        controller: _nameController,
                        hint: 'Alex Rivera',
                        icon: Icons.badge_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        label: 'Email Address',
                        controller: _emailController,
                        hint: 'alex@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        label: 'Phone (optional)',
                        controller: _phoneController,
                        hint: '+1 555 0192',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'At least 6 characters',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppTheme.inkSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
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
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _agreeTerms,
                        activeColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'I agree to the TeamSync Terms of Service and Privacy Policy.',
                        style: AppTheme.bodyFont(
                          fontSize: 12,
                          color: AppTheme.inkSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
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
                            'Create Account',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTheme.bodyFont(
                          fontSize: 13,
                          color: AppTheme.inkSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onRegistered(),
                        child: Text(
                          'Sign in',
                          style: AppTheme.bodyFont(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
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
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyFont(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            fillColor: AppTheme.groundMuted,
            filled: true,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.imagePath,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
  });

  final String imagePath;
  final String badge;
  final String title;
  final String subtitle;
  final String buttonLabel;
}
