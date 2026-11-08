import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:zxing2/qrcode.dart';

import '../../models/landmark.dart';
import '../../providers/scanner_provider.dart';
import '../../services/camera_service.dart';
import '../../services/landmark_data_service.dart';
import 'landmark_detail_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final QRCodeReader _qrReader = QRCodeReader();
  final ImagePicker _picker = ImagePicker();

  CameraService? _cameraService;
  bool _isDecodingFrame = false;
  bool _isNavigatingToDetail = false;
  int _lastScanAttemptMs = 0;

  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE5C158);
  static const Color yoloYellow = Color(0xFFFFE600);
  static const Color deepEspresso = Color(0xFF12100E);
  static const Color textParchment = Color(0xFFF7EBE1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Pause live AR ML stream so QR scanner has exclusive camera stream access
      final scanner = Provider.of<ScannerProvider>(context, listen: false);
      scanner.stopScanning();

      _cameraService = Provider.of<CameraService>(context, listen: false);
      _startQrStream();
    });
  }

  Future<void> _startQrStream() async {
    final cam = _cameraService;
    if (cam == null || !cam.isLiveCamera) return;
    if (cam.isStreaming) {
      await cam.stopImageStream();
    }
    await cam.startImageStream(_onCameraFrame);
  }

  Future<void> _stopQrStream() async {
    final cam = _cameraService;
    if (cam != null && cam.isStreaming) {
      await cam.stopImageStream();
    }
  }

  void _onCameraFrame(CameraImage image) async {
    if (_isDecodingFrame || _isNavigatingToDetail || !mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScanAttemptMs < 120) return;
    _lastScanAttemptMs = now;
    _isDecodingFrame = true;

    try {
      final String? qrText = _decodeCameraImage(image);
      if (qrText != null && qrText.trim().isNotEmpty && mounted) {
        await _handleDecodedQrText(qrText.trim());
      }
    } catch (_) {
      // Ignore frame decode errors
    } finally {
      _isDecodingFrame = false;
    }
  }

  String? _decodeCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final int width = image.width;
    final int height = image.height;
    if (width <= 0 || height <= 0) return null;

    final Plane plane0 = image.planes[0];
    final Uint8List bytes = plane0.bytes;
    final int bytesPerRow = plane0.bytesPerRow;
    final int bytesPerPixel = plane0.bytesPerPixel ?? 1;

    final Int8List luma = Int8List(width * height);

    if (image.format.group == ImageFormatGroup.bgra8888 || bytesPerPixel == 4) {
      for (int y = 0; y < height; y++) {
        final int srcRow = y * bytesPerRow;
        final int dstRow = y * width;
        for (int x = 0; x < width; x++) {
          final int idx = srcRow + (x << 2);
          if (idx + 2 < bytes.length) {
            final int b = bytes[idx];
            final int g = bytes[idx + 1];
            final int r = bytes[idx + 2];
            luma[dstRow + x] = ((r + (g << 1) + b) >> 2);
          }
        }
      }
    } else {
      // YUV420 plane 0 is direct grayscale luminance
      for (int y = 0; y < height; y++) {
        final int srcRow = y * bytesPerRow;
        final int dstRow = y * width;
        for (int x = 0; x < width; x++) {
          final int idx = srcRow + x;
          if (idx < bytes.length) {
            luma[dstRow + x] = bytes[idx];
          }
        }
      }
    }

    // 1. Try raw sensor orientation
    final String? direct = _tryDecodeLuminance(luma, width, height);
    if (direct != null) return direct;

    // 2. Try 90-degree clockwise rotated luminance (matches portrait phone orientation)
    final Int8List rotated = Int8List(width * height);
    final int rotW = height;
    final int rotH = width;
    for (int y = 0; y < height; y++) {
      final int srcRow = y * width;
      final int targetX = height - 1 - y;
      for (int x = 0; x < width; x++) {
        rotated[x * rotW + targetX] = luma[srcRow + x];
      }
    }
    return _tryDecodeLuminance(rotated, rotW, rotH);
  }

  String? _tryDecodeLuminance(Int8List luma, int width, int height) {
    final source = RGBLuminanceSource.crop(luma, width, height, 0, 0, width, height);

    try {
      final res = _qrReader.decode(BinaryBitmap(HybridBinarizer(source)));
      if (res.text.isNotEmpty) return res.text;
    } catch (_) {}

    try {
      final res = _qrReader.decode(BinaryBitmap(GlobalHistogramBinarizer(source)));
      if (res.text.isNotEmpty) return res.text;
    } catch (_) {}

    try {
      final res = _qrReader.decode(BinaryBitmap(HybridBinarizer(source.invert())));
      if (res.text.isNotEmpty) return res.text;
    } catch (_) {}

    return null;
  }

  Future<void> _pickQrFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final int w = decoded.width;
      final int h = decoded.height;
      final Int8List luma = Int8List(w * h);

      for (int y = 0; y < h; y++) {
        final int rowOff = y * w;
        for (int x = 0; x < w; x++) {
          final p = decoded.getPixel(x, y);
          luma[rowOff + x] = ((p.r.toInt() + (p.g.toInt() << 1) + p.b.toInt()) >> 2);
        }
      }

      final String? qrText = _tryDecodeLuminance(luma, w, h);
      if (qrText != null && qrText.trim().isNotEmpty) {
        await _handleDecodedQrText(qrText.trim());
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC53030),
            content: Text(
              'No valid QR code found in the selected photo.',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC53030),
            content: Text('Failed to read QR image: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleDecodedQrText(String rawText) async {
    if (_isNavigatingToDetail || !mounted) return;

    final Landmark? landmark = LandmarkDataService.findByQrContent(rawText);
    if (landmark != null) {
      _isNavigatingToDetail = true;
      HapticFeedback.mediumImpact();

      await _stopQrStream();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LandmarkDetailScreen(landmark: landmark),
        ),
      );

      if (mounted) {
        setState(() {
          _isNavigatingToDetail = false;
        });
        await _startQrStream();
      }
    }
  }

  @override
  void dispose() {
    _stopQrStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = Provider.of<CameraService>(context);

    return Scaffold(
      backgroundColor: deepEspresso,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Feed
          if (cameraService.isLiveCamera &&
              cameraService.controller != null &&
              cameraService.controller!.value.isInitialized)
            _buildCameraPreview(cameraService.controller!, context)
          else
            _buildCameraFallbackBackground(),

          // 2. Dark Vignette & QR Reticle Frame Overlay
          _buildQrScannerReticleOverlay(),

          // 3. Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: _buildTopBar(context, cameraService),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(CameraController controller, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double cameraAspect = 1.0 / controller.value.aspectRatio;
    final double screenAspect = screenSize.aspectRatio;

    double scale = 1.0;
    if (screenAspect < cameraAspect) {
      scale = cameraAspect / screenAspect;
    } else {
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

  Widget _buildCameraFallbackBackground() {
    return Container(
      color: deepEspresso,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: goldPrimary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'QR Scanner Ready',
              style: GoogleFonts.playfairDisplay(
                color: textParchment,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScannerReticleOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: yoloYellow.withValues(alpha: 0.85),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: yoloYellow.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated laser scan line
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              height: 2.5,
              decoration: BoxDecoration(
                color: yoloYellow,
                boxShadow: [
                  BoxShadow(
                    color: yoloYellow.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -95, end: 95, duration: 1800.ms, curve: Curves.easeInOut),

            // Center subtle QR watermark
            Icon(
              Icons.qr_code_2,
              size: 72,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CameraService cameraService) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE1C1814),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: goldPrimary.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        children: [
          // Back to mode selector
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF28221B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: goldPrimary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_ios_new, color: goldLight, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    'MODES',
                    style: GoogleFonts.outfit(
                      color: textParchment,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, color: yoloYellow, size: 16),
              const SizedBox(width: 6),
              Text(
                'LANDMARK QR SCANNER',
                style: GoogleFonts.outfit(
                  color: textParchment,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Torch button
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              cameraService.isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: cameraService.isFlashOn ? yoloYellow : const Color(0xFF9E8E81),
              size: 19,
            ),
            tooltip: 'Toggle Flash',
            onPressed: () => cameraService.toggleFlash(),
          ),
          // Pick QR from gallery
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.photo_library_outlined, color: goldLight, size: 19),
            tooltip: 'Scan QR Image from Gallery',
            onPressed: _pickQrFromGallery,
          ),
        ],
      ),
    );
  }
}

