import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/landmark.dart';
import '../screens/landmark_detail_screen.dart';

/// Real-time AR HUD overlay displaying dynamic YOLO-style tracking bounding boxes
/// and landmark label tags that follow the monument across the camera view,
/// matching the BoxMapper + DetectionPainter behavior from its411yolo.
class ARHudOverlay extends StatelessWidget {
  final RecognitionResult? result;
  final bool isScanning;
  final double headingDegrees;
  final double simulatedDistance;
  final VoidCallback? onDismiss;

  const ARHudOverlay({
    super.key,
    required this.result,
    required this.isScanning,
    required this.headingDegrees,
    required this.simulatedDistance,
    this.onDismiss,
  });

  // Reference yellow color matching standard YOLO object detection bounding boxes
  static const Color yoloYellow = Color(0xFFFFE600);

  @override
  Widget build(BuildContext context) {
    if (!isScanning) return const SizedBox.shrink();

    final res = result;
    final landmark = res?.landmark;
    final isLocked = landmark != null && res?.boundingBox != null;

    // If no landmark is confidently detected, display nothing (turn off completely)
    if (!isLocked) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = res!.boundingBox!.toFittedRect(
          imageSize: res.imageSize,
          widgetSize: widgetSize,
          fit: BoxFit.cover,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Real-time CustomPainter outline (like DetectionPainter in its411yolo)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: LandmarkDetectionPainter(
                    rect: rect,
                    color: yoloYellow,
                  ),
                ),
              ),
            ),

            // 2. Interactive tracking frame & label chip that follows the object
            _buildInteractiveTrackingBox(context, landmark, res, rect),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveTrackingBox(
    BuildContext context,
    Landmark landmark,
    RecognitionResult res,
    Rect rect,
  ) {
    final matchPct = (res.overallConfidence * 100).toStringAsFixed(0);
    final bool placeChipInsideTop = rect.top < 28;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LandmarkDetailScreen(landmark: landmark),
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Attached Yellow Label Tag on the Top Edge (follows object like its411yolo)
            Positioned(
              top: placeChipInsideTop ? 0 : -24,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: yoloYellow,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                    bottomRight: Radius.circular(3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${landmark.name.toUpperCase()}  $matchPct%',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black,
                      size: 9,
                    ),
                  ],
                ),
              ),
            ),

            // Close / Dismiss Button on the Top Right of the Box
            if (onDismiss != null)
              Positioned(
                top: placeChipInsideTop ? 0 : -24,
                right: 0,
                child: GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: const BoxDecoration(
                      color: yoloYellow,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                        bottomLeft: Radius.circular(3),
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 13,
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

/// CustomPainter modeled after its411yolo's DetectionPainter to draw the bounding box
/// outline directly onto the canvas with zero frame lag as the object moves.
class LandmarkDetectionPainter extends CustomPainter {
  final Rect rect;
  final Color color;

  const LandmarkDetectionPainter({
    required this.rect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rect.isEmpty || size.isEmpty) return;

    final boxPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      boxPaint,
    );
  }

  @override
  bool shouldRepaint(covariant LandmarkDetectionPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.color != color;
  }
}
