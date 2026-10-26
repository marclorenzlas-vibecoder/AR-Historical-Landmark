import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/scanner_provider.dart';
import '../../services/camera_service.dart';
import '../../services/landmark_data_service.dart';
import '../widgets/ar_hud_overlay.dart';
import 'gallery_sim_screen.dart';
import 'landmark_detail_screen.dart';

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
    final activeLandmark = LandmarkDataService.findByLabel(scanner.activeSimulatedLandmarkKey);

    return Scaffold(
      backgroundColor: const Color(0xFF12100E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewport or High-Res Simulated AR Feed
          if (cameraService.isLiveCamera && cameraService.controller != null)
            CameraPreview(cameraService.controller!)
          else
            _buildSimulatedViewport(activeLandmark),

          // 2. Vintage Brass Viewfinder & Smart Non-Overlapping AR Card
          ARHudOverlay(
            result: scanner.currentResult,
            isScanning: scanner.isScanning,
            headingDegrees: scanner.headingDegrees,
            simulatedDistance: scanner.simulatedDistance,
          ),

          // 3. Unified, Clean Top Header Bar (Safe-Area Aware, Zero Overlap!)
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

          // 4. Bottom Heritage Explorer Control Dock
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

  Widget _buildSimulatedViewport(dynamic landmark) {
    if (landmark == null) {
      return Container(color: const Color(0xFF14110E));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          landmark.imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFF1B1714),
            child: const Center(
              child: Icon(Icons.account_balance, size: 90, color: Color(0xFFD4AF37)),
            ),
          ),
        ),
        // Warm antique vignette for contrast
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.45),
                const Color(0xFF14110E).withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Clean, spacious top bar that unifies telemetry, mode, and AI confidence without any overlap
  Widget _buildUnifiedTopBar(
    BuildContext context,
    CameraService cameraService,
    ScannerProvider scanner,
  ) {
    final res = scanner.currentResult;
    final matchPct = ((res?.overallConfidence ?? 0.95) * 100).toStringAsFixed(0);

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
        children: [
          // Left: Compass & Range Telemetry
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_outlined, color: Color(0xFFD4AF37), size: 15),
              const SizedBox(width: 5),
              Text(
                '${scanner.headingDegrees.toStringAsFixed(0)}° • ~${scanner.simulatedDistance.toStringAsFixed(0)}m',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE5C158),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Center: Lens Mode Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF28221B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: scanner.isScanning ? const Color(0xFF68D391) : const Color(0xFFE53E3E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  cameraService.isLiveCamera ? 'LIVE CAMERA' : 'SAMPLE VIEW',
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

          const Spacer(),

          // Right: AI Pipeline Confidence Button
          GestureDetector(
            onTap: () => _showPipelineDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology, color: Color(0xFFE5C158), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'AI $matchPct%',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFFF0B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Warm, friendly Heritage Explorer Navigation Dock
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
          // 1. Landmark Archive / Library
          _buildDockButton(
            icon: Icons.account_balance,
            label: 'Archive',
            color: const Color(0xFFD4AF37),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GallerySimScreen()),
              );
            },
          ),

          // 2. Collab ML Info
          _buildDockButton(
            icon: Icons.hub_outlined,
            label: 'Collab ML',
            color: const Color(0xFFE5C158),
            onTap: () => _showPipelineDialog(context),
          ),

          // 3. Central Pause / Resume Scanning Button
          GestureDetector(
            onTap: () => scanner.toggleScanning(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: scanner.isScanning
                      ? [const Color(0xFFE5C158), const Color(0xFFC59B27)]
                      : [const Color(0xFF4A3E33), const Color(0xFF2B241E)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  if (scanner.isScanning)
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Icon(
                scanner.isScanning ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),

          // 4. Discovery Log / Field Notes
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildDockButton(
                icon: Icons.history_edu,
                label: 'Notes',
                color: const Color(0xFFF7EBE1),
                onTap: () => _showHistorySheet(context, scanner),
              ),
              if (scanner.discoveryHistory.isNotEmpty)
                Positioned(
                  right: 4,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${scanner.discoveryHistory.length}',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // 5. Flash / Torch
          _buildDockButton(
            icon: cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
            label: 'Torch',
            color: cameraService.isFlashOn ? const Color(0xFFE5C158) : const Color(0xFF9E8E81),
            onTap: () => cameraService.toggleFlash(),
          ),
        ],
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
            const Icon(Icons.account_balance, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Text(
              'Heritage AI Architecture',
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
              'Stage 1: YOLO Landmark Detector',
              'Real-time object detection localizing the monument bounding box and tracking it steadily across camera motion.',
            ),
            const SizedBox(height: 12),
            _buildDialogStep(
              '2',
              'Stage 2: Deep CNN Classifier',
              'Deep convolutional neural network recognizing architectural characteristics and historical epoch with high confidence.',
            ),
            const SizedBox(height: 12),
            _buildDialogStep(
              '3',
              'Google Colab Training Notebook',
              'Located in notebooks/historical_landmark_yolo_cnn.ipynb for your group collaboration and model training.',
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

  void _showHistorySheet(BuildContext context, ScannerProvider scanner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1814),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final history = scanner.discoveryHistory;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_edu, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 10),
                  Text(
                    'Field Discovery Log',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFFF7EBE1),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        scanner.clearHistory();
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'CLEAR',
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No monuments scanned yet. Aim your camera lens at a historical site or select one from the Archive!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: const Color(0xFFAFA397), fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final landmark = item.landmark;
                      if (landmark == null) return const SizedBox();

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.asset(
                              landmark.imageAsset,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFF28221B),
                                child: const Icon(Icons.account_balance, color: Color(0xFFD4AF37)),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          landmark.name,
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFFF7EBE1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${landmark.country} • ${(item.overallConfidence * 100).toStringAsFixed(0)}% Match',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFC7B9AC),
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LandmarkDetailScreen(landmark: landmark),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
