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
                methodCall.method == 'exitPip') {
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
  });
}
