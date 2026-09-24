import 'dart:async';
import 'package:flutter/material.dart';
import '../models/landmark.dart';
import '../services/landmark_data_service.dart';
import '../services/ml_service.dart';

class ScannerProvider extends ChangeNotifier {
  final MLService mlService;

  bool _isScanning = true;
  RecognitionResult? _currentResult;
  Timer? _scanTimer;
  String _activeSimulatedLandmarkKey = 'eiffel_tower';
  final List<RecognitionResult> _discoveryHistory = [];
  double _simulatedDistance = 85.0;
  double _headingDegrees = 42.0;
  double _pitchDegrees = -5.0;
  bool _isAudioPlaying = false;

  ScannerProvider({required this.mlService}) {
    startScanning();
  }

  bool get isScanning => _isScanning;
  RecognitionResult? get currentResult => _currentResult;
  String get activeSimulatedLandmarkKey => _activeSimulatedLandmarkKey;
  List<RecognitionResult> get discoveryHistory => List.unmodifiable(_discoveryHistory);
  double get simulatedDistance => _simulatedDistance;
  double get headingDegrees => _headingDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isAudioPlaying => _isAudioPlaying;

  void startScanning() {
    _isScanning = true;
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      _executeInference();
    });
    notifyListeners();
  }

  void stopScanning() {
    _isScanning = false;
    _scanTimer?.cancel();
    notifyListeners();
  }

  void toggleScanning() {
    if (_isScanning) {
      stopScanning();
    } else {
      startScanning();
    }
  }

  Future<void> _executeInference() async {
    if (!_isScanning) return;

    final result = await mlService.processFrame(
      forcedLandmarkKey: _activeSimulatedLandmarkKey,
    );

    _currentResult = result;

    // Record discovery if confidence is high and not already latest
    if (result.overallConfidence > 0.88) {
      if (_discoveryHistory.isEmpty ||
          _discoveryHistory.last.label != result.label) {
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
    super.dispose();
  }
}
