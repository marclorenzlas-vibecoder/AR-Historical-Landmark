import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'tflite_adapter/tflite_adapter.dart' as tflite;
import 'tflite_adapter/tflite_adapter.dart' show Interpreter, InterpreterOptions, IsolateInterpreter;
import '../models/landmark.dart';
import 'landmark_data_service.dart';

enum MLInferenceMode {
  tfliteHardware,
  simulationEngine,
}

class MLService extends ChangeNotifier {
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  tflite.Interpreter? _yoloInterpreter;
  tflite.Interpreter? _cnnInterpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  MLInferenceMode _mode = MLInferenceMode.simulationEngine;
  String _statusMessage = 'Initializing ML Core...';
  int _lastInferenceTimeMs = 24;

  // Pre-allocated coordinate lookup tables for 224x224 CNN crop
  final Int32List _srcXTable = Int32List(224);
  final Int32List _srcYTable = Int32List(224);

  // Pre-allocated 64x64 full-frame spatial localization buffers (zero GC pressure per frame)
  static const int _gridSize = 64;
  static const int _gridCells = _gridSize * _gridSize;
  final Float32List _gridR = Float32List(_gridCells);
  final Float32List _gridG = Float32List(_gridCells);
  final Float32List _gridB = Float32List(_gridCells);
  final Float32List _rawSal = Float32List(_gridCells);
  final Float32List _smoothSal = Float32List(_gridCells);
  final Uint8List _visited = Uint8List(_gridCells);
  final Int32List _bfsQueue = Int32List(_gridCells);
  final Float32List _colWeight = Float32List(_gridSize);
  final Float32List _rowWeight = Float32List(_gridSize);

  // Real-time object tracking state (enables YOLO-style continuous box following)
  BoundingBox? _trackedBox;
  String? _lockedLandmarkKey;
  double _lockedConfidence = 0.0;
  int _framesSinceStrongHit = 0;

  // Reusable 4D tensor buffer to eliminate 50,000 List allocations per camera frame
  final List<List<List<List<double>>>> _inputTensorBuffer = List.generate(
    1,
    (_) => List.generate(
      224,
      (_) => List.generate(
        224,
        (_) => [0.0, 0.0, 0.0],
      ),
    ),
  );

  double _confidenceThreshold = 0.88; // Balanced default for fast lock & smooth tracking

  bool get isInitialized => _isInitialized;
  MLInferenceMode get mode => _mode;
  String get statusMessage => _statusMessage;
  int get lastInferenceTimeMs => _lastInferenceTimeMs;
  List<String> get labels => _labels;
  Interpreter? get interpreter => _interpreter;
  double get confidenceThreshold => _confidenceThreshold;

  set confidenceThreshold(double value) {
    final clamped = value.clamp(0.50, 0.99);
    if ((_confidenceThreshold - clamped).abs() > 0.001) {
      _confidenceThreshold = clamped;
      notifyListeners();
    }
  }

  void setConfidenceThreshold(double value) {
    confidenceThreshold = value;
  }

  void resetTracking() {
    _trackedBox = null;
    _lockedLandmarkKey = null;
    _lockedConfidence = 0.0;
    _framesSinceStrongHit = 0;
  }

