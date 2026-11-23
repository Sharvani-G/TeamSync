import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isMatching = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _continue() {
    setState(() {
      _isMatching = _passwordController.text == _confirmController.text &&
          _passwordController.text.length >= 6;
    });
    if (!_isMatching) return;
    Navigator.pushReplacementNamed(context, '/main');
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
                        child: Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 24),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Create new password',
                      style: AppTheme.displayFont(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your new password must be different from previous passwords and at least 6 characters.',
                      style: AppTheme.bodyFont(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'New Password',
                      style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppTheme.inkSecondary,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Confirm Password',
                      style: AppTheme.bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmController,
                      obscureText: !_showConfirm,
                      style: AppTheme.bodyFont(fontSize: 14, color: AppTheme.ink),
                      decoration: InputDecoration(
                        hintText: 'Re-enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppTheme.inkSecondary,
                          ),
                          onPressed: () => setState(() => _showConfirm = !_showConfirm),
                        ),
                        fillColor: AppTheme.groundMuted,
                        filled: true,
                      ),
                    ),

                    if (!_isMatching) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Passwords do not match or are shorter than 6 characters.',
                        style: AppTheme.bodyFont(fontSize: 12, color: AppTheme.danger),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          'Update Password',
                          style: AppTheme.bodyFont(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
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
