import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/landmark.dart';
import '../services/camera_service.dart';
import '../services/ml_service.dart';

class ScannerProvider extends ChangeNotifier {
  final MLService mlService;
  CameraService? _cameraService;

  bool _isScanning = true;
  bool _isProcessingFrame = false;
  RecognitionResult? _currentResult;

  // Temporal multi-frame stability counters (avoids noise blips from random objects)
  String? _candidateLabel;
  int _consecutiveHitCount = 0;
  int _lastFrameTimestamp = 0;
  static const int _requiredConsecutiveHits = 2;

  final List<RecognitionResult> _discoveryHistory = [];
  double _simulatedDistance = 45.0;
  double _headingDegrees = 42.0;
  double _pitchDegrees = -5.0;
  bool _isAudioPlaying = false;

  ScannerProvider({
    required this.mlService,
    CameraService? cameraService,
  }) {
    if (cameraService != null) {
      bindCameraService(cameraService);
    }
  }

  double get confidenceThreshold => mlService.confidenceThreshold;

  void setConfidenceThreshold(double value) {
    mlService.setConfidenceThreshold(value);
    if (_currentResult != null &&
        _currentResult!.overallConfidence < mlService.confidenceThreshold) {
      clearCurrentResult();
    } else {
      notifyListeners();
    }
  }

  bool get isScanning => _isScanning;
  bool get isProcessingFrame => _isProcessingFrame;
  RecognitionResult? get currentResult => _currentResult;
  List<RecognitionResult> get discoveryHistory => List.unmodifiable(_discoveryHistory);
  double get simulatedDistance => _simulatedDistance;
  double get headingDegrees => _headingDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isAudioPlaying => _isAudioPlaying;
  CameraService? get cameraService => _cameraService;

  /// Manually clears current recognition and turns off bounding box and bottom card
  void clearCurrentResult() {
    _currentResult = null;
    _candidateLabel = null;
    _consecutiveHitCount = 0;
    notifyListeners();
  }

  void bindCameraService(CameraService service) {
    if (_cameraService != service) {
      _cameraService?.removeListener(_onCameraStateChanged);
      _cameraService = service;
      _cameraService?.addListener(_onCameraStateChanged);
    }
    _checkAndStartStreaming();
  }

  void _onCameraStateChanged() {
    _checkAndStartStreaming();
    notifyListeners();
  }

  void _checkAndStartStreaming() {
    if (!_isScanning) return;
    if (_cameraService != null &&
        _cameraService!.isLiveCamera &&
        !_cameraService!.isStreaming) {
      _cameraService!.startImageStream(_onCameraFrame);
    }
  }

  void startScanning() {
    _isScanning = true;
    _candidateLabel = null;
    _consecutiveHitCount = 0;
    _checkAndStartStreaming();
    notifyListeners();
  }

  void stopScanning() {
    _isScanning = false;
    _cameraService?.stopImageStream();
    _candidateLabel = null;
    _consecutiveHitCount = 0;
    _currentResult = null;
    notifyListeners();
  }

  void toggleScanning() {
    if (_isScanning) {
      stopScanning();
    } else {
      startScanning();
    }
  }

  /// Real-time camera image stream callback for live model inference
  void _onCameraFrame(CameraImage image) async {
    if (!_isScanning || _isProcessingFrame) return;

    // Pace inferences to ~5-6 per second (170ms interval) to keep UI smooth and 60fps
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameTimestamp < 170) {
      return;
    }
    _lastFrameTimestamp = now;
    _isProcessingFrame = true;

    try {
      final sensorOrientation = _cameraService?.sensorOrientation ?? 90;
      final result = await mlService.processCameraImage(
        image,
        sensorOrientation: sensorOrientation,
      );
      if (result != null) {
        _handleNewRecognition(result);
      }
    } catch (e) {
      debugPrint('Error processing camera frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// High-accuracy snapshot scan triggered by tapping the shutter/scan button
  Future<RecognitionResult?> scanSnapshot() async {
    if (_cameraService == null) return null;
    final bytes = await _cameraService!.captureFrameBytes();
    if (bytes != null) {
      final result = await mlService.processImageBytes(bytes);
      if (result != null && result.landmark != null && result.overallConfidence >= 0.85) {
        _currentResult = result;
        _candidateLabel = result.label;
        _consecutiveHitCount = 2;
        _simulatedDistance = result.landmark!.estimatedDistanceMeters;

        if (_discoveryHistory.isEmpty ||
            _discoveryHistory.first.label != result.label) {
          _discoveryHistory.insert(0, result);
          if (_discoveryHistory.length > 25) {
            _discoveryHistory.removeLast();
          }
        }
        notifyListeners();
        return result;
      } else {
        // No monument detected in view -> turn off immediately!
        _currentResult = null;
        _candidateLabel = null;
        _consecutiveHitCount = 0;
        notifyListeners();
        return null;
      }
    }
    return null;
  }

  void _handleNewRecognition(RecognitionResult result) {
    final bool isLandmarkHit = result.landmark != null &&
        result.overallConfidence >= mlService.confidenceThreshold;

    if (isLandmarkHit) {
      if (result.label == _candidateLabel) {
        _consecutiveHitCount++;
      } else {
        _candidateLabel = result.label;
        _consecutiveHitCount = 1;
      }

      // Require 2 consecutive confident hits to prevent single-frame false triggers
      if (_consecutiveHitCount >= _requiredConsecutiveHits) {
        final bool isFirstLock = _currentResult?.landmark == null ||
            _currentResult?.label != result.label;
        _currentResult = result;
        _simulatedDistance = result.landmark!.estimatedDistanceMeters;

        if (isFirstLock) {
          if (_discoveryHistory.isEmpty ||
              _discoveryHistory.first.label != result.label) {
            _discoveryHistory.insert(0, result);
            if (_discoveryHistory.length > 25) {
              _discoveryHistory.removeLast();
            }
          }
        }
        notifyListeners();
      }
    } else {
      _candidateLabel = null;
      _consecutiveHitCount = 0;

      // When pointing at desk, floor, or away from monument: IMMEDIATELY TURN OFF!
      if (_currentResult != null) {
        _currentResult = null;
        notifyListeners();
      }
    }
  }

  void setSimulatedTelemetry({
    double? heading,
    double? pitch,
    double? distance,
  }) {
    if (heading != null) _headingDegrees = heading;
    if (pitch != null) _pitchDegrees = pitch;
    if (distance != null) _simulatedDistance = distance;
    notifyListeners();
  }

  void toggleAudioGuide() {
    _isAudioPlaying = !_isAudioPlaying;
    notifyListeners();
  }

  void clearHistory() {
    _discoveryHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraService?.removeListener(_onCameraStateChanged);
    _cameraService?.stopImageStream();
    super.dispose();
  }
}
