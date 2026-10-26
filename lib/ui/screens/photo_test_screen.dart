import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/landmark.dart';
import '../../services/ml_service.dart';
import 'landmark_detail_screen.dart';

class PhotoTestScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final String? initialImageName;

  const PhotoTestScreen({
    super.key,
    this.initialImageBytes,
    this.initialImageName,
  });

  @override
  State<PhotoTestScreen> createState() => _PhotoTestScreenState();
}

class _PhotoTestScreenState extends State<PhotoTestScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  double _imageAspectRatio = 1.33;
  RecognitionResult? _result;
  bool _isProcessing = false;

  static const Color yoloYellow = Color(0xFFFFE600);

  @override
  void initState() {
    super.initState();
    if (widget.initialImageBytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runInference(widget.initialImageBytes!, widget.initialImageName ?? 'Initial Photo');
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        await _runInference(bytes, file.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC53030),
            content: Text('Could not open gallery photo: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loadSample(String assetPath, String name) async {
    try {
      setState(() => _isProcessing = true);
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      await _runInference(bytes, name);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sample photo: $e')),
        );
      }
    }
  }

  Future<void> _runInference(Uint8List bytes, String name) async {
    final mlService = Provider.of<MLService>(context, listen: false);

    double aspect = 1.33;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (frame.image.height > 0) {
        aspect = frame.image.width / frame.image.height;
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _imageBytes = bytes;
      _imageName = name;
      _imageAspectRatio = aspect;
      _result = null;
    });

    final res = await mlService.processImageBytes(bytes);

    if (mounted) {
      setState(() {
        _result = res;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12100E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1814),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFD4AF37), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHOTO MODEL TESTER',
              style: GoogleFonts.outfit(
                color: const Color(0xFFF7EBE1),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (_imageName != null)
              Text(
                _imageName!,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFC7B9AC),
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: yoloYellow),
            tooltip: 'Adjust Strictness',
            onPressed: _showStrictnessModal,
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate, color: yoloYellow),
            tooltip: 'Pick New Photo',
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: _imageBytes == null ? _buildEmptyState() : _buildResultView(),
    );
  }

  void _showStrictnessModal() {
    final mlService = Provider.of<MLService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double currentThreshold = mlService.confidenceThreshold;
            final int thresholdPct = (currentThreshold * 100).round();

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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: yoloYellow, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'DETECTION STRICTNESS',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFF7EBE1),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: yoloYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$thresholdPct%',
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: yoloYellow,
                      inactiveTrackColor: const Color(0xFF332B24),
                      thumbColor: yoloYellow,
                    ),
                    child: Slider(
                      value: thresholdPct.toDouble(),
                      min: 60.0,
                      max: 99.0,
                      divisions: 39,
                      onChanged: (val) {
                        setModalState(() {
                          mlService.setConfidenceThreshold(val / 100.0);
                        });
                        if (_imageBytes != null && _imageName != null) {
                          _runInference(_imageBytes!, _imageName!);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yoloYellow,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'DONE',
                      style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1814),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: yoloYellow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: yoloYellow, size: 38),
                ),
                const SizedBox(height: 16),
                Text(
                  'TEST TRAINED MODEL DIRECTLY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFF7EBE1),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload landmark photos from your device gallery to test the TFLite model with full class probability breakdowns and bounding box previews.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFC7B9AC),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.upload_file, color: Colors.black, size: 18),
                  label: Text(
                    'CHOOSE FROM GALLERY',
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yoloYellow,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Quick-test samples header
          Text(
            'QUICK-TEST SAMPLE PHOTOS',
            style: GoogleFonts.outfit(
              color: const Color(0xFFE5C158),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // 3 Sample Landmark Cards
          _buildSampleCard(
            title: 'San Sebastian Cathedral',
            subtitle: '1876 Coral-stone Cathedral',
            assetPath: 'assets/landmarks/cathedral.jpg',
            labelKey: 'cathedral',
          ),
          const SizedBox(height: 12),
          _buildSampleCard(
            title: 'La Consolacion College Bacolod',
            subtitle: '1919 Augustinian Sister Institution',
            assetPath: 'assets/landmarks/lccb.jpg',
            labelKey: 'lccb',
          ),
          const SizedBox(height: 12),
          _buildSampleCard(
            title: 'Bacolod Public Plaza',
            subtitle: '1927 Classical Gazebo & Bandstand',
            assetPath: 'assets/landmarks/plaza.jpg',
            labelKey: 'plaza',
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCard({
    required String title,
    required String subtitle,
    required String assetPath,
    required String labelKey,
  }) {
    return GestureDetector(
      onTap: () => _loadSample(assetPath, title),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1814),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                assetPath,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: const Color(0xFF28221B),
                  child: const Icon(Icons.account_balance, color: Color(0xFFD4AF37)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFF7EBE1),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFC7B9AC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: yoloYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: yoloYellow.withValues(alpha: 0.5)),
              ),
              child: Text(
                'TEST',
                style: GoogleFonts.outfit(
                  color: yoloYellow,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final res = _result;
    final landmark = res?.landmark;
    final isDetected = landmark != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo Display with Yellow YOLO Bounding Box Overlay
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: const Color(0xFF161311),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _imageAspectRatio,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final actualW = constraints.maxWidth;
                        final actualH = constraints.maxHeight;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Base Photo
                            Image.memory(
                              _imageBytes!,
                              fit: BoxFit.fill,
                            ),

                            // Pure Outline Yellow Bounding Box Overlay (Matches user request: outline only)
                            if (!_isProcessing && isDetected && res?.boundingBox != null)
                              Builder(
                                builder: (context) {
                                  final box = res!.boundingBox!;
                                  final left = box.left * actualW;
                                  final top = box.top * actualH;
                                  final width = box.width * actualW;
                                  final height = box.height * actualH;
                                  final matchPct = (res.overallConfidence * 100).toStringAsFixed(0);

                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Positioned(
                                        left: left,
                                        top: top,
                                        width: width,
                                        height: height,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Yellow outline box (PURE OUTLINE - NO FILL)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                border: Border.all(color: yoloYellow, width: 2.5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),

                                            // Top attached label tag
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
                                                child: Text(
                                                  '${landmark.name.toUpperCase()}  $matchPct%',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.black,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // Processing overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: yoloYellow),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Detection Outcome Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDetected ? const Color(0xFF1C1814) : const Color(0xFF231A18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDetected ? const Color(0xFF68D391) : const Color(0xFFE53E3E).withValues(alpha: 0.6),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDetected ? Icons.check_circle : Icons.warning_amber,
                  color: isDetected ? const Color(0xFF68D391) : const Color(0xFFE53E3E),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDetected ? landmark.name : 'UNRECOGNIZED SCENE',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFF7EBE1),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDetected
                            ? 'Classified with ${((res?.overallConfidence ?? 0) * 100).toStringAsFixed(1)}% match in ${res?.inferenceTimeMs}ms'
                            : 'No trained landmark reached the required confidence threshold.',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFC7B9AC),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Probabilities Breakdown
          if (res != null && res.allProbabilities.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1814),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CLASS PROBABILITIES',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFE5C158),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        '${res.inferenceTimeMs} ms',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFC7B9AC),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...res.allProbabilities.entries.map((e) {
                    final isTop = e.key == res.label && isDetected;
                    final pct = (e.value * 100).clamp(0.0, 100.0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                e.key.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: isTop ? yoloYellow : const Color(0xFFD0C3B5),
                                  fontSize: 11,
                                  fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.outfit(
                                  color: isTop ? yoloYellow : const Color(0xFFD0C3B5),
                                  fontSize: 11,
                                  fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (e.value).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFF28221B),
                              valueColor: AlwaysStoppedAnimation(
                                isTop ? yoloYellow : const Color(0xFFD4AF37).withValues(alpha: 0.4),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Action Buttons
          if (isDetected) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LandmarkDetailScreen(landmark: landmark),
                  ),
                );
              },
              icon: const Icon(Icons.auto_stories, color: Colors.black, size: 18),
              label: Text(
                'EXPLORE FULL HISTORY & AUDIO GUIDE',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: yoloYellow,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
          ],

          OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.add_photo_alternate, color: Color(0xFFD4AF37), size: 18),
            label: Text(
              'TEST ANOTHER PHOTO',
              style: GoogleFonts.outfit(
                color: const Color(0xFFE5C158),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
