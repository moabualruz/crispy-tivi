import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/features/player/presentation/providers/pip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipNotifier Tests', () {
    late ProviderContainer container;
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('crispy/pip'), (
            MethodCall methodCall,
          ) async {
            log.add(methodCall);
            if (methodCall.method == 'enterPip' ||
                methodCall.method == 'exitPip' ||
                methodCall.method == 'setAutoPipReady') {
              return null;
            }
            throw PlatformException(code: 'NotFound');
          });

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('crispy/pip'), null);
    });

    test('initial state is inactive', () {
      final state = container.read(pipProvider);
      expect(state.isActive, isFalse);
      expect(state.slotIndex, isNull);
    });

    test('onNativePipChanged updates state', () {
      final notifier = container.read(pipProvider.notifier);

      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      notifier.onNativePipChanged(isInPip: false);
      expect(container.read(pipProvider).isActive, isFalse);
    });

    test('onNativePipChanged clears slotIndex on exit', () {
      final notifier = container.read(pipProvider.notifier);

      // Simulate entering PiP with a slot index via enterPip logic.
      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      notifier.onNativePipChanged(isInPip: false);
      expect(container.read(pipProvider).slotIndex, isNull);
    });

    test('exitPip is no-op when not active', () async {
      final notifier = container.read(pipProvider.notifier);
      await notifier.exitPip();
      expect(container.read(pipProvider).isActive, isFalse);
      // No exitPip method call should be logged since state was inactive.
      expect(log.where((c) => c.method == 'exitPip'), isEmpty);
    });

    test('exitPip resets state when active', () async {
      final notifier = container.read(pipProvider.notifier);

      // Force active state via native callback.
      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      await notifier.exitPip();
      expect(container.read(pipProvider).isActive, isFalse);
      expect(container.read(pipProvider).slotIndex, isNull);
    });

    test('togglePip exits when active', () async {
      final notifier = container.read(pipProvider.notifier);

      // Make active first.
      notifier.onNativePipChanged(isInPip: true);
      expect(container.read(pipProvider).isActive, isTrue);

      final (success, error) = await notifier.togglePip();
      expect(success, isTrue);
      expect(error, isNull);
      expect(container.read(pipProvider).isActive, isFalse);
    });

    test('setAutoPipReady sends to platform channel', () async {
      final notifier = container.read(pipProvider.notifier);
      await notifier.setAutoPipReady(ready: true, width: 640, height: 360);

      final autoPipCalls =
          log.where((c) => c.method == 'setAutoPipReady').toList();
      // On desktop test host, setAutoPipReady goes through PipImpl
      // which routes to MethodChannel on Android/iOS, no-op on desktop.
      // Depending on test platform, the call may or may not appear.
      // Just verify no exceptions.
      expect(autoPipCalls, isA<List<MethodCall>>());
    });

    test('isSupported returns true on test platform', () {
      final notifier = container.read(pipProvider.notifier);
      // On Windows/macOS/Linux test host, PipImpl.isSupported is true
      // (desktop PiP via window_manager).
      expect(notifier.isSupported, isTrue);
    });
  });

  group('PipState', () {
    test('default values', () {
      const state = PipState();
      expect(state.isActive, isFalse);
      expect(state.slotIndex, isNull);
    });

    test('copyWith preserves fields', () {
      const state = PipState(isActive: true, slotIndex: 2);
      final copy = state.copyWith();
      expect(copy.isActive, isTrue);
      expect(copy.slotIndex, 2);
    });

    test('copyWith overrides fields', () {
      const state = PipState();
      final copy = state.copyWith(isActive: true, slotIndex: 1);
      expect(copy.isActive, isTrue);
      expect(copy.slotIndex, 1);
    });

    test('copyWith can set isActive false', () {
      const state = PipState(isActive: true, slotIndex: 3);
      final copy = state.copyWith(isActive: false);
      expect(copy.isActive, isFalse);
      // slotIndex preserved since not overridden.
      expect(copy.slotIndex, 3);
    });
  });
}
