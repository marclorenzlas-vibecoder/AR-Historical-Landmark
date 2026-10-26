import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

enum CameraFeedMode {
  liveCamera,
  simulatedView,
}

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isFlashOn = false;
  bool _isStreaming = false;
  CameraFeedMode _feedMode = CameraFeedMode.simulatedView;
  String _errorMessage = '';

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isFlashOn => _isFlashOn;
  bool get isStreaming => _isStreaming;
  CameraFeedMode get feedMode => _feedMode;
  String get errorMessage => _errorMessage;
  bool get isLiveCamera => _feedMode == CameraFeedMode.liveCamera && _isInitialized;

  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Prefer rear camera for AR scanning
        final backCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        _selectedCameraIndex = backCameraIndex != -1 ? backCameraIndex : 0;
        await _initController(_cameras[_selectedCameraIndex]);
        _feedMode = CameraFeedMode.liveCamera;
      } else {
        _feedMode = CameraFeedMode.simulatedView;
      }
    } catch (e) {
      debugPrint('Live camera not available, falling back to simulated viewport: $e');
      _errorMessage = e.toString();
      _feedMode = CameraFeedMode.simulatedView;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initController(CameraDescription description) async {
    if (_isStreaming) {
      await stopImageStream();
    }
    await _controller?.dispose();

    final imageFormat = defaultTargetPlatform == TargetPlatform.android
        ? ImageFormatGroup.yuv420
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg);

    _controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: imageFormat,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      debugPrint('Camera controller init error: $e');
      _feedMode = CameraFeedMode.simulatedView;
    }
  }

  Future<void> startImageStream(Function(CameraImage image) onImage) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return;
    try {
      _isStreaming = true;
      await _controller!.startImageStream(onImage);
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting camera image stream: $e');
      _isStreaming = false;
    }
  }

  Future<void> stopImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (!_isStreaming) return;
    try {
      _isStreaming = false;
      await _controller!.stopImageStream();
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping camera image stream: $e');
    }
  }

  Future<Uint8List?> captureFrameBytes() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    try {
      final file = await _controller!.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error capturing frame snapshot: $e');
      return null;
    }
  }

  Future<void> toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;
    if (_isStreaming) {
      await stopImageStream();
    }
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIndex]);
    notifyListeners();
  }

  void setFeedMode(CameraFeedMode mode) {
    _feedMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isStreaming) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }
}
