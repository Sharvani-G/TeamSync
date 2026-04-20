import 'package:flutter/material.dart';
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
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/main');
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
                child: _GlowBlob(color: current.accent.withValues(alpha: 0.25)),
              ),
              Positioned(
                bottom: -80,
                left: -40,
                child: _GlowBlob(color: current.accent.withValues(alpha: 0.18)),
              ),
              PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
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
              color: Colors.black.withValues(alpha: 0.08),
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
                                : page.accent.withValues(alpha: 0.35),
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
