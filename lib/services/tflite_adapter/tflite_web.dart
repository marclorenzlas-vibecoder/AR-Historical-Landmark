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

  int get address => 0;
  void run(Object input, Object output) {}
  void close() {}
}

class IsolateInterpreter {
  static Future<IsolateInterpreter> create({
    required int address,
    String debugName = 'TfLiteInterpreterIsolate',
  }) async {
    return IsolateInterpreter();
  }

  Future<void> run(Object input, Object output) async {}
  void close() {}
}
