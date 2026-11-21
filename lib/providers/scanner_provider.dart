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
  double _liveAccuracy = 0.0;

  // Temporal multi-frame stability counters (avoids noise blips from random objects)
  String? _candidateLabel;
  int _consecutiveHitCount = 0;
  int _lastFrameTimestamp = 0;
  static const int _requiredConsecutiveHits = 5;

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
  double get liveAccuracy => _liveAccuracy;
  List<RecognitionResult> get discoveryHistory => List.unmodifiable(_discoveryHistory);
  double get simulatedDistance => _simulatedDistance;
  double get headingDegrees => _headingDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isAudioPlaying => _isAudioPlaying;
  CameraService? get cameraService => _cameraService;

  /// Manually clears current recognition and turns off bounding box and bottom card
  void clearCurrentResult() {
    _currentResult = null;
    _liveAccuracy = 0.0;
    _candidateLabel = null;
    _consecutiveHitCount = 0;
    mlService.resetTracking();
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
    _liveAccuracy = 0.0;
    mlService.resetTracking();
    notifyListeners();
  }

  void toggleScanning() {
    if (_isScanning) {
      stopScanning();
    } else {
      startScanning();
    }
  }

  /// Real-time camera image stream callback for live model inference & object tracking
  void _onCameraFrame(CameraImage image) async {
    if (!_isScanning || _isProcessingFrame) return;

    // Process frames continuously back-to-back like its411yolo for real-time object tracking
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFrameTimestamp < 16) {
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
      if (result != null && result.landmark != null && result.overallConfidence >= mlService.confidenceThreshold) {
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
    final double prevAccuracy = _liveAccuracy;

    final bool isAlreadyLockedSameClass =
        _currentResult?.landmark != null && _currentResult?.label == result.label;
    final bool isLandmarkHit = result.landmark != null &&
        (isAlreadyLockedSameClass ||
            result.overallConfidence >= mlService.confidenceThreshold);

    if (isLandmarkHit) {
      if (result.label == _candidateLabel) {
        _consecutiveHitCount++;
      } else {
        _candidateLabel = result.label;
        _consecutiveHitCount = 1;
      }

      // Require 2 consecutive hits for initial lock, then update every single frame while tracking
      if (_consecutiveHitCount >= _requiredConsecutiveHits || isAlreadyLockedSameClass) {
        final bool isFirstLock = _currentResult?.landmark == null ||
            _currentResult?.label != result.label;
        _currentResult = result;
        _liveAccuracy = result.overallConfidence.clamp(0.0, 1.0);
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
      } else {
        // First hit (awaiting 2nd consecutive confirmation): show high progress but below 80%
        final double target =
            (_scaledSearchingAccuracy(result.overallConfidence)).clamp(0.0, 0.79);
        _liveAccuracy = (_liveAccuracy * 0.4 + target * 0.6).clamp(0.0, 0.79);
        if ((_liveAccuracy - prevAccuracy).abs() >= 0.005) {
          notifyListeners();
        }
      }
    } else {
      _candidateLabel = null;
      _consecutiveHitCount = 0;

      // Searching / unconfirmed frame: scale relative to lock threshold and keep strictly below 80%
      if (result.allProbabilities.isEmpty) {
        _liveAccuracy = 0.0;
      } else {
        final double rawTop = result.allProbabilities.values
            .reduce((a, b) => a > b ? a : b);
        final double target = _scaledSearchingAccuracy(rawTop);
        _liveAccuracy = (_liveAccuracy * 0.6 + target * 0.4).clamp(0.0, 0.79);
      }

      // When pointing at desk, floor, or away from monument: IMMEDIATELY TURN OFF!
      if (_currentResult != null) {
        _currentResult = null;
        notifyListeners();
      } else if ((_liveAccuracy - prevAccuracy).abs() >= 0.005) {
        notifyListeners();
      }
    }
  }

  /// Maps raw unconfirmed softmax probability [0.34..confidenceThreshold] into [0.0..0.79]
  /// so the indicator only reaches 80%+ when a landmark is genuinely confirmed and locked.
  double _scaledSearchingAccuracy(double rawTop) {
    final double threshold = mlService.confidenceThreshold;
    final double span = (threshold - 0.34).clamp(0.10, 1.0);
    final double normalized = ((rawTop - 0.34) / span).clamp(0.0, 1.0);
    return normalized * 0.79;
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
