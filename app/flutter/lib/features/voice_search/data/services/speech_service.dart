import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:speech_to_text/speech_recognition_error.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
// import 'package:speech_to_text/speech_to_text.dart';

import 'speech_to_text_mock.dart';

import '../../domain/entities/voice_search_state.dart';

/// Provider for voice search service.
final voiceSearchServiceProvider =
    NotifierProvider<VoiceSearchService, VoiceSearchState>(
      VoiceSearchService.new,
    );

/// Service that manages speech-to-text recognition for voice search.
///
/// Uses the [speech_to_text] package for cross-platform speech recognition.
/// Handles permission requests, audio level monitoring, and result streaming.
class VoiceSearchService extends Notifier<VoiceSearchState> {
  SpeechToText? _speech;
  bool _initialized = false;

  @override
  VoiceSearchState build() {
    // Clean up on dispose.
    ref.onDispose(() {
      _speech?.stop();
      _speech?.cancel();
    });

    return const VoiceSearchState();
  }

  /// Initializes the speech recognition service.
  ///
  /// Returns true if initialization was successful.
  Future<bool> initialize() async {
    if (_initialized) return true;

    state = state.copyWith(status: VoiceSearchStatus.initializing);

    // Check and request microphone permission.
    final permissionGranted = await _requestMicrophonePermission();
    if (!permissionGranted) {
      state = state.copyWith(
        status: VoiceSearchStatus.unavailable,
        errorMessage: 'Microphone permission denied',
      );
      return false;
    }

    // Initialize speech recognition.
    _speech = SpeechToText();

    try {
      final available = await _speech!.initialize(
        onError: _onError,
        onStatus: _onStatus,
        debugLogging: kDebugMode,
      );

      if (!available) {
        state = state.copyWith(
          status: VoiceSearchStatus.unavailable,
          errorMessage: 'Speech recognition not available on this device',
        );
        return false;
      }

      _initialized = true;

      // Load available locales.
      final locales = await _speech!.locales();
      final localeIds = locales.map((l) => l.localeId).toList();

      // Find system locale or default to en_US.
      final systemLocale = await _speech!.systemLocale();
      final defaultLocale = systemLocale?.localeId ?? 'en_US';

      state = state.copyWith(
        status: VoiceSearchStatus.idle,
        availableLocales: localeIds,
        selectedLocale: defaultLocale,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: VoiceSearchStatus.unavailable,
        errorMessage: 'Failed to initialize speech recognition: $e',
      );
      return false;
    }
  }

  /// Requests microphone permission.
  Future<bool> _requestMicrophonePermission() async {
    // Web doesn't use permission_handler.
    if (kIsWeb) return true;

    // Desktop platforms may not need explicit permission.
    if (Platform.isWindows || Platform.isLinux) return true;

    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Starts listening for speech input.
  ///
  /// [onResult] is called when speech is recognized.
  Future<void> startListening({
    void Function(String text, bool isFinal)? onResult,
  }) async {
    if (!_initialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_speech == null || !_speech!.isAvailable) {
      state = state.copyWith(
        status: VoiceSearchStatus.error,
        errorMessage: 'Speech recognition not available',
      );
      return;
    }

    // Clear previous recognition results.
    state = state.copyWith(
      status: VoiceSearchStatus.listening,
      recognizedText: '',
      isFinal: false,
      clearError: true,
    );

    try {
      await _speech!.listen(
        onResult: (result) => _onResult(result, onResult),
        onSoundLevelChange: _onSoundLevelChange,
        localeId: state.selectedLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.search,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: VoiceSearchStatus.error,
        errorMessage: 'Failed to start listening: $e',
      );
    }
  }

  /// Stops listening for speech input.
  Future<void> stopListening() async {
    if (_speech == null) return;

    await _speech!.stop();

    state = state.copyWith(status: VoiceSearchStatus.idle, soundLevel: 0.0);
  }

  /// Cancels the current listening session without processing.
  Future<void> cancelListening() async {
    if (_speech == null) return;

    await _speech!.cancel();

    state = state.copyWith(
      status: VoiceSearchStatus.idle,
      recognizedText: '',
      isFinal: false,
      soundLevel: 0.0,
    );
  }

  /// Sets the locale for speech recognition.
  void setLocale(String localeId) {
    if (state.availableLocales.contains(localeId)) {
      state = state.copyWith(selectedLocale: localeId);
    }
  }

  void _onResult(
    SpeechRecognitionResult result,
    void Function(String, bool)? callback,
  ) {
    state = state.copyWith(
      recognizedText: result.recognizedWords,
      isFinal: result.finalResult,
    );

    callback?.call(result.recognizedWords, result.finalResult);

    if (result.finalResult) {
      state = state.copyWith(status: VoiceSearchStatus.idle, soundLevel: 0.0);
    }
  }

  void _onSoundLevelChange(double level) {
    // Normalize sound level to 0.0-1.0 range.
    // speech_to_text returns dB values, typically -2 to 10.
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    state = state.copyWith(soundLevel: normalized);
  }

  void _onError(SpeechRecognitionError error) {
    // Ignore "no speech" errors - they're expected.
    if (error.errorMsg == 'error_no_match' ||
        error.errorMsg == 'error_speech_timeout') {
      state = state.copyWith(status: VoiceSearchStatus.idle, soundLevel: 0.0);
      return;
    }

    state = state.copyWith(
      status: VoiceSearchStatus.error,
      errorMessage: _mapErrorMessage(error.errorMsg),
      soundLevel: 0.0,
    );
  }

  void _onStatus(String status) {
    // Handle status changes from the speech recognizer.
    if (status == 'done' || status == 'notListening') {
      state = state.copyWith(status: VoiceSearchStatus.idle, soundLevel: 0.0);
    }
  }

  String _mapErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'error_audio':
        return 'Audio recording error';
      case 'error_network':
        return 'Network error - check your connection';
      case 'error_no_match':
        return 'No speech recognized';
      case 'error_permission':
        return 'Microphone permission denied';
      case 'error_speech_timeout':
        return 'No speech detected';
      case 'error_busy':
        return 'Speech recognition busy';
      case 'error_not_available':
        return 'Speech recognition not available';
      default:
        return 'Speech recognition error: $errorCode';
    }
  }

  /// Whether speech recognition is available on this platform.
  bool get isSupported {
    // Supported on Android, iOS, macOS, and Windows.
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;
  }
}
