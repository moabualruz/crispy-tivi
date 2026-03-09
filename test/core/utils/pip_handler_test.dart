import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/utils/platform_capabilities.dart';
import 'package:crispy_tivi/features/player/presentation/providers/pip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipNotifier (unified PiP)', () {
    late ProviderContainer container;
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      // Mock the crispy/pip MethodChannel so PipImpl can initialize.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('crispy/pip'), (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            return null;
          });
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('crispy/pip'), null);
    });

    test('PlatformCapabilities.pip returns true on all platforms', () {
      expect(PlatformCapabilities.pip, isTrue);
    });

    test('initial state is inactive', () {
      final state = container.read(pipProvider);
      expect(state.isActive, isFalse);
      expect(state.slotIndex, isNull);
    });

    test('onNativePipChanged updates state to active', () {
      final notifier = container.read(pipProvider.notifier);

      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);
    });

    test('onNativePipChanged resets state when PiP exits', () {
      final notifier = container.read(pipProvider.notifier);

      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      notifier.onNativePipChanged(isInPip: false);
      expect(container.read(pipProvider).isActive, isFalse);
      expect(container.read(pipProvider).slotIndex, isNull);
    });

    test('exitPip is no-op when not active', () async {
      final notifier = container.read(pipProvider.notifier);
      // Should not throw or change state.
      await notifier.exitPip();
      expect(container.read(pipProvider).isActive, isFalse);
    });

    test('multiple native callbacks are idempotent', () {
      final notifier = container.read(pipProvider.notifier);

      notifier.onNativePipChanged(isInPip: true);
      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      notifier.onNativePipChanged(isInPip: false);
      notifier.onNativePipChanged(isInPip: false);
      expect(container.read(pipProvider).isActive, isFalse);
    });

    test('PipState copyWith preserves fields', () {
      const state = PipState(isActive: true, slotIndex: 2);
      final copy = state.copyWith();
      expect(copy.isActive, isTrue);
      expect(copy.slotIndex, 2);
    });

    test('PipState copyWith overrides fields', () {
      const state = PipState();
      final copy = state.copyWith(isActive: true, slotIndex: 1);
      expect(copy.isActive, isTrue);
      expect(copy.slotIndex, 1);
    });

    test('PipState default constructor has correct defaults', () {
      const state = PipState();
      expect(state.isActive, isFalse);
      expect(state.slotIndex, isNull);
    });
  });
}
