import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/data/cache_service.dart';
import 'package:crispy_tivi/core/data/crispy_backend.dart';
import 'package:crispy_tivi/core/data/memory_backend.dart';
import 'package:crispy_tivi/features/player/data/'
    'upscale_manager.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'gpu_info.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_mode.dart';
import 'package:crispy_tivi/features/player/domain/entities/'
    'upscale_quality.dart';
import 'package:crispy_tivi/features/player/presentation/'
    'providers/upscale_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────

class MockCrispyBackend extends Mock implements CrispyBackend {}

// ── Tests ──────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════
  //  upscaleManagerProvider
  // ════════════════════════════════════════════════

  group('upscaleManagerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns UpscaleManager instance', () {
      final manager = container.read(upscaleManagerProvider);
      expect(manager, isA<UpscaleManager>());
    });

    test('returns same instance on repeated reads', () {
      final a = container.read(upscaleManagerProvider);
      final b = container.read(upscaleManagerProvider);
      expect(identical(a, b), isTrue);
    });
  });

  // ════════════════════════════════════════════════
  //  upscaleActiveNotifier
  // ════════════════════════════════════════════════

  group('UpscaleActiveNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is null', () {
      final state = container.read(upscaleActiveProvider);
      expect(state, isNull);
    });

    test('set(3) updates state to 3', () {
      container.read(upscaleActiveProvider.notifier).set(3);
      expect(container.read(upscaleActiveProvider), equals(3));
    });

    test('set(4) updates state to 4', () {
      container.read(upscaleActiveProvider.notifier).set(4);
      expect(container.read(upscaleActiveProvider), equals(4));
    });

    test('set(null) resets to null', () {
      container.read(upscaleActiveProvider.notifier).set(3);
      expect(container.read(upscaleActiveProvider), equals(3));

      container.read(upscaleActiveProvider.notifier).set(null);
      expect(container.read(upscaleActiveProvider), isNull);
    });

    test('multiple set calls update correctly', () {
      final notifier = container.read(upscaleActiveProvider.notifier);

      notifier.set(1);
      expect(container.read(upscaleActiveProvider), equals(1));

      notifier.set(4);
      expect(container.read(upscaleActiveProvider), equals(4));

      notifier.set(null);
      expect(container.read(upscaleActiveProvider), isNull);
    });
  });

  // ════════════════════════════════════════════════
  //  upscaleModeProvider
  // ════════════════════════════════════════════════

  group('upscaleModeProvider', () {
    test('defaults to UpscaleMode.off when settings '
        'not loaded (upscaleEnabled defaults false)', () {
      // Override settingsNotifierProvider to return
      // an AsyncLoading state (no value yet).
      // upscaleEnabled defaults to false, so mode
      // should be off regardless of saved mode.
      final container = ProviderContainer(
        overrides: [
          settingsNotifierProvider.overrideWith(
            () => _NeverLoadSettingsNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final mode = container.read(upscaleModeProvider);
      expect(mode, equals(UpscaleMode.off));
    });
  });

  // ════════════════════════════════════════════════
  //  upscaleQualityProvider
  // ════════════════════════════════════════════════

  group('upscaleQualityProvider', () {
    test('defaults to UpscaleQuality.balanced when '
        'settings not loaded', () {
      final container = ProviderContainer(
        overrides: [
          settingsNotifierProvider.overrideWith(
            () => _NeverLoadSettingsNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final quality = container.read(upscaleQualityProvider);
      expect(quality, equals(UpscaleQuality.balanced));
    });
  });

  // ════════════════════════════════════════════════
  //  gpuInfoProvider
  // ════════════════════════════════════════════════

  group('gpuInfoProvider', () {
    test('returns GpuInfo with vendor Unknown from '
        'MemoryBackend', () async {
      final backend = MemoryBackend();
      final container = ProviderContainer(
        overrides: [crispyBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final gpu = await container.read(gpuInfoProvider.future);

      expect(gpu.vendor, equals(GpuVendor.unknown));
      expect(gpu.name, equals('Test GPU'));
      expect(gpu.supportsHwVsr, isFalse);
      expect(gpu.vsrMethod, equals(VsrMethod.none));
      expect(gpu.vramMb, isNull);
    });

    test('returns GpuInfo.unknown on error', () async {
      final mockBackend = MockCrispyBackend();
      when(
        () => mockBackend.detectGpu(),
      ).thenThrow(Exception('GPU detection unavailable'));

      final container = ProviderContainer(
        overrides: [crispyBackendProvider.overrideWithValue(mockBackend)],
      );
      addTearDown(container.dispose);

      final gpu = await container.read(gpuInfoProvider.future);

      expect(gpu.vendor, equals(GpuVendor.unknown));
      expect(gpu.name, equals('Unknown'));
      expect(gpu.supportsHwVsr, isFalse);
      expect(gpu.vsrMethod, equals(VsrMethod.none));
    });
  });
}

// ── Test Helpers ──────────────────────────────────

/// A [SettingsNotifier] that never finishes loading,
/// simulating the "settings not yet loaded" state
/// where providers should fall back to defaults.
class _NeverLoadSettingsNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() {
    // Return a future that never completes, keeping
    // the provider in AsyncLoading with null value.
    return Future<SettingsState>.delayed(const Duration(days: 365));
  }
}
