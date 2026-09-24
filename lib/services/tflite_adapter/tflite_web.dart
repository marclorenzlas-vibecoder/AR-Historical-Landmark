class InterpreterOptions {
  int threads = 1;
}

class Interpreter {
  static Future<Interpreter> fromAsset(
    String assetName, {
    InterpreterOptions? options,
  }) async {
    throw UnsupportedError(
      'TFLite native FFI interpreter is only supported on native mobile and desktop platforms.',
    );
  }

  void run(Object input, Object output) {}
  void close() {}
}
