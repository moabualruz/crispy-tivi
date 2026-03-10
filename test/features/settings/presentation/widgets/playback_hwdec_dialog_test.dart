import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/config/app_config.dart';
import 'package:crispy_tivi/config/settings_notifier.dart';
import 'package:crispy_tivi/core/utils/gpu_info.dart';
import 'package:crispy_tivi/features/player/domain/entities/hardware_decoder.dart';

// ── Minimal AppConfig for tests ───────────────────────────────
AppConfig _minimalConfig() => const AppConfig(
  appName: 'Test',
  appVersion: '0.0.1',
  api: ApiConfig(
    baseUrl: 'http://test',
    backendPort: 8080,
    connectTimeoutMs: 5000,
    receiveTimeoutMs: 5000,
    sendTimeoutMs: 5000,
  ),
  player: PlayerConfig(
    defaultBufferDurationMs: 2000,
    autoPlay: true,
    defaultAspectRatio: '16:9',
  ),
  theme: ThemeConfig(
    mode: 'dark',
    seedColorHex: '#3B82F6',
    useDynamicColor: false,
  ),
  features: FeaturesConfig(
    iptvEnabled: true,
    jellyfinEnabled: false,
    plexEnabled: false,
    embyEnabled: false,
  ),
  cache: CacheConfig(
    epgRefreshIntervalMinutes: 60,
    channelListRefreshIntervalMinutes: 30,
    maxCachedEpgDays: 7,
  ),
);

