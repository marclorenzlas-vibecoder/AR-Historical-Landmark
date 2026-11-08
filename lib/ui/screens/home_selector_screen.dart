import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ar_scanner_screen.dart';
import 'qr_scanner_screen.dart';

class HomeSelectorScreen extends StatelessWidget {
  const HomeSelectorScreen({super.key});

  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE5C158);
  static const Color yoloYellow = Color(0xFFFFE600);
  static const Color deepEspresso = Color(0xFF12100E);
  static const Color surfaceBrown = Color(0xFF1C1814);
  static const Color textParchment = Color(0xFFF7EBE1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepEspresso,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Top Emblem & App Title
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surfaceBrown,
                    border: Border.all(
                      color: goldPrimary.withValues(alpha: 0.55),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: goldPrimary.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    size: 46,
                    color: goldPrimary,
                  ),
                ),
              ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 18),

              Text(
                'ARcVision',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  color: textParchment,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'HISTORICAL LANDMARK HERITAGE EXPLORER',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: goldLight,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose how you would like to explore Bacolod\'s historical landmarks:',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC7B9AC),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // OPTION 1: SCAN A QR CODE
              _buildModeOptionCard(
                context: context,
                badgeText: 'OPTION 1 • QR CODE LOOKUP',
                title: 'Scan Landmark QR Code',
                description:
                    'Scan a QR code for LCCB, CATHEDRAL, or PLAZA to immediately open its complete historical details and timeline.',
                icon: Icons.qr_code_scanner,
                accentColor: yoloYellow,
                tags: const ['LCCB', 'CATHEDRAL', 'PLAZA'],
                buttonLabel: 'START QR SCANNER',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QRScannerScreen(),
                    ),
                  );
                },
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.12, end: 0),

              const SizedBox(height: 18),

              // OPTION 2: LIVE AR DATA DETECTION
              _buildModeOptionCard(
                context: context,
                badgeText: 'OPTION 2 • REAL-TIME AI TRACKING',
                title: 'Live AR Object Scanner',
                description:
                    'Point your camera directly at the landmark with real-time YOLO-style outline tracking that follows the monument.',
                icon: Icons.center_focus_strong,
                accentColor: goldLight,
                tags: const ['LIVE CAMERA', 'DYNAMIC OUTLINE', 'AI MODEL'],
                buttonLabel: 'LAUNCH LIVE AR SCANNER',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ARScannerScreen(),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.12, end: 0),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOptionCard({
    required BuildContext context,
    required String badgeText,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required List<String> tags,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceBrown,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.6),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: GoogleFonts.playfairDisplay(
                          color: textParchment,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: GoogleFonts.outfit(
                color: const Color(0xFFD0C3B5),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14110E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        t,
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonLabel,
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

