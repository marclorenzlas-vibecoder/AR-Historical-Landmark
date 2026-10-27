import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/landmark.dart';
import '../../providers/scanner_provider.dart';
import '../../services/camera_service.dart';
import '../widgets/ar_hud_overlay.dart';
import 'landmark_detail_screen.dart';
import 'photo_test_screen.dart';

class ARScannerScreen extends StatefulWidget {
  const ARScannerScreen({super.key});

  @override
  State<ARScannerScreen> createState() => _ARScannerScreenState();
}

class _ARScannerScreenState extends State<ARScannerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final camera = Provider.of<CameraService>(context, listen: false);
        final scanner = Provider.of<ScannerProvider>(context, listen: false);
        scanner.bindCameraService(camera);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = Provider.of<CameraService>(context);
    final scanner = Provider.of<ScannerProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF12100E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Feed (Fixed aspect ratio without stretching/distortion)
          if (cameraService.isLiveCamera &&
              cameraService.controller != null &&
              cameraService.controller!.value.isInitialized)
            _buildUnstretchedCameraPreview(cameraService.controller!, context)
          else
            _buildCameraLoadingViewport(),

          // 2. Optical Reticle & Smart Dynamic AR Landmark Card (Pops up automatically!)
          ARHudOverlay(
            result: scanner.currentResult,
            isScanning: scanner.isScanning,
            headingDegrees: scanner.headingDegrees,
            simulatedDistance: scanner.simulatedDistance,
            onDismiss: () => scanner.clearCurrentResult(),
          ),

          // 3. Unified, Clean Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: _buildUnifiedTopBar(context, cameraService, scanner),
              ),
            ),
          ),

          // 4. Bottom Landmark Identification Label Card (Prominently displays detected monument)
          if (scanner.currentResult?.landmark != null)
            Positioned(
              bottom: 104,
              left: 16,
              right: 16,
              child: _buildBottomLandmarkCard(
                context,
                scanner.currentResult!.landmark!,
                scanner.currentResult!,
                scanner,
              ),
            ),

          // 5. Bottom Explorer Control Dock (Zero archive/testing simulations - 100% automatic live detection)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _buildHeritageControlDock(context, cameraService, scanner),
          ),
        ],
      ),
    );
  }

  /// Renders camera feed with strictly preserved aspect ratio, filling screen without stretching
  Widget _buildUnstretchedCameraPreview(
    CameraController controller,
    BuildContext context,
  ) {
    if (!controller.value.isInitialized) {
      return _buildCameraLoadingViewport();
    }

    final screenSize = MediaQuery.of(context).size;
    // On mobile portrait, display aspect ratio of camera preview is 1 / controller.value.aspectRatio
    final double cameraAspect = 1.0 / controller.value.aspectRatio;
    final double screenAspect = screenSize.aspectRatio;

    // Scale to fill the screen without stretching or geometric distortion
    double scale = 1.0;
    if (screenAspect < cameraAspect) {
      // Screen is taller than camera preview
      scale = cameraAspect / screenAspect;
    } else {
      // Screen is wider than camera preview
      scale = screenAspect / cameraAspect;
    }

    return SizedBox.expand(
      child: ClipRect(
        child: Transform.scale(
          scale: scale,
          child: Center(
            child: AspectRatio(
              aspectRatio: cameraAspect,
              child: CameraPreview(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLoadingViewport() {
    return Container(
      color: const Color(0xFF12100E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                  width: 1.5,
                ),
                color: const Color(0xFF1C1814),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 46,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ARcVision',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFF7EBE1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point camera at Cathedral, LCCB, or Public Plaza',
              style: GoogleFonts.outfit(
                color: const Color(0xFFC7B9AC),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedTopBar(
    BuildContext context,
    CameraService cameraService,
    ScannerProvider scanner,
  ) {
    final res = scanner.currentResult;
    final hasLandmark = res?.landmark != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1814),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Heading Telemetry
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, color: Color(0xFFD4AF37), size: 15),
              const SizedBox(width: 5),
              Text(
                '${scanner.headingDegrees.toStringAsFixed(0)}° • ${hasLandmark ? '~${scanner.simulatedDistance.toStringAsFixed(0)}m' : 'LIVE'}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE5C158),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Right: Live Recognition Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF28221B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLandmark
                    ? const Color(0xFF68D391).withValues(alpha: 0.6)
                    : const Color(0xFFD4AF37).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: hasLandmark
                        ? const Color(0xFF68D391)
                        : (scanner.isScanning ? const Color(0xFFE5C158) : const Color(0xFFE53E3E)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasLandmark
                      ? 'MONUMENT IDENTIFIED'
                      : (scanner.isScanning ? 'LIVE AR RECOGNITION' : 'SCANNER PAUSED'),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFF7FAFC),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLandmarkCard(
    BuildContext context,
    Landmark landmark,
    RecognitionResult res,
    ScannerProvider scanner,
  ) {
    final matchPct = (res.overallConfidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF71C1814),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFE600),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFFFE600).withValues(alpha: 0.16),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Leading Landmark Icon Badge
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LandmarkDetailScreen(landmark: landmark),
                ),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE600).withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFE600),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.account_balance,
                color: Color(0xFFFFE600),
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Landmark Information Column
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LandmarkDetailScreen(landmark: landmark),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF68D391),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'IDENTIFIED • $matchPct% MATCH',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF68D391),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    landmark.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFF7EBE1),
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${landmark.yearBuilt} • ${landmark.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFC7B9AC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Trailing Action Button
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LandmarkDetailScreen(landmark: landmark),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE600),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DETAILS',
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.black,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Dismiss 'X' Button (Instantly turn off / dismiss)
          GestureDetector(
            onTap: () => scanner.clearCurrentResult(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white70,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.25, end: 0, duration: 200.ms).fadeIn();
  }

  Widget _buildHeritageControlDock(
    BuildContext context,
    CameraService cameraService,
    ScannerProvider scanner,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF21C1814),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Torch / Flashlight
          _buildDockButton(
            icon: cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
            label: 'Torch',
            color: cameraService.isFlashOn ? const Color(0xFFE5C158) : const Color(0xFF9E8E81),
            onTap: () => cameraService.toggleFlash(),
          ),

          // 2. Switch Camera (Back / Front)
          _buildDockButton(
            icon: Icons.flip_camera_ios,
            label: 'Flip',
            color: const Color(0xFFE5C158),
            onTap: () => cameraService.switchCamera(),
          ),

          // 3. Test with Photo Upload (Gallery / Sample tester)
          _buildDockButton(
            icon: Icons.add_photo_alternate,
            label: 'Test Photo',
            color: const Color(0xFFFFE600),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PhotoTestScreen(),
                ),
              );
            },
          ),

          // 6. Detection Strictness & Accuracy Slider
          _buildDockButton(
            icon: Icons.tune,
            label: 'Strictness',
            color: const Color(0xFFE5C158),
            onTap: () => _showStrictnessModal(context, scanner),
          ),
        ],
      ),
    );
  }

  void _showStrictnessModal(BuildContext context, ScannerProvider scanner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double currentThreshold = scanner.confidenceThreshold;
            final int thresholdPct = (currentThreshold * 100).round();

            String levelTitle;
            String levelDesc;
            Color levelColor;
            IconData levelIcon;

            if (thresholdPct >= 95) {
              levelTitle = 'ULTRA STRICT (ANTI-CLUTTER)';
              levelDesc =
                  'Locks only onto verified historical landmarks. Highly resistant to desks, floors, keyboards, and dark room clutter.';
              levelColor = const Color(0xFF68D391);
              levelIcon = Icons.shield_outlined;
            } else if (thresholdPct >= 88) {
              levelTitle = 'BALANCED DETECTION';
              levelDesc =
                  'Optimal balance between fast locking and false positive rejection. Recommended for daytime outdoor viewing.';
              levelColor = const Color(0xFFFFE600);
              levelIcon = Icons.balance;
            } else {
              levelTitle = 'HIGH SENSITIVITY';
              levelDesc =
                  'Detects landmarks easily from farther distances or in low light, but may produce false triggers on indoor objects.';
              levelColor = const Color(0xFFED8936);
              levelIcon = Icons.bolt;
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1814),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header with Title & Live Value Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE600).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.tune, color: Color(0xFFFFE600), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DETECTION STRICTNESS',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFF7EBE1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                'Accuracy & clutter rejection threshold',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFC7B9AC),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Current percentage pill & Model info button
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
                            tooltip: 'Model Info',
                            onPressed: () => _showPipelineDialog(context),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE600),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '$thresholdPct%',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Interactive Threshold Slider
                  Row(
                    children: [
                      Text(
                        '60%',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF9E8E81),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: const Color(0xFFFFE600),
                            inactiveTrackColor: const Color(0xFF332B24),
                            thumbColor: const Color(0xFFFFE600),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            overlayColor: const Color(0xFFFFE600).withValues(alpha: 0.2),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          ),
                          child: Slider(
                            value: thresholdPct.toDouble(),
                            min: 60.0,
                            max: 99.0,
                            divisions: 39,
                            onChanged: (val) {
                              setModalState(() {
                                scanner.setConfidenceThreshold(val / 100.0);
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        '99%',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF9E8E81),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quick Preset Buttons
                  Row(
                    children: [
                      _buildPresetChip(
                        label: 'Sensitive (80%)',
                        isActive: thresholdPct == 80,
                        onTap: () {
                          setModalState(() {
                            scanner.setConfidenceThreshold(0.80);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Balanced (90%)',
                        isActive: thresholdPct == 90,
                        onTap: () {
                          setModalState(() {
                            scanner.setConfidenceThreshold(0.90);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildPresetChip(
                        label: 'Strict (96%) ★',
                        isActive: thresholdPct == 96,
                        onTap: () {
                          setModalState(() {
                            scanner.setConfidenceThreshold(0.96);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Dynamic Strictness Explanation Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14110E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: levelColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(levelIcon, color: levelColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                levelTitle,
                                style: GoogleFonts.outfit(
                                  color: levelColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                levelDesc,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFD0C3B5),
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Action Buttons (Test Photo & Done)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PhotoTestScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_photo_alternate, size: 16, color: Color(0xFFFFE600)),
                          label: Text(
                            'TEST WITH PHOTO',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFFE600),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFFE600), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE600),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'APPLY & CLOSE',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFFE600).withValues(alpha: 0.18)
                : const Color(0xFF231D17),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFFE600)
                  : const Color(0xFFD4AF37).withValues(alpha: 0.25),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: isActive ? const Color(0xFFFFE600) : const Color(0xFFC7B9AC),
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPipelineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1814),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Text(
              'Trained Landmark Model',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFFF7EBE1),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogStep(
              '1',
              'TFLite Neural Vision Model',
              'On-device MobileNetV2 trained specifically for real-time local historical landmark identification in Bacolod City.',
            ),
            const SizedBox(height: 12),
            _buildDialogStep(
              '2',
              'Recognized Monuments',
              '• San Sebastian Cathedral (cathedral)\n• La Consolacion College Bacolod (lccb)\n• Bacolod Public Plaza & Bandstand (plaza)',
            ),
            const SizedBox(height: 12),
            _buildDialogStep(
              '3',
              'Automatic AR Overlay',
              'Aim your device camera directly at any of the historical sites. The model detects the landmark automatically and displays its historical details.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CLOSE',
              style: GoogleFonts.outfit(
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStep(String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFFD4AF37),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: GoogleFonts.outfit(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFF7EBE1),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC7B9AC),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


}
