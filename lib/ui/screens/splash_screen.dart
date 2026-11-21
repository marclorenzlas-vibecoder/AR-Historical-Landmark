import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_selector_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color deepEspresso = Color(0xFF12100E);
  static const Color goldLight = Color(0xFFE5C158);
  static const Color yoloYellow = Color(0xFFFFE600);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => const HomeSelectorScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepEspresso,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Centered App Logo with clean scale, fade, and subtle shimmer
              Image.asset(
                'assets/app_icon_nobg.png',
                width: 230,
                fit: BoxFit.contain,
              )
                  .animate()
                  .fadeIn(duration: 550.ms, curve: Curves.easeOutCubic)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    end: const Offset(1.0, 1.0),
                    duration: 650.ms,
                    curve: Curves.easeOutBack,
                  )
                  .shimmer(
                    delay: 450.ms,
                    duration: 1200.ms,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),

              const SizedBox(height: 18),

              Text(
                'HISTORICAL LANDMARK HERITAGE EXPLORER',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: goldLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              )
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 450.ms)
                  .slideY(begin: 0.25, end: 0, duration: 450.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 28),

              // Minimal animated progress bar accent
              SizedBox(
                width: 110,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFF2A231D),
                    valueColor: AlwaysStoppedAnimation<Color>(yoloYellow),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
