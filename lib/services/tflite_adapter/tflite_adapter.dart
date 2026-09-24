export 'tflite_io.dart'
    if (dart.library.html) 'tflite_web.dart'
    if (dart.library.js_interop) 'tflite_web.dart';
