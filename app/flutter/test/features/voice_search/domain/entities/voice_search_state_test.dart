import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/voice_search/domain/entities/voice_search_state.dart';

void main() {
  group('VoiceSearchState', () {
    test('should have correct default values', () {
      const state = VoiceSearchState();

      expect(state.status, VoiceSearchStatus.idle);
      expect(state.recognizedText, '');
      expect(state.isFinal, false);
      expect(state.errorMessage, null);
      expect(state.soundLevel, 0.0);
      expect(state.availableLocales, isEmpty);
      expect(state.selectedLocale, 'en_US');
    });

    test('isListening should return true when status is listening', () {
      const state = VoiceSearchState(status: VoiceSearchStatus.listening);
      expect(state.isListening, true);

      const idleState = VoiceSearchState(status: VoiceSearchStatus.idle);
      expect(idleState.isListening, false);
    });

    test('isReady should return true when status is idle', () {
      const state = VoiceSearchState(status: VoiceSearchStatus.idle);
      expect(state.isReady, true);

      const listeningState = VoiceSearchState(
        status: VoiceSearchStatus.listening,
      );
      expect(listeningState.isReady, false);
    });

    test('isAvailable should return false when status is unavailable', () {
      const state = VoiceSearchState(status: VoiceSearchStatus.unavailable);
      expect(state.isAvailable, false);

      const availableState = VoiceSearchState(status: VoiceSearchStatus.idle);
      expect(availableState.isAvailable, true);
    });

    test('hasText should return true when recognizedText is not empty', () {
      const state = VoiceSearchState(recognizedText: 'Hello');
      expect(state.hasText, true);

      const emptyState = VoiceSearchState(recognizedText: '');
      expect(emptyState.hasText, false);
    });

    test('copyWith should return new state with updated values', () {
      const state = VoiceSearchState();

      final updated = state.copyWith(
        status: VoiceSearchStatus.listening,
        recognizedText: 'Hello world',
        soundLevel: 0.5,
      );

      expect(updated.status, VoiceSearchStatus.listening);
      expect(updated.recognizedText, 'Hello world');
      expect(updated.soundLevel, 0.5);
      expect(updated.isFinal, false); // unchanged
    });

    test('copyWith with clearError should set errorMessage to null', () {
      const state = VoiceSearchState(
        status: VoiceSearchStatus.error,
        errorMessage: 'Some error',
      );

      final cleared = state.copyWith(
        status: VoiceSearchStatus.idle,
        clearError: true,
      );

      expect(cleared.status, VoiceSearchStatus.idle);
      expect(cleared.errorMessage, null);
    });

    test('props should include all fields for equality', () {
      const state1 = VoiceSearchState(
        status: VoiceSearchStatus.listening,
        recognizedText: 'Hello',
      );

      const state2 = VoiceSearchState(
        status: VoiceSearchStatus.listening,
        recognizedText: 'Hello',
      );

      const state3 = VoiceSearchState(
        status: VoiceSearchStatus.listening,
        recognizedText: 'World',
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });

  group('VoiceSearchStatus', () {
    test('should have all expected values', () {
      expect(VoiceSearchStatus.values, hasLength(6));
      expect(
        VoiceSearchStatus.values,
        containsAll([
          VoiceSearchStatus.idle,
          VoiceSearchStatus.initializing,
          VoiceSearchStatus.listening,
          VoiceSearchStatus.processing,
          VoiceSearchStatus.unavailable,
          VoiceSearchStatus.error,
        ]),
      );
    });
  });
}
