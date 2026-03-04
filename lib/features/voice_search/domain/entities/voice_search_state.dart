import 'package:equatable/equatable.dart';

/// Possible states for voice search.
enum VoiceSearchStatus {
  /// Ready to start listening.
  idle,

  /// Initializing speech recognition.
  initializing,

  /// Actively listening for speech.
  listening,

  /// Processing the recognized speech.
  processing,

  /// Speech recognition is not available.
  unavailable,

  /// An error occurred during recognition.
  error,
}

/// Immutable state for voice search service.
class VoiceSearchState extends Equatable {
  /// Current status of voice recognition.
  final VoiceSearchStatus status;

  /// Recognized text from speech (partial or final).
  final String recognizedText;

  /// Whether the result is final or still being processed.
  final bool isFinal;

  /// Error message if status is [VoiceSearchStatus.error].
  final String? errorMessage;

  /// Current sound level (0.0 to 1.0) for visual feedback.
  final double soundLevel;

  /// Available locales for speech recognition.
  final List<String> availableLocales;

  /// Currently selected locale for recognition.
  final String selectedLocale;

  const VoiceSearchState({
    this.status = VoiceSearchStatus.idle,
    this.recognizedText = '',
    this.isFinal = false,
    this.errorMessage,
    this.soundLevel = 0.0,
    this.availableLocales = const [],
    this.selectedLocale = 'en_US',
  });

  /// Whether speech recognition is currently active.
  bool get isListening => status == VoiceSearchStatus.listening;

  /// Whether the service is ready to start listening.
  bool get isReady => status == VoiceSearchStatus.idle;

  /// Whether speech recognition is available on this device.
  bool get isAvailable => status != VoiceSearchStatus.unavailable;

  /// Whether there's recognized text available.
  bool get hasText => recognizedText.isNotEmpty;

  VoiceSearchState copyWith({
    VoiceSearchStatus? status,
    String? recognizedText,
    bool? isFinal,
    String? errorMessage,
    bool clearError = false,
    double? soundLevel,
    List<String>? availableLocales,
    String? selectedLocale,
  }) {
    return VoiceSearchState(
      status: status ?? this.status,
      recognizedText: recognizedText ?? this.recognizedText,
      isFinal: isFinal ?? this.isFinal,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      soundLevel: soundLevel ?? this.soundLevel,
      availableLocales: availableLocales ?? this.availableLocales,
      selectedLocale: selectedLocale ?? this.selectedLocale,
    );
  }

  @override
  List<Object?> get props => [
    status,
    recognizedText,
    isFinal,
    errorMessage,
    soundLevel,
    availableLocales,
    selectedLocale,
  ];
}
