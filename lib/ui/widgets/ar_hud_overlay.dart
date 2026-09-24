import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/landmark.dart';
import '../screens/landmark_detail_screen.dart';

class ARHudOverlay extends StatefulWidget {
  final RecognitionResult? result;
  final bool isScanning;
  final double headingDegrees;
  final double simulatedDistance;

  const ARHudOverlay({
    super.key,
    required this.result,
    required this.isScanning,
    required this.headingDegrees,
    required this.simulatedDistance,
  });

  @override
  State<ARHudOverlay> createState() => _ARHudOverlayState();
}

class _ARHudOverlayState extends State<ARHudOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final res = widget.result;
    final box = res?.boundingBox;
    final landmark = res?.landmark;

    return Stack(
      children: [
        // 1. Heritage Brass Optical Viewfinder & Brackets
        if (box != null && widget.isScanning)
          Positioned.fill(
            child: CustomPaint(
              painter: HeritageViewfinderPainter(
                box: box,
                screenSize: screenSize,
                overallConfidence: res?.overallConfidence ?? 0.0,
              ),
            ),
          ),

        // 2. Warm Golden Explorer Shimmer Wave (Replaces harsh laser)
        if (widget.isScanning && box != null)
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              final rect = box.toRect(screenSize);
              final shimmerY = rect.top + (rect.height * _shimmerController.value);
              return Positioned(
                left: rect.left,
                top: shimmerY,
                width: rect.width,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        const Color(0xFFFFF0B8),
                        const Color(0xFFE5C158).withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        // 3. Intelligent Non-Overlapping Heritage AR Landmark Card
        if (box != null && landmark != null && widget.isScanning)
          _buildSmartFloatingCard(context, landmark, res!, box, screenSize, topPadding),

        // 4. Searching Reticle when searching horizon
        if (box == null && widget.isScanning)
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.explore,
                    size: 54,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.65),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
                  Positioned(
                    bottom: 16,
                    child: Text(
                      'SEEKING HERITAGE SITE...',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFE5C158),
                        fontSize: 10,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Calculates a collision-free position for the floating card
  Widget _buildSmartFloatingCard(
    BuildContext context,
    Landmark landmark,
    RecognitionResult res,
    BoundingBox box,
    Size screenSize,
    double topPadding,
  ) {
    const cardWidth = 310.0;
    const cardHeight = 110.0;

    // Minimum safe Y below the top header (topPadding + 75px for top bar)
    final safeTopLimit = topPadding + 75.0;

    // Center card horizontally over box, clamped to screen bounds
    final targetX = (box.centerX * screenSize.width) - (cardWidth / 2);
    final clampedX = targetX.clamp(16.0, max(16.0, screenSize.width - cardWidth - 16.0));

    // Determine vertical placement:
    // If placing above the box would hit the top bar, place it BELOW the box!
    final spaceAbove = (box.top * screenSize.height) - safeTopLimit;
    double targetY;

    if (spaceAbove > (cardHeight + 16)) {
      // Plenty of room above box
      targetY = (box.top * screenSize.height) - cardHeight - 12;
    } else {
      // Place below box or just below the top header
      targetY = (box.bottom * screenSize.height) + 14;
      // If below box goes off the screen, dock at bottom above controls
      if (targetY + cardHeight > screenSize.height - 110) {
        targetY = screenSize.height - 230;
      }
    }

    return Positioned(
      left: clampedX.toDouble(),
      top: max(safeTopLimit, targetY).toDouble(),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LandmarkDetailScreen(landmark: landmark),
            ),
          );
        },
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xF21C1814),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header tag
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance,
                          color: Color(0xFFD4AF37),
                          size: 11,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'MONUMENT IDENTIFIED',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFE5C158),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E2A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(res.overallConfidence * 100).toStringAsFixed(0)}% MATCH',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFFF0B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Landmark Name in elegant serif
              Text(
                landmark.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFFFBF7F2),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${landmark.country} • ${landmark.era}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFD0C3B5),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),

              // Friendly call-to-action
              Row(
                children: [
                  const Icon(
                    Icons.auto_stories,
                    color: Color(0xFFD4AF37),
                    size: 13,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Explore history & audio guide',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFE5C158),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFD4AF37),
                    size: 10,
                  ),
                ],
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 250.ms)
          .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1)),
    );
  }
}

/// Custom painter for vintage brass optical viewfinder and brackets
class HeritageViewfinderPainter extends CustomPainter {
  final BoundingBox box;
  final Size screenSize;
  final double overallConfidence;

  HeritageViewfinderPainter({
    required this.box,
    required this.screenSize,
    required this.overallConfidence,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = box.toRect(screenSize);

    // Warm Antique Brass Bounding Box
    const goldColor = Color(0xFFD4AF37);
    const champagneColor = Color(0xFFF0D890);

    final boxPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = goldColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      boxPaint,
    );

    // Classical Surveyor Corner Brackets
    final cornerPaint = Paint()
      ..color = champagneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;

    const cornerLength = 20.0;

    // Top-Left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Top-Right
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, cornerLength), cornerPaint);

    // Bottom-Right
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, cornerLength), cornerPaint);

    // Subtle center optical surveyor crosshair
    final center = rect.center;
    final crossPaint = Paint()
      ..color = champagneColor.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;

    canvas.drawLine(center - const Offset(10, 0), center + const Offset(10, 0), crossPaint);
    canvas.drawLine(center - const Offset(0, 10), center + const Offset(0, 10), crossPaint);
  }

  @override
  bool shouldRepaint(covariant HeritageViewfinderPainter oldDelegate) {
    return oldDelegate.box != box ||
        oldDelegate.overallConfidence != overallConfidence;
  }
}
