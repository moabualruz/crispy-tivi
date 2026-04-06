/// Re-exports for voice search presentation layer.
///
/// Widgets in [voice_search/presentation/widgets/] must import from this file
/// instead of reaching directly into data/ layers (DIP / ISP compliance).
export '../../data/services/speech_service.dart'
    show VoiceSearchService, voiceSearchServiceProvider;
