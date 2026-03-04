class SpeechToText {
  bool get isAvailable => true;
  Future<bool> initialize({
    required void Function(SpeechRecognitionError) onError,
    required void Function(String) onStatus,
    bool debugLogging = false,
  }) async => true;
  Future<List<SpeechLocale>> locales() async => [
    SpeechLocale('en_US', 'English'),
  ];
  Future<SpeechLocale?> systemLocale() async =>
      SpeechLocale('en_US', 'English');
  Future<void> listen({
    void Function(SpeechRecognitionResult)? onResult,
    void Function(double)? onSoundLevelChange,
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
    dynamic listenOptions,
  }) async {}
  Future<void> stop() async {}
  Future<void> cancel() async {}
}

class SpeechLocale {
  final String localeId;
  final String name;
  SpeechLocale(this.localeId, this.name);
}

class SpeechRecognitionResult {
  final String recognizedWords = '';
  final bool finalResult = true;
}

class SpeechRecognitionError {
  final String errorMsg = '';
}

class SpeechListenOptions {
  SpeechListenOptions({
    dynamic listenMode,
    bool? cancelOnError,
    bool? partialResults,
  });
}

class ListenMode {
  static const search = 1;
}
