import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../models/landmark.dart';
import '../services/camera_service.dart';
import '../services/landmark_data_service.dart';
import '../services/ml_service.dart';

class ScannerProvider extends ChangeNotifier {
  final MLService mlService;
  CameraService? _cameraService;

  bool _isScanning = true;
  bool _isProcessingFrame = false;
  RecognitionResult? _currentResult;
  Timer? _scanTimer;
  String _activeSimulatedLandmarkKey = 'cathedral';
  final List<RecognitionResult> _discoveryHistory = [];
  double _simulatedDistance = 45.0;
  double _headingDegrees = 42.0;
  double _pitchDegrees = -5.0;
  bool _isAudioPlaying = false;

  ScannerProvider({
    required this.mlService,
    CameraService? cameraService,
  }) {
    _cameraService = cameraService;
    if (mlService.labels.isNotEmpty) {
      _activeSimulatedLandmarkKey = mlService.labels.first;
    }
    startScanning();
  }

  bool get isScanning => _isScanning;
  bool get isProcessingFrame => _isProcessingFrame;
  RecognitionResult? get currentResult => _currentResult;
  String get activeSimulatedLandmarkKey => _activeSimulatedLandmarkKey;
  List<RecognitionResult> get discoveryHistory => List.unmodifiable(_discoveryHistory);
  double get simulatedDistance => _simulatedDistance;
  double get headingDegrees => _headingDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isAudioPlaying => _isAudioPlaying;
  CameraService? get cameraService => _cameraService;

  void bindCameraService(CameraService service) {
    if (_cameraService == service) return;
    _cameraService = service;
    if (_isScanning) {
      startScanning();
    }
  }

  void startScanning() {
    _isScanning = true;
    _scanTimer?.cancel();

    if (_cameraService != null && _cameraService!.isLiveCamera) {
      // Start live hardware camera stream for real model inference
      _cameraService!.startImageStream(_onCameraFrame);
    } else {
      // Fallback timer for simulated feed / desktop testing
      _scanTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
        _executeSimulatedInference();
      });
    }
    notifyListeners();
  }

  void stopScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    _cameraService?.stopImageStream();
    notifyListeners();
  }

  void toggleScanning() {
    if (_isScanning) {
      stopScanning();
    } else {
      startScanning();
    }
  }

  /// Real-time camera image stream callback
  void _onCameraFrame(CameraImage image) async {
    if (!_isScanning || _isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final result = await mlService.processCameraImage(image);
      if (result != null) {
        _handleNewRecognition(result);
      }
    } catch (e) {
      debugPrint('Error processing camera frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Simulated / fallback inference loop
  Future<void> _executeSimulatedInference() async {
    if (!_isScanning) return;

    final result = await mlService.processFrame(
      forcedLandmarkKey: _activeSimulatedLandmarkKey,
    );

    _handleNewRecognition(result);
  }

  /// Manual snapshot scan (useful for taking a still photo to analyze)
  Future<void> scanSnapshot() async {
    if (_cameraService == null) return;
    final bytes = await _cameraService!.captureFrameBytes();
    if (bytes != null) {
      final result = await mlService.processImageBytes(bytes);
      if (result != null) {
        _handleNewRecognition(result);
      }
    }
  }

  void _handleNewRecognition(RecognitionResult result) {
    _currentResult = result;

    if (result.landmark != null) {
      _simulatedDistance = result.landmark!.estimatedDistanceMeters;
    }

    // Record landmark discovery if confidence is high and distinct from the last entry
    if (result.overallConfidence >= 0.55 && result.landmark != null) {
      if (_discoveryHistory.isEmpty ||
          _discoveryHistory.first.label != result.label) {
        _discoveryHistory.insert(0, result);
        if (_discoveryHistory.length > 20) {
          _discoveryHistory.removeLast();
        }
      }
    }

    notifyListeners();
  }

  void setActiveLandmark(String landmarkKey) {
    _activeSimulatedLandmarkKey = landmarkKey;
    final landmark = LandmarkDataService.findByLabel(landmarkKey);
    if (landmark != null) {
      _simulatedDistance = landmark.estimatedDistanceMeters;
    }
    notifyListeners();
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
    _scanTimer?.cancel();
    _cameraService?.stopImageStream();
    super.dispose();
  }
}