  Future<void> initialize() async {
    try {
      // 1. Load labels directly from model/labels/labels.txt
      try {
        final labelData = await rootBundle.loadString('model/labels/labels.txt');
        _labels = labelData
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (e) {
        try {
          final labelData = await rootBundle.loadString('assets/labels/labels.txt');
          _labels = labelData
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } catch (e2) {
          debugPrint('Warning: Could not load labels.txt: $e2');
          _labels = LandmarkDataService.allLandmarks.map((l) => l.labelKey).toList();
        }
      }

      // 2. Load TFLite model directly from model/model.tflite with multi-threaded hardware options
      bool modelLoaded = false;
      final options = InterpreterOptions()..threads = 2;
      try {
        _interpreter = await Interpreter.fromAsset('model/model.tflite', options: options);
        _cnnInterpreter ??= _interpreter;
        modelLoaded = true;
      } catch (e) {
        try {
          _interpreter = await Interpreter.fromAsset('assets/models/model.tflite', options: options);
          _cnnInterpreter ??= _interpreter;
          modelLoaded = true;
        } catch (e2) {
          debugPrint('Model model.tflite not found or not supported on this platform: $e2');
        }
      }

      if (modelLoaded && _interpreter != null) {
        try {
          _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
          debugPrint('IsolateInterpreter created for background inference execution.');
        } catch (e) {
          debugPrint('IsolateInterpreter creation notice: $e');
        }
      }

      if (modelLoaded) {
        _mode = MLInferenceMode.tfliteHardware;
        _statusMessage = 'TFLite Hardware Acceleration Active (model.tflite)';
      } else {
        _mode = MLInferenceMode.simulationEngine;
        _statusMessage = 'AI Recognition Engine Ready (Simulation Fallback)';
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Simulation Mode Active: $e';
      _mode = MLInferenceMode.simulationEngine;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Process live camera frame with Stage 1 Spatial Object Localization & Tracking + Stage 2 ROI CNN
  Future<RecognitionResult?> processCameraImage(
    CameraImage image, {
    int sensorOrientation = 90,
  }) async {
    final activeInterpreter = _interpreter ?? _cnnInterpreter;
    if (activeInterpreter == null) {
      return null;
    }

    final stopwatch = Stopwatch()..start();

    try {
      final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
      final int uprightW = isRotated ? image.height : image.width;
      final int uprightH = isRotated ? image.width : image.height;
      final Size uprightImageSize = Size(uprightW.toDouble(), uprightH.toDouble());

      // 0. Quick scene texture check: avoid running model on flat walls, floors, ceilings, or covered lenses
      if (image.planes.isNotEmpty) {
        final Plane yPlane = image.planes[0];
        final Uint8List yBytes = yPlane.bytes;
        final int stride = yPlane.bytesPerRow;
        int minLuma = 255;
        int maxLuma = 0;
        for (int i = 1; i <= 5; i++) {
          final int sy = (image.height * i ~/ 6) * stride;
          for (int j = 1; j <= 5; j++) {
            final int sx = image.width * j ~/ 6;
            final int idx = sy + sx;
            if (idx < yBytes.length) {
              final int val = yBytes[idx];
              if (val < minLuma) minLuma = val;
              if (val > maxLuma) maxLuma = val;
            }
          }
        }
        if ((maxLuma - minLuma) < 22) {
          resetTracking();
          return RecognitionResult(
            label: 'searching',
            yoloConfidence: 0.0,
            cnnConfidence: 0.0,
            boundingBox: null,
            imageSize: uprightImageSize,
            inferenceTimeMs: 2,
            landmark: null,
            allProbabilities: const {},
          );
        }
      }

      // 1. Stage 1 (YOLO-style Localization): Sample upright 64x64 frame & detect object bounding box
      _extractUprightGridFromCamera(image, sensorOrientation);
      final BoundingBox? detectedBox = _localizeObjectInGrid();

      if (detectedBox == null) {
        resetTracking();
        return RecognitionResult(
          label: 'searching',
          yoloConfidence: 0.0,
          cnnConfidence: 0.0,
          boundingBox: null,
          imageSize: uprightImageSize,
          inferenceTimeMs: 4,
          landmark: null,
          allProbabilities: const {},
        );
      }

      // Smoothly track the localized object box across frames so the outline follows the object
      final BoundingBox smoothBox = _updateTrackedBox(detectedBox);

      // 2. Stage 2 (ROI-Guided CNN): Sample 224x224 upright tensor centered on the tracked object
      final double roiScale = (max(smoothBox.width, smoothBox.height) * 1.22).clamp(0.45, 1.0);
      final input = _preprocessCameraImage(
        image,
        224,
        224,
        sensorOrientation: sensorOrientation,
        roiCenterU: smoothBox.centerX,
        roiCenterV: smoothBox.centerY,
        roiScale: roiScale,
      );

      final numClasses = _labels.isNotEmpty ? _labels.length : 3;
      final output = List.generate(1, (_) => List.filled(numClasses, 0.0));

      if (_isolateInterpreter != null) {
        await _isolateInterpreter!.run(input, output);
      } else {
        activeInterpreter.run(input, output);
      }

      List<double> probabilities = _calculateSoftmax(output[0]);

      // If ROI is significantly off-center or zoomed, also check full center crop when acquiring lock
      if (_lockedLandmarkKey == null &&
          ((smoothBox.centerX - 0.5).abs() > 0.12 ||
              (smoothBox.centerY - 0.5).abs() > 0.12 ||
              roiScale < 0.85)) {
        final double roiBest = probabilities.reduce(max);
        if (roiBest < _confidenceThreshold) {
          final centerInput = _preprocessCameraImage(
            image,
            224,
            224,
            sensorOrientation: sensorOrientation,
            roiCenterU: 0.5,
            roiCenterV: 0.5,
            roiScale: 1.0,
          );
          final centerOutput = List.generate(1, (_) => List.filled(numClasses, 0.0));
          if (_isolateInterpreter != null) {
            await _isolateInterpreter!.run(centerInput, centerOutput);
          } else {
            activeInterpreter.run(centerInput, centerOutput);
          }
          final centerProbs = _calculateSoftmax(centerOutput[0]);
          if (centerProbs.reduce(max) > roiBest) {
            probabilities = centerProbs;
          }
        }
      }

      stopwatch.stop();
      _lastInferenceTimeMs = max(8, stopwatch.elapsedMilliseconds);

      int bestIdx = 0;
      double bestProb = probabilities[0];
      double secondProb = 0.0;

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > bestProb) {
          secondProb = bestProb;
          bestProb = probabilities[i];
          bestIdx = i;
        } else if (probabilities[i] > secondProb) {
          secondProb = probabilities[i];
        }
      }

      final Map<String, double> probMap = {};
      for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
        probMap[_labels[i]] = probabilities[i];
      }

      // 3. Decision & Continuous Object Tracking Hysteresis
      final double acquireThreshold = _confidenceThreshold;
      final double acquireMargin = (acquireThreshold * 0.45).clamp(0.18, 0.60);
      final bool isStrongHit = bestIdx >= 0 &&
          bestIdx < _labels.length &&
          bestProb >= acquireThreshold &&
          (bestProb - secondProb) >= acquireMargin;

      if (isStrongHit) {
        final detectedKey = _labels[bestIdx];
        final landmark = LandmarkDataService.findByLabel(detectedKey);
        if (landmark != null) {
          _lockedLandmarkKey = detectedKey;
          _lockedConfidence = bestProb;
          _framesSinceStrongHit = 0;

          return RecognitionResult(
            label: detectedKey,
            yoloConfidence: bestProb,
            cnnConfidence: bestProb,
            boundingBox: smoothBox,
            imageSize: uprightImageSize,
            inferenceTimeMs: _lastInferenceTimeMs,
            landmark: landmark,
            allProbabilities: probMap,
          );
        }
      }

      // If already locked onto a landmark, keep following the object seamlessly during camera pans/tilts
      if (_lockedLandmarkKey != null) {
        final int lockedIdx = _labels.indexOf(_lockedLandmarkKey!);
        final double lockedClassProb =
            (lockedIdx >= 0 && lockedIdx < probabilities.length) ? probabilities[lockedIdx] : 0.0;
        final double trackContinuationThreshold = (acquireThreshold - 0.25).clamp(0.45, 0.75);

        final bool continuesTracking =
            (bestIdx == lockedIdx && lockedClassProb >= trackContinuationThreshold) ||
                (_framesSinceStrongHit < 5 && lockedClassProb >= 0.38);

        if (continuesTracking) {
          _framesSinceStrongHit++;
          _lockedConfidence = _lockedConfidence * 0.75 + max(lockedClassProb, bestProb) * 0.25;
          final landmark = LandmarkDataService.findByLabel(_lockedLandmarkKey!);
          if (landmark != null) {
            return RecognitionResult(
              label: _lockedLandmarkKey!,
              yoloConfidence: _lockedConfidence,
              cnnConfidence: _lockedConfidence,
              boundingBox: smoothBox,
              imageSize: uprightImageSize,
              inferenceTimeMs: _lastInferenceTimeMs,
              landmark: landmark,
              allProbabilities: probMap,
            );
          }
        } else {
          resetTracking();
        }
      }

      return RecognitionResult(
        label: 'searching',
        yoloConfidence: 0.0,
        cnnConfidence: 0.0,
        boundingBox: null,
        imageSize: uprightImageSize,
        inferenceTimeMs: _lastInferenceTimeMs,
        landmark: null,
        allProbabilities: probMap,
      );
    } catch (e) {
      debugPrint('Real-time frame inference error: $e');
      return null;
    }
  }

  /// Samples the full upright camera frame into the 64x64 RGB grid for Stage 1 localization
  void _extractUprightGridFromCamera(CameraImage image, int sensorOrientation) {
    final int width = image.width;
    final int height = image.height;

    if (image.format.group == ImageFormatGroup.yuv420 || image.planes.length >= 3) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final Uint8List yBytes = yPlane.bytes;
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;

      final int yLen = yBytes.length;
      final int uLen = uBytes.length;
      final int vLen = vBytes.length;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final int vRowStride = vPlane.bytesPerRow;
      final int vPixelStride = vPlane.bytesPerPixel ?? 1;

      for (int gy = 0; gy < _gridSize; gy++) {
        final double v = (gy + 0.5) / _gridSize;
        final int rowOffset = gy * _gridSize;

        for (int gx = 0; gx < _gridSize; gx++) {
          final double u = (gx + 0.5) / _gridSize;

          int srcX;
          int srcY;
          if (sensorOrientation == 90) {
            srcX = (v * (width - 1)).round().clamp(0, width - 1);
            srcY = ((1.0 - u) * (height - 1)).round().clamp(0, height - 1);
          } else if (sensorOrientation == 270) {
            srcX = ((1.0 - v) * (width - 1)).round().clamp(0, width - 1);
            srcY = (u * (height - 1)).round().clamp(0, height - 1);
          } else if (sensorOrientation == 180) {
            srcX = ((1.0 - u) * (width - 1)).round().clamp(0, width - 1);
            srcY = ((1.0 - v) * (height - 1)).round().clamp(0, height - 1);
          } else {
            srcX = (u * (width - 1)).round().clamp(0, width - 1);
            srcY = (v * (height - 1)).round().clamp(0, height - 1);
          }

          final int yIndex = srcY * yRowStride + srcX;
          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;
          final int uIndex = uvY * uvRowStride + uvX * uvPixelStride;
          final int vIndex = uvY * vRowStride + uvX * vPixelStride;

          final int yVal = (yIndex >= 0 && yIndex < yLen) ? yBytes[yIndex] : 0;
          final int uVal = (uIndex >= 0 && uIndex < uLen) ? uBytes[uIndex] - 128 : 0;
          final int vVal = (vIndex >= 0 && vIndex < vLen) ? vBytes[vIndex] - 128 : 0;

          final int cellIdx = rowOffset + gx;
          _gridR[cellIdx] = (yVal + 1.402 * vVal).clamp(0.0, 255.0);
          _gridG[cellIdx] = (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0.0, 255.0);
          _gridB[cellIdx] = (yVal + 1.772 * uVal).clamp(0.0, 255.0);
        }
      }
      return;
    }

    if (image.format.group == ImageFormatGroup.bgra8888 || image.planes.length == 1) {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;
      final int bytesLen = bytes.length;

      for (int gy = 0; gy < _gridSize; gy++) {
        final double v = (gy + 0.5) / _gridSize;
        final int rowOffset = gy * _gridSize;

        for (int gx = 0; gx < _gridSize; gx++) {
          final double u = (gx + 0.5) / _gridSize;

          int srcX;
          int srcY;
          if (sensorOrientation == 90) {
            srcX = (v * (width - 1)).round().clamp(0, width - 1);
            srcY = ((1.0 - u) * (height - 1)).round().clamp(0, height - 1);
          } else if (sensorOrientation == 270) {
            srcX = ((1.0 - v) * (width - 1)).round().clamp(0, width - 1);
            srcY = (u * (height - 1)).round().clamp(0, height - 1);
          } else if (sensorOrientation == 180) {
            srcX = ((1.0 - u) * (width - 1)).round().clamp(0, width - 1);
            srcY = ((1.0 - v) * (height - 1)).round().clamp(0, height - 1);
          } else {
            srcX = (u * (width - 1)).round().clamp(0, width - 1);
            srcY = (v * (height - 1)).round().clamp(0, height - 1);
          }

          final int index = srcY * bytesPerRow + (srcX << 2);
          final int cellIdx = rowOffset + gx;
          if (index >= 0 && index + 2 < bytesLen) {
            _gridR[cellIdx] = bytes[index + 2].toDouble();
            _gridG[cellIdx] = bytes[index + 1].toDouble();
            _gridB[cellIdx] = bytes[index].toDouble();
          } else {
            _gridR[cellIdx] = 0.0;
            _gridG[cellIdx] = 0.0;
            _gridB[cellIdx] = 0.0;
          }
        }
      }
    }
  }

