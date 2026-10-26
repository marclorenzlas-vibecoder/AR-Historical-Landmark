import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/landmark.dart';
import '../screens/landmark_detail_screen.dart';

/// Real-time AR HUD overlay displaying dynamic YOLO-style tracking bounding boxes
/// and landmark label tags that follow the monument across the camera view.
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

    final screenSize = MediaQuery.of(context).size;
    final res = result;
    final landmark = res?.landmark;
    final isLocked = landmark != null && res?.boundingBox != null;

    // If no landmark is confidently detected, display nothing (turn off completely)
    if (!isLocked) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildDynamicTrackingBoundingBox(context, landmark, res!, screenSize),
      ],
    );
  }

  /// 1. Dynamic YOLO-style Bounding Box that frames the detected landmark
  Widget _buildDynamicTrackingBoundingBox(
    BuildContext context,
    Landmark landmark,
    RecognitionResult res,
    Size screenSize,
  ) {
    final box = res.boundingBox!;
    final double left = box.left * screenSize.width;
    final double top = box.top * screenSize.height;
    final double width = box.width * screenSize.width;
    final double height = box.height * screenSize.height;

    final matchPct = (res.overallConfidence * 100).toStringAsFixed(0);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LandmarkDetailScreen(landmark: landmark),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: yoloYellow,
              width: 2.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Attached Yellow Label Tag on the Top Edge
              Positioned(
                top: -24,
                left: -2.5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: const BoxDecoration(
                    color: yoloYellow,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(3),
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
                  top: -24,
                  right: -2.5,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: yoloYellow,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
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
      ),
    );
  }
}

