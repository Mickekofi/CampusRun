import 'dart:async';

import 'package:flutter/material.dart';

import 'session.dart';
import 'theme_settings.dart';

// ============================================================================
// APPLICATION ENTRY POINT
// ============================================================================

void main() {
  runApp(const CampusRunApp());
}

// ============================================================================
// ROOT APPLICATION WIDGET
// ============================================================================

/// Main application widget that sets up theming and navigation.
class CampusRunApp extends StatelessWidget {
  const CampusRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeSettings,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CampusRun',
          theme: appThemeSettings.themeData,
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ============================================================================
// SPLASH SCREEN - STATEFUL WIDGET
// ============================================================================

/// Splash screen widget that displays branding and auto-navigates to main app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ========================================================================
  // ANIMATION CONTROLLERS & ANIMATIONS
  // ========================================================================

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  // ========================================================================
  // TIMERS
  // ========================================================================

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller with repeating animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Fade animation with easeInOut curve
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Scale animation: scales from 0.97 to 1.03
    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Auto-navigate to SessionPage after 20 seconds
    _timer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const SessionPage()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        // Gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppBrandColors.white, const Color(0xFFE3F2FD)],
          ),
        ),
        // ====================================================================
        // SPLASH SCREEN CONTENT
        // ====================================================================
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with fade and scale effects
              ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Icon(
                    Icons.pedal_bike_rounded,
                    size: 96,
                    color: AppBrandColors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                '',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Motivational quote
              const Text(
                "\"Some men see things as they are and ask 'Why?' I dream things that never were and ask 'Why not?'\" -- Robert F. Kennedy",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 28),

              // Loading progress indicator
              SizedBox(
                width: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const LinearProgressIndicator(
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppBrandColors.red,
                    ),
                    backgroundColor: Color(0xFFBBDEFB),
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