  /// Samples a decoded static image into the 64x64 RGB grid for Stage 1 localization
  void _extractGridFromDecodedImage(img.Image decoded) {
    final int width = decoded.width;
    final int height = decoded.height;

    for (int gy = 0; gy < _gridSize; gy++) {
      final int sy = ((gy + 0.5) * height / _gridSize).floor().clamp(0, height - 1);
      final int rowOffset = gy * _gridSize;
      for (int gx = 0; gx < _gridSize; gx++) {
        final int sx = ((gx + 0.5) * width / _gridSize).floor().clamp(0, width - 1);
        final p = decoded.getPixel(sx, sy);
        final int cellIdx = rowOffset + gx;
        _gridR[cellIdx] = p.r.toDouble();
        _gridG[cellIdx] = p.g.toDouble();
        _gridB[cellIdx] = p.b.toDouble();
      }
    }
  }

  /// Stage 1 Spatial Saliency + Connected-Component Object Localizer.
  /// Detects the tight bounding box of the landmark/object in the 64x64 frame grid.
  BoundingBox? _localizeObjectInGrid({bool useTrackingPrior = true}) {
    // 1. Estimate background color from low-gradient perimeter cells & top sky region
    double borderR = 0.0, borderG = 0.0, borderB = 0.0;
    int borderCount = 0;

    double topR = 0.0, topG = 0.0, topB = 0.0, topGradSum = 0.0;
    int topCount = 0;

    for (int gy = 0; gy < _gridSize; gy++) {
      for (int gx = 0; gx < _gridSize; gx++) {
        final bool isBorder = gx <= 1 || gx >= _gridSize - 2 || gy <= 1 || gy >= _gridSize - 2;
        if (!isBorder) continue;

        final int idx = gy * _gridSize + gx;
        final int nx = (gx + 1 < _gridSize) ? gx + 1 : gx - 1;
        final int ny = (gy + 1 < _gridSize) ? gy + 1 : gy - 1;
        final int nIdxX = gy * _gridSize + nx;
        final int nIdxY = ny * _gridSize + gx;

        final double localGrad = ((_gridR[idx] - _gridR[nIdxX]).abs() +
                (_gridG[idx] - _gridG[nIdxX]).abs() +
                (_gridB[idx] - _gridB[nIdxX]).abs() +
                (_gridR[idx] - _gridR[nIdxY]).abs() +
                (_gridG[idx] - _gridG[nIdxY]).abs() +
                (_gridB[idx] - _gridB[nIdxY]).abs()) /
            6.0;

        if (localGrad < 18.0) {
          borderR += _gridR[idx];
          borderG += _gridG[idx];
          borderB += _gridB[idx];
          borderCount++;
        }

        if (gy <= 2) {
          topR += _gridR[idx];
          topG += _gridG[idx];
          topB += _gridB[idx];
          topGradSum += localGrad;
          topCount++;
        }
      }
    }

    if (borderCount > 0) {
      borderR /= borderCount;
      borderG /= borderCount;
      borderB /= borderCount;
    } else {
      borderR = 128.0;
      borderG = 128.0;
      borderB = 128.0;
    }

    final double avgTopGrad = topCount > 0 ? topGradSum / topCount : 99.0;
    if (topCount > 0) {
      topR /= topCount;
      topG /= topCount;
      topB /= topCount;
    }

    // 2. Compute raw structural edge + foreground contrast activation per cell
    _rawSal.fillRange(0, _gridCells, 0.0);

    for (int gy = 1; gy < _gridSize - 1; gy++) {
      final int rowOffset = gy * _gridSize;
      for (int gx = 1; gx < _gridSize - 1; gx++) {
        final int idx = rowOffset + gx;

        final double dx = ((_gridR[idx + 1] - _gridR[idx - 1]).abs() +
                (_gridG[idx + 1] - _gridG[idx - 1]).abs() +
                (_gridB[idx + 1] - _gridB[idx - 1]).abs()) /
            3.0;
        final double dy = ((_gridR[idx + _gridSize] - _gridR[idx - _gridSize]).abs() +
                (_gridG[idx + _gridSize] - _gridG[idx - _gridSize]).abs() +
                (_gridB[idx + _gridSize] - _gridB[idx - _gridSize]).abs()) /
            3.0;

        double grad2 = 0.0;
        if (gx >= 2 && gx < _gridSize - 2 && gy >= 2 && gy < _gridSize - 2) {
          final double dx2 = ((_gridR[idx + 2] - _gridR[idx - 2]).abs() +
                  (_gridG[idx + 2] - _gridG[idx - 2]).abs() +
                  (_gridB[idx + 2] - _gridB[idx - 2]).abs()) /
              3.0;
          final double dy2 = ((_gridR[idx + 2 * _gridSize] - _gridR[idx - 2 * _gridSize]).abs() +
                  (_gridG[idx + 2 * _gridSize] - _gridG[idx - 2 * _gridSize]).abs() +
                  (_gridB[idx + 2 * _gridSize] - _gridB[idx - 2 * _gridSize]).abs()) /
              3.0;
          grad2 = (dx2 + dy2) * 0.5;
        }

        final double grad = (dx + dy) * 0.65 + grad2 * 0.35;
        final double bgDiff = ((_gridR[idx] - borderR).abs() +
                (_gridG[idx] - borderG).abs() +
                (_gridB[idx] - borderB).abs()) /
            3.0;

        // Suppress uniform sky/ceiling above the monument so the top outline hugs the roofline/towers
        if (gy < 26 && avgTopGrad < 16.0) {
          final double skyDiff = ((_gridR[idx] - topR).abs() +
                  (_gridG[idx] - topG).abs() +
                  (_gridB[idx] - topB).abs()) /
              3.0;
          if (skyDiff < 20.0 && grad < 14.0) {
            _rawSal[idx] = 0.0;
            continue;
          }
        }

        if (grad < 5.5 && bgDiff < 16.0) {
          _rawSal[idx] = 0.0;
        } else {
          _rawSal[idx] = grad * 0.72 + bgDiff * 0.28;
        }
      }
    }

    // 3. 5x5 spatial density filter + gentle tracking continuity prior
    _smoothSal.fillRange(0, _gridCells, 0.0);
    double maxSal = 0.0;
    double sumSal = 0.0;

    final BoundingBox? priorBox = useTrackingPrior ? _trackedBox : null;
    final double priorCx = priorBox?.centerX ?? 0.5;
    final double priorCy = priorBox?.centerY ?? 0.5;

    for (int gy = 2; gy < _gridSize - 2; gy++) {
      final double v = (gy + 0.5) / _gridSize;
      for (int gx = 2; gx < _gridSize - 2; gx++) {
        final double u = (gx + 0.5) / _gridSize;
        double acc = 0.0;
        for (int ky = -2; ky <= 2; ky++) {
          final int rOff = (gy + ky) * _gridSize + gx;
          acc += _rawSal[rOff - 2] +
              _rawSal[rOff - 1] +
              _rawSal[rOff] +
              _rawSal[rOff + 1] +
              _rawSal[rOff + 2];
        }
        double val = acc / 25.0;

        if (priorBox != null) {
          final double distSq =
              (u - priorCx) * (u - priorCx) + (v - priorCy) * (v - priorCy);
          val *= (1.0 + 0.22 * exp(-distSq / 0.22));
        }

        final int idx = gy * _gridSize + gx;
        _smoothSal[idx] = val;
        sumSal += val;
        if (val > maxSal) {
          maxSal = val;
        }
      }
    }

    if (maxSal < 6.5) {
      return null;
    }

    final double meanSal = sumSal / _gridCells;

    // 4. Find the dominant object core centroid
    final double coreThresh = maxSal * 0.60;
    double coreSumX = 0.0;
    double coreSumY = 0.0;
    double coreWeight = 0.0;

    for (int gy = 2; gy < _gridSize - 2; gy++) {
      final int rowOffset = gy * _gridSize;
      for (int gx = 2; gx < _gridSize - 2; gx++) {
        final double w = _smoothSal[rowOffset + gx];
        if (w >= coreThresh) {
          coreSumX += gx * w;
          coreSumY += gy * w;
          coreWeight += w;
        }
      }
    }

    if (coreWeight <= 0.0) {
      return null;
    }

    final int coreX = (coreSumX / coreWeight).round().clamp(2, _gridSize - 3);
    final int coreY = (coreSumY / coreWeight).round().clamp(2, _gridSize - 3);

    // 5. Connected-component region growing (with 2-cell bridge gap) around dominant object core
    _visited.fillRange(0, _gridCells, 0);
    _colWeight.fillRange(0, _gridSize, 0.0);
    _rowWeight.fillRange(0, _gridSize, 0.0);

    final double compThresh = max(meanSal * 1.12, maxSal * 0.27);
    int qHead = 0;
    int qTail = 0;

    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -3; dx <= 3; dx++) {
        final int sx = (coreX + dx).clamp(2, _gridSize - 3);
        final int sy = (coreY + dy).clamp(2, _gridSize - 3);
        final int sIdx = sy * _gridSize + sx;
        if (_visitedAt(sIdx) == 0 && _smoothSal[sIdx] >= compThresh) {
          _visited[sIdx] = 1;
          _bfsQueue[qTail++] = sIdx;
        }
      }
    }

    if (qTail == 0) {
      final int cIdx = coreY * _gridSize + coreX;
      _visited[cIdx] = 1;
      _bfsQueue[qTail++] = cIdx;
    }

    double totalCompWeight = 0.0;
    while (qHead < qTail) {
      final int currIdx = _bfsQueue[qHead++];
      final int cy = currIdx ~/ _gridSize;
      final int cx = currIdx - cy * _gridSize;
      final double w = _smoothSal[currIdx];

      _colWeight[cx] += w;
      _rowWeight[cy] += w;
      totalCompWeight += w;

      for (int ny = max(2, cy - 2); ny <= min(_gridSize - 3, cy + 2); ny++) {
        final int nRow = ny * _gridSize;
        for (int nx = max(2, cx - 2); nx <= min(_gridSize - 3, cx + 2); nx++) {
          final int nIdx = nRow + nx;
          if (_visited[nIdx] == 0 && _smoothSal[nIdx] >= compThresh) {
            _visited[nIdx] = 1;
            _bfsQueue[qTail++] = nIdx;
          }
        }
      }
    }

    if (totalCompWeight <= 0.0) {
      return null;
    }

    // 6. Compute tight 2.5% - 97.5% projection bounds of the connected object
    final double lowCut = totalCompWeight * 0.025;
    final double highCut = totalCompWeight * 0.975;

    int minX = 2, maxX = _gridSize - 3;
    double cumX = 0.0;
    for (int gx = 0; gx < _gridSize; gx++) {
      cumX += _colWeight[gx];
      if (cumX >= lowCut) {
        minX = gx;
        break;
      }
    }
    cumX = 0.0;
    for (int gx = 0; gx < _gridSize; gx++) {
      cumX += _colWeight[gx];
      if (cumX >= highCut) {
        maxX = gx;
        break;
      }
    }

    int minY = 2, maxY = _gridSize - 3;
    double cumY = 0.0;
    for (int gy = 0; gy < _gridSize; gy++) {
      cumY += _rowWeight[gy];
      if (cumY >= lowCut) {
        minY = gy;
        break;
      }
    }
    cumY = 0.0;
    for (int gy = 0; gy < _gridSize; gy++) {
      cumY += _rowWeight[gy];
      if (cumY >= highCut) {
        maxY = gy;
        break;
      }
    }

    // Add 1.5 grid cells (~2.3%) exterior framing pad
    final double rawLeft = ((minX - 1.5) / _gridSize).clamp(0.03, 0.86);
    final double rawTop = ((minY - 1.5) / _gridSize).clamp(0.04, 0.86);
    final double rawRight = ((maxX + 2.5) / _gridSize).clamp(rawLeft + 0.14, 0.97);
    final double rawBottom = ((maxY + 2.5) / _gridSize).clamp(rawTop + 0.14, 0.96);

    return BoundingBox(
      left: rawLeft,
      top: rawTop,
      right: rawRight,
      bottom: rawBottom,
    );
  }

  int _visitedAt(int idx) => _visited[idx];

  /// Velocity-adaptive EMA tracker so the outline smoothly & immediately follows the object
  BoundingBox _updateTrackedBox(BoundingBox rawBox) {
    if (_trackedBox == null) {
      _trackedBox = rawBox;
      return rawBox;
    }

    final prev = _trackedBox!;
    final double dx = rawBox.centerX - prev.centerX;
    final double dy = rawBox.centerY - prev.centerY;
    final double shift = sqrt(dx * dx + dy * dy);
    final double sizeDiff =
        (rawBox.width - prev.width).abs() + (rawBox.height - prev.height).abs();

    // Fast response when panning/moving object, rock-steady when holding still
    final double alpha = (0.35 + shift * 2.8 + sizeDiff * 1.4).clamp(0.35, 0.90);

    final smoothed = BoundingBox(
      left: (prev.left + (rawBox.left - prev.left) * alpha).clamp(0.02, 0.88),
      top: (prev.top + (rawBox.top - prev.top) * alpha).clamp(0.03, 0.88),
      right: (prev.right + (rawBox.right - prev.right) * alpha).clamp(0.14, 0.98),
      bottom: (prev.bottom + (rawBox.bottom - prev.bottom) * alpha).clamp(0.14, 0.97),
    );
    _trackedBox = smoothed;
    return smoothed;
  }

  List<double> _calculateSoftmax(List<double> rawScores) {
    final sumScores = rawScores.fold(0.0, (sum, val) => sum + val);
    final allPositive = rawScores.every((val) => val >= 0.0);
    if (allPositive && (sumScores - 1.0).abs() < 0.15) {
      return List<double>.from(rawScores);
    }
    double maxScore = rawScores.reduce((curr, next) => curr > next ? curr : next);
    double expSum = 0.0;
    final expScores = <double>[];
    for (final s in rawScores) {
      final e = exp((s - maxScore).clamp(-50.0, 50.0));
      expScores.add(e);
      expSum += e;
    }
    return expScores.map((e) => expSum > 0 ? e / expSum : 0.0).toList();
  }

  void _updateCoordinateTables(
    int width,
    int height,
    int sensorOrientation, {
    double roiCenterU = 0.5,
    double roiCenterV = 0.5,
    double roiScale = 1.0,
  }) {
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final int uprightW = isRotated ? height : width;
    final int uprightH = isRotated ? width : height;

    final int minDim = min(uprightW, uprightH);
    final double cropSpan = (minDim * roiScale.clamp(0.40, 1.0)).clamp(64.0, minDim.toDouble());
    final double halfSpan = cropSpan / 2.0;

    final double centerUprightX =
        (roiCenterU * uprightW).clamp(halfSpan, max(halfSpan, uprightW - halfSpan));
    final double centerUprightY =
        (roiCenterV * uprightH).clamp(halfSpan, max(halfSpan, uprightH - halfSpan));

    const int targetW = 224;
    const int targetH = 224;

    for (int outY = 0; outY < targetH; outY++) {
      final double v = (outY + 0.5) / targetH;
      final int uprightY =
          (centerUprightY + (v - 0.5) * cropSpan).round().clamp(0, uprightH - 1);

      if (sensorOrientation == 90) {
        _srcXTable[outY] = uprightY.clamp(0, width - 1);
      } else if (sensorOrientation == 270) {
        _srcXTable[outY] = ((width - 1) - uprightY).clamp(0, width - 1);
      } else if (sensorOrientation == 180) {
        _srcYTable[outY] = ((height - 1) - uprightY).clamp(0, height - 1);
      } else {
        _srcYTable[outY] = uprightY.clamp(0, height - 1);
      }
    }

    for (int outX = 0; outX < targetW; outX++) {
      final double u = (outX + 0.5) / targetW;
      final int uprightX =
          (centerUprightX + (u - 0.5) * cropSpan).round().clamp(0, uprightW - 1);

      if (sensorOrientation == 90) {
        _srcYTable[outX] = ((height - 1) - uprightX).clamp(0, height - 1);
      } else if (sensorOrientation == 270) {
        _srcYTable[outX] = uprightX.clamp(0, height - 1);
      } else if (sensorOrientation == 180) {
        _srcXTable[outX] = ((width - 1) - uprightX).clamp(0, width - 1);
      } else {
        _srcXTable[outX] = uprightX.clamp(0, width - 1);
      }
    }
  }

  /// Extracts and rotates the localized ROI to an upright [1, 224, 224, 3] Float tensor in [0.0, 255.0]
  List<List<List<List<double>>>> _preprocessCameraImage(
    CameraImage image,
    int targetW,
    int targetH, {
    int sensorOrientation = 90,
    double roiCenterU = 0.5,
    double roiCenterV = 0.5,
    double roiScale = 1.0,
  }) {
    final int width = image.width;
    final int height = image.height;
    final bool isRotated = sensorOrientation == 90 || sensorOrientation == 270;

    _updateCoordinateTables(
      width,
      height,
      sensorOrientation,
      roiCenterU: roiCenterU,
      roiCenterV: roiCenterV,
      roiScale: roiScale,
    );

    // Android YUV420 format
    if (image.format.group == ImageFormatGroup.yuv420 || image.planes.length >= 3) {
      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final Uint8List yBytes = yPlane.bytes;
      final Uint8List uBytes = uPlane.bytes;
      final Uint8List vBytes = vPlane.bytes;

      final int yLength = yBytes.length;
      final int uLength = uBytes.length;
      final int vLength = vBytes.length;

      final int yRowStride = yPlane.bytesPerRow;
      final int uvRowStride = uPlane.bytesPerRow;
      final int uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final int vRowStride = vPlane.bytesPerRow;
      final int vPixelStride = vPlane.bytesPerPixel ?? 1;

      for (int outY = 0; outY < targetH; outY++) {
        final row = _inputTensorBuffer[0][outY];

        for (int outX = 0; outX < targetW; outX++) {
          final int srcX = isRotated ? _srcXTable[outY] : _srcXTable[outX];
          final int srcY = isRotated ? _srcYTable[outX] : _srcYTable[outY];
          final int uvX = srcX >> 1;
          final int uvY = srcY >> 1;

          final int yIndex = srcY * yRowStride + srcX;
          final int uIndex = uvY * uvRowStride + uvX * uvPixelStride;
          final int vIndex = uvY * vRowStride + uvX * vPixelStride;

          final int yVal = (yIndex < yLength) ? yBytes[yIndex] : 0;
          final int uVal = (uIndex >= 0 && uIndex < uLength) ? uBytes[uIndex] - 128 : 0;
          final int vVal = (vIndex >= 0 && vIndex < vLength) ? vBytes[vIndex] - 128 : 0;

          final double r = (yVal + 1.402 * vVal).clamp(0.0, 255.0);
          final double g = (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0.0, 255.0);
          final double b = (yVal + 1.772 * uVal).clamp(0.0, 255.0);

          final pixel = row[outX];
          pixel[0] = r;
          pixel[1] = g;
          pixel[2] = b;
        }
      }
      return _inputTensorBuffer;
    }

    // iOS BGRA8888 or single plane format
    if (image.format.group == ImageFormatGroup.bgra8888 || image.planes.length == 1) {
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;
      final int bytesLength = bytes.length;

      for (int outY = 0; outY < targetH; outY++) {
        final row = _inputTensorBuffer[0][outY];

        for (int outX = 0; outX < targetW; outX++) {
          final int srcX = isRotated ? _srcXTable[outY] : _srcXTable[outX];
          final int srcY = isRotated ? _srcYTable[outX] : _srcYTable[outY];
          final int index = srcY * bytesPerRow + (srcX << 2);
          final pixel = row[outX];

          if (index + 2 < bytesLength) {
            pixel[0] = bytes[index + 2].toDouble();
            pixel[1] = bytes[index + 1].toDouble();
            pixel[2] = bytes[index].toDouble();
          } else {
            pixel[0] = 0.0;
            pixel[1] = 0.0;
            pixel[2] = 0.0;
          }
        }
      }
      return _inputTensorBuffer;
    }

    return _inputTensorBuffer;
  }

  /// Process decoded image bytes (e.g. from snapshot or photo library) with dynamic object localization
  Future<RecognitionResult?> processImageBytes(Uint8List bytes) async {
    final activeInterpreter = _interpreter ?? _cnnInterpreter;
    if (activeInterpreter == null) {
      return processFrame();
    }

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      final Size imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());

      // 1. Dynamically localize the object in the static photo
      _extractGridFromDecodedImage(decoded);
      final BoundingBox localizedBox = _localizeObjectInGrid(useTrackingPrior: false) ??
          const BoundingBox(left: 0.12, top: 0.12, right: 0.88, bottom: 0.88);

      // 2. Crop around the localized object (and compare with center crop)
      final int minDim = min(decoded.width, decoded.height);
      final double roiScale = (max(localizedBox.width, localizedBox.height) * 1.20).clamp(0.45, 1.0);
      final int cropSize = (minDim * roiScale).round().clamp(64, minDim);
      final int halfCrop = cropSize ~/ 2;
      final int centerX =
          (localizedBox.centerX * decoded.width).round().clamp(halfCrop, max(halfCrop, decoded.width - halfCrop));
      final int centerY =
          (localizedBox.centerY * decoded.height).round().clamp(halfCrop, max(halfCrop, decoded.height - halfCrop));

      final cropped = img.copyCrop(
        decoded,
        x: (centerX - halfCrop).clamp(0, max(0, decoded.width - cropSize)),
        y: (centerY - halfCrop).clamp(0, max(0, decoded.height - cropSize)),
        width: cropSize,
        height: cropSize,
      );
      final resized = img.copyResize(cropped, width: 224, height: 224);

      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final p = resized.getPixel(x, y);
              return [
                p.r.toDouble(),
                p.g.toDouble(),
                p.b.toDouble(),
              ];
            },
          ),
        ),
      );

      final numClasses = _labels.isNotEmpty ? _labels.length : 3;
      final output = List.generate(1, (_) => List.filled(numClasses, 0.0));
      activeInterpreter.run(input, output);

      List<double> probabilities = _calculateSoftmax(output[0]);

      // Also check full center crop if ROI crop is smaller than full frame
      if (cropSize < minDim * 0.92) {
        final fullCropped = img.copyCrop(
          decoded,
          x: (decoded.width - minDim) ~/ 2,
          y: (decoded.height - minDim) ~/ 2,
          width: minDim,
          height: minDim,
        );
        final fullResized = img.copyResize(fullCropped, width: 224, height: 224);
        final fullInput = List.generate(
          1,
          (_) => List.generate(
            224,
            (y) => List.generate(
              224,
              (x) {
                final p = fullResized.getPixel(x, y);
                return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
              },
            ),
          ),
        );
        final fullOutput = List.generate(1, (_) => List.filled(numClasses, 0.0));
        activeInterpreter.run(fullInput, fullOutput);
        final fullProbs = _calculateSoftmax(fullOutput[0]);
        if (fullProbs.reduce(max) > probabilities.reduce(max)) {
          probabilities = fullProbs;
        }
      }

      int bestIdx = 0;
      double bestProb = probabilities[0];
      double secondProb = 0.0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > bestProb) {
          secondProb = bestProb;
          bestProb = probabilities[i];
          bestIdx = i;
        } else if (probabilities[i] > secondProb) {
          secondProb = probabilities[i];
        }
      }

      final Map<String, double> probMap = {};
      for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
        probMap[_labels[i]] = probabilities[i];
      }

      final double effectiveThreshold = (_confidenceThreshold - 0.08).clamp(0.55, 0.95);
      final double effectiveMargin = (effectiveThreshold * 0.35).clamp(0.15, 0.45);
      final bool isConfident = bestIdx >= 0 &&
          bestIdx < _labels.length &&
          bestProb >= effectiveThreshold &&
          (bestProb - secondProb) >= effectiveMargin;

      if (isConfident) {
        final detectedKey = _labels[bestIdx];
        final landmark = LandmarkDataService.findByLabel(detectedKey);

        if (landmark != null) {
          return RecognitionResult(
            label: detectedKey,
            yoloConfidence: bestProb,
            cnnConfidence: bestProb,
            boundingBox: localizedBox,
            imageSize: imageSize,
            inferenceTimeMs: 16,
            landmark: landmark,
            allProbabilities: probMap,
          );
        }
      }

      return RecognitionResult(
        label: 'searching',
        yoloConfidence: 0.0,
        cnnConfidence: 0.0,
        boundingBox: null,
        imageSize: imageSize,
        inferenceTimeMs: 16,
        landmark: null,
        allProbabilities: probMap,
      );
    } catch (e) {
      debugPrint('Error processing image bytes: $e');
      return null;
    }
  }

  /// Run dual-stage YOLO + CNN pipeline (simulation / fallback mode)
  Future<RecognitionResult> processFrame({
    String? forcedLandmarkKey,
    double cameraJitter = 0.0,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Only recognize if explicitly forced (e.g. testing)
    if (forcedLandmarkKey != null && forcedLandmarkKey.isNotEmpty) {
      final landmark = LandmarkDataService.findByLabel(forcedLandmarkKey);
      if (landmark != null) {
        final yoloResult = await _runStage1Yolo(forcedLandmarkKey, cameraJitter);
        final cnnResult = await _runStage2Cnn(forcedLandmarkKey, yoloResult);
        stopwatch.stop();
        _lastInferenceTimeMs = max(16, stopwatch.elapsedMilliseconds);

        return RecognitionResult(
          label: forcedLandmarkKey,
          yoloConfidence: yoloResult.confidence,
          cnnConfidence: cnnResult.confidence,
          boundingBox: yoloResult.boundingBox,
          inferenceTimeMs: _lastInferenceTimeMs,
          landmark: landmark,
        );
      }
    }

    stopwatch.stop();
    _lastInferenceTimeMs = max(16, stopwatch.elapsedMilliseconds);

    // Default: searching (no fake popup!)
    return RecognitionResult(
      label: 'searching',
      yoloConfidence: 0.0,
      cnnConfidence: 0.0,
      boundingBox: null,
      inferenceTimeMs: _lastInferenceTimeMs,
      landmark: null,
    );
  }

  /// Stage 1: YOLO detection (Bounding Box & ROI localization)
  Future<_YoloDetection> _runStage1Yolo(String landmarkKey, double jitter) async {
    if (_yoloInterpreter != null) {
      try {
        final input = List.generate(
          1,
          (_) => List.generate(
            640,
            (_) => List.generate(640, (_) => List.filled(3, 0.5)),
          ),
        );
        final output = List.generate(
          1,
          (_) => List.generate(84, (_) => List.filled(8400, 0.0)),
        );
        _yoloInterpreter!.run(input, output);
      } catch (e) {
        debugPrint('TFLite YOLO execution fallback: $e');
      }
    }

    final rng = Random();
    final jX = (rng.nextDouble() - 0.5) * 0.015 + jitter;
    final jY = (rng.nextDouble() - 0.5) * 0.015;

    final left = (0.16 + jX).clamp(0.05, 0.85);
    final top = (0.18 + jY).clamp(0.08, 0.85);
    final right = (0.84 + jX).clamp(left + 0.1, 0.95);
    final bottom = (0.76 + jY).clamp(top + 0.1, 0.92);

    final conf = 0.91 + (rng.nextDouble() * 0.07);

    return _YoloDetection(
      boundingBox: BoundingBox(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      confidence: conf.clamp(0.85, 0.99),
    );
  }

  /// Stage 2: CNN Feature Extraction & Landmark Classification
  Future<_CnnClassification> _runStage2Cnn(
    String landmarkKey,
    _YoloDetection yoloDetection,
  ) async {
    if (_cnnInterpreter != null) {
      try {
        final input = List.generate(
          1,
          (_) => List.generate(
            224,
            (_) => List.generate(224, (_) => List.filled(3, 0.5)),
          ),
        );
        final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));
        _cnnInterpreter!.run(input, output);
      } catch (e) {
        debugPrint('TFLite CNN execution fallback: $e');
      }
    }

    final rng = Random();
    final conf = 0.93 + (rng.nextDouble() * 0.06);

    return _CnnClassification(
      predictedClass: landmarkKey,
      confidence: conf.clamp(0.88, 0.99),
    );
  }

  @override
  void dispose() {
    _isolateInterpreter?.close();
    _interpreter?.close();
    _yoloInterpreter?.close();
    _cnnInterpreter?.close();
    super.dispose();
  }
}

class _YoloDetection {
  final BoundingBox boundingBox;
  final double confidence;

  const _YoloDetection({
    required this.boundingBox,
    required this.confidence,
  });
}

class _CnnClassification {
  final String predictedClass;
  final double confidence;

  const _CnnClassification({
    required this.predictedClass,
    required this.confidence,
  });
}