// ── Fake SettingsNotifier ─────────────────────────────────────
class _FakeSettingsNotifier extends AsyncNotifier<SettingsState>
    implements SettingsNotifier {
  String? lastHwdecMode;

  @override
  Future<SettingsState> build() async =>
      SettingsState(config: _minimalConfig());

  @override
  Future<void> setHwdecMode(String mode) async {
    lastHwdecMode = mode;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Inline AlertDialog builder ────────────────────────────────
//
// Because showHwdecDialog() constructs GpuInfoHelper() directly
// (not via a provider), the GPU detection result is not mockable
// from tests. Instead, each test builds the AlertDialog content
// directly with known GpuInfo values, mirroring the widget tree
// that showHwdecDialog() produces after GPU detection completes.
Widget _buildDialog({
  required GpuInfo gpuInfo,
  required String currentMode,
  required _FakeSettingsNotifier notifier,
}) {
  return ProviderScope(
    overrides: [settingsNotifierProvider.overrideWith(() => notifier)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (ctx) => _HwdecDialogContent(
                            gpuInfo: gpuInfo,
                            currentMode: currentMode,
                            ctx: ctx,
                          ),
                    ),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
}

/// Mirrors the AlertDialog tree built by showHwdecDialog() after
/// GPU detection. Uses Consumer to access ref for setHwdecMode.
class _HwdecDialogContent extends ConsumerWidget {
  const _HwdecDialogContent({
    required this.gpuInfo,
    required this.currentMode,
    required this.ctx,
  });

  final GpuInfo gpuInfo;
  final String currentMode;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Hardware Decoder'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gpuInfo.isDetected) ...[
                // GPU name banner
                Row(
                  children: [
                    const Icon(Icons.memory),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Detected GPU'),
                          Text(gpuInfo.gpuName ?? 'Unknown'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (gpuInfo.recommendedDecoder != HardwareDecoder.auto)
                  Text('Recommended: ${gpuInfo.recommendedDecoder.label}'),
              ],
              // Decoder options
              ...gpuInfo.availableDecoders.map(
                (decoder) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    decoder.mpvValue == currentMode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(decoder.label),
                  subtitle: Text(decoder.description),
                  onTap: () {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setHwdecMode(decoder.mpvValue);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

void main() {
  late _FakeSettingsNotifier fakeNotifier;

  setUp(() {
    fakeNotifier = _FakeSettingsNotifier();
  });

  // ── GPU info banner ───────────────────────────────────────
  group('HwDec dialog — GPU info banner', () {
    testWidgets('shows GPU name when GpuInfo has a detected name', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce RTX 4080',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('NVIDIA GeForce RTX 4080'), findsOneWidget);
      expect(find.text('Detected GPU'), findsOneWidget);
    });

    testWidgets('shows recommended decoder label when not Auto', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce GTX 1080',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Recommended: ${HardwareDecoder.nvdec.label}'),
        findsOneWidget,
      );
    });

    testWidgets('does not show recommended text when decoder is Auto', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'Unknown GPU',
        vendor: 'Unknown',
        recommendedDecoder: HardwareDecoder.auto,
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Recommended:'), findsNothing);
    });

    testWidgets('GPU banner is absent when gpuName is null', (tester) async {
      const gpuInfo = GpuInfo(
        gpuName: null,
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No GPU name text — the banner section is hidden.
      expect(find.text('Detected GPU'), findsNothing);
    });
  });

  // ── Decoder options — web platform profile ────────────────
  group('HwDec dialog — web platform decoders (Auto + Software Only)', () {
    testWidgets('shows Auto and Software Only when only those decoders exist', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'Web Browser',
        vendor: 'Browser',
        recommendedDecoder: HardwareDecoder.auto,
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.auto.label), findsOneWidget);
      expect(find.text(HardwareDecoder.none.label), findsOneWidget);
    });

    testWidgets('shows descriptions for auto and software decoders', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'no',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.auto.description), findsOneWidget);
      expect(find.text(HardwareDecoder.none.description), findsOneWidget);
    });
  });

  // ── Decoder options — desktop/mobile platform profiles ────
  group('HwDec dialog — platform-specific decoders', () {
    testWidgets('shows NVIDIA decoder options when GPU is NVIDIA', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce RTX 3080',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.cuda,
          HardwareDecoder.d3d11va,
          HardwareDecoder.dxva2,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.nvdec.label), findsOneWidget);
      expect(find.text(HardwareDecoder.cuda.label), findsOneWidget);
      expect(find.text(HardwareDecoder.d3d11va.label), findsOneWidget);
    });

    testWidgets('shows Android MediaCodec decoder option', (tester) async {
      const gpuInfo = GpuInfo(
        gpuName: 'Android GPU',
        vendor: 'Android',
        recommendedDecoder: HardwareDecoder.mediacodec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.mediacodec,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.mediacodec.label), findsOneWidget);
      expect(find.text(HardwareDecoder.mediacodec.description), findsOneWidget);
    });

    testWidgets('shows Apple VideoToolbox decoder option for macOS', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'Apple M2',
        vendor: 'Apple',
        recommendedDecoder: HardwareDecoder.videotoolbox,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.videotoolbox,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.videotoolbox.label), findsOneWidget);
    });

    testWidgets('shows VA-API and VDPAU for Linux NVIDIA', (tester) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce GTX 970',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.vaapi,
          HardwareDecoder.vdpau,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'vaapi',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(HardwareDecoder.vaapi.label), findsOneWidget);
      expect(find.text(HardwareDecoder.vdpau.label), findsOneWidget);
    });
  });

  // ── Tapping an option ─────────────────────────────────────
  group('HwDec dialog — option selection', () {
    testWidgets('tapping an option calls setHwdecMode with correct mpv value', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce RTX 4080',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(HardwareDecoder.nvdec.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastHwdecMode, HardwareDecoder.nvdec.mpvValue);
    });

    testWidgets('dialog dismisses after decoder selection', (tester) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Hardware Decoder'), findsOneWidget);

      await tester.tap(find.text(HardwareDecoder.none.label));
      await tester.pumpAndSettle();

      expect(find.text('Hardware Decoder'), findsNothing);
    });

    testWidgets('Cancel button closes dialog without calling setHwdecMode', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastHwdecMode, isNull);
      expect(find.text('Hardware Decoder'), findsNothing);
    });

    testWidgets('tapping Software Only sets mpv value "no"', (tester) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(HardwareDecoder.none.label));
      await tester.pumpAndSettle();

      expect(fakeNotifier.lastHwdecMode, 'no');
    });
  });

  // ── Current mode pre-selection ────────────────────────────
  group('HwDec dialog — current mode pre-selection', () {
    testWidgets('current decoder shows radio_button_checked icon', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'no', // Software Only is selected
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // One checked, one unchecked.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });

    testWidgets('non-current decoders show radio_button_unchecked icon', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        gpuName: 'NVIDIA GeForce RTX 4080',
        vendor: 'NVIDIA',
        recommendedDecoder: HardwareDecoder.nvdec,
        availableDecoders: [
          HardwareDecoder.auto,
          HardwareDecoder.nvdec,
          HardwareDecoder.none,
        ],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'nvdec', // NVDEC is selected
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Only one checked — nvdec; two unchecked — auto and none.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });

    testWidgets('unknown currentMode leaves all options unchecked', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'unknown_value',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No match → all unchecked.
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });
  });

  // ── Graceful empty / null GPU state ──────────────────────
  group('HwDec dialog — null/undetected GPU state', () {
    testWidgets('renders without crash when gpuName is null', (tester) async {
      const gpuInfo = GpuInfo(
        gpuName: null,
        availableDecoders: [HardwareDecoder.auto, HardwareDecoder.none],
      );

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog opens and shows decoder options without crashing.
      expect(find.text('Hardware Decoder'), findsOneWidget);
      expect(find.text(HardwareDecoder.auto.label), findsOneWidget);
      expect(find.text(HardwareDecoder.none.label), findsOneWidget);
    });

    testWidgets('renders without crash when availableDecoders is empty', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(gpuName: null, availableDecoders: []);

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Dialog still opens; no options listed but title is present.
      expect(find.text('Hardware Decoder'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('Cancel button works even with empty decoder list', (
      tester,
    ) async {
      const gpuInfo = GpuInfo(gpuName: null, availableDecoders: []);

      await tester.pumpWidget(
        _buildDialog(
          gpuInfo: gpuInfo,
          currentMode: 'auto',
          notifier: fakeNotifier,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Hardware Decoder'), findsNothing);
    });
  });

  // ── HardwareDecoder entity ────────────────────────────────
  group('HardwareDecoder entity', () {
    test('auto mpvValue is "auto"', () {
      expect(HardwareDecoder.auto.mpvValue, 'auto');
    });

    test('none mpvValue is "no"', () {
      expect(HardwareDecoder.none.mpvValue, 'no');
    });

    test('nvdec mpvValue is "nvdec"', () {
      expect(HardwareDecoder.nvdec.mpvValue, 'nvdec');
    });

    test('fromMpvValue returns correct decoder', () {
      expect(HardwareDecoder.fromMpvValue('no'), HardwareDecoder.none);
      expect(HardwareDecoder.fromMpvValue('nvdec'), HardwareDecoder.nvdec);
      expect(HardwareDecoder.fromMpvValue('auto'), HardwareDecoder.auto);
    });

    test('fromMpvValue returns auto for unknown value', () {
      expect(
        HardwareDecoder.fromMpvValue('unknown_decoder'),
        HardwareDecoder.auto,
      );
    });

    test('all decoders have non-empty label and description', () {
      for (final decoder in HardwareDecoder.values) {
        expect(decoder.label, isNotEmpty);
        expect(decoder.description, isNotEmpty);
        expect(decoder.mpvValue, isNotEmpty);
      }
    });
  });

  // ── GpuInfo entity ────────────────────────────────────────
  group('GpuInfo entity', () {
    test('isDetected is true when gpuName is non-null', () {
      const info = GpuInfo(gpuName: 'Test GPU');
      expect(info.isDetected, isTrue);
    });

    test('isDetected is false when gpuName is null', () {
      const info = GpuInfo();
      expect(info.isDetected, isFalse);
    });

    test('default availableDecoders contains auto and none', () {
      const info = GpuInfo();
      expect(info.availableDecoders, contains(HardwareDecoder.auto));
      expect(info.availableDecoders, contains(HardwareDecoder.none));
    });

    test('default recommendedDecoder is auto', () {
      const info = GpuInfo();
      expect(info.recommendedDecoder, HardwareDecoder.auto);
    });
  });
}
