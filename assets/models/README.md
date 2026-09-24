# TFLite Models Directory

Place your exported TensorFlow Lite models here:

1. `landmark_yolo.tflite`
   - **Type**: Object Detection / Bounding Box (YOLOv8 or YOLOv5 format)
   - **Input**: `[1, 640, 640, 3]` or `[1, 3, 640, 640]` normalized float32
   - **Output**: Bounding boxes `[x, y, w, h]` and landmark class probabilities.

2. `landmark_cnn.tflite`
   - **Type**: Fine-grained Historical Landmark Classifier (MobileNetV3 / EfficientNet / ResNet)
   - **Input**: `[1, 224, 224, 3]` float32 normalized [-1, 1] or [0, 1]
   - **Output**: Class confidence logits matching `assets/labels/landmarks.txt`.

> **Note**: When `.tflite` files are present, `ml_service.dart` loads them into the TensorFlow Lite interpreter. When running before the models are trained or on platforms without native TFLite binaries, the built-in simulator engine provides realistic live landmark detections for development and demonstration.
