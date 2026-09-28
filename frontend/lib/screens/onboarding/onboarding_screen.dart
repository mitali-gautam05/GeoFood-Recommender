import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _precached = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      imagePath: 'assets/onboarding/slide1.jpg',
      title: 'Food that finds\nyou first.',
      subtitle:
          'GeoTaste AI learns what you love and recommends the best nearby restaurants before you even feel hungry.',
      color: Color(0xFFFF6B35),
    ),
    OnboardingPage(
      imagePath: 'assets/onboarding/slide2.jpg',
      title: 'Smarter with\nevery tap.',
      subtitle:
          'Every time you accept or decline a suggestion, our AI gets sharper. The more you use it, the better it gets.',
      color: Color(0xFF2ECC71),
    ),
    OnboardingPage(
      imagePath: 'assets/onboarding/slide3.jpg',
      title: 'Right food,\nright time.',
      subtitle:
          'Biryani at 8pm. Dosa at 8am. GeoTaste AI knows what hits different based on the hour — not just your location.',
      color: Color(0xFF3498DB),
    ),
    OnboardingPage(
      imagePath: 'assets/onboarding/slide4.jpg',
      title: 'No spam.\nEver.',
      subtitle:
          'Tell us you\'re not hungry and we pause for an hour. You\'re in control. We just make the choices easier.',
      color: Color(0xFF9B59B6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load all slide images up front so swiping never shows a blank frame.
    if (!_precached) {
      _precached = true;
      for (final p in _pages) {
        precacheImage(AssetImage(p.imagePath), context).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  // Full-bleed photo + brand-colour tint + dark gradient for text contrast.
  Widget _buildBackground(OnboardingPage p) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          p.imagePath,
          fit: BoxFit.cover,
          cacheWidth: 1200,
          // If the photo is missing, fall back to the plain brand colour.
          errorBuilder: (_, __, ___) => Container(color: p.color),
        ),
        Container(color: p.color.withOpacity(0.45)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 1.0],
              colors: [
                Colors.black.withOpacity(0.15),
                Colors.transparent,
                Colors.black.withOpacity(0.75),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: page.color,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // ── Pages: photo background + text ────────────────────────
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) {
                _fadeController.reset();
                setState(() => _currentPage = i);
                _fadeController.forward();
              },
              itemCount: _pages.length,
              itemBuilder: (_, i) {
                final p = _pages[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildBackground(p),
                    SafeArea(
                      child: Padding(
                        // bottom padding clears the dots + button below
                        padding: const EdgeInsets.fromLTRB(32, 0, 32, 190),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -1,
                                shadows: [
                                  Shadow(blurRadius: 12, color: Colors.black38),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              p.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 17,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── Skip button ───────────────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButton(
                    onPressed: _goToLogin,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom: dots + button ─────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: page.color,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String imagePath;
  final String title;
  final String subtitle;
  final Color color;

  OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}