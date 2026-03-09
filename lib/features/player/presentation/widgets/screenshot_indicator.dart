import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';

import '../../data/player_service.dart';
import '../providers/player_providers.dart';

// ─────────────────────────────────────────────────────────────
//  Screenshot Key (shared between OSD and keyboard handler)
// ─────────────────────────────────────────────────────────────

/// Global key for the [RepaintBoundary] wrapping the video surface
/// in [PlayerOsd]. Used by both the overflow menu and keyboard
/// shortcuts to capture screenshots.
final screenshotBoundaryKey = GlobalKey(debugLabel: 'screenshotBoundary');

// ─────────────────────────────────────────────────────────────
//  Screenshot State + Provider
// ─────────────────────────────────────────────────────────────

/// Screenshot result shown briefly by [ScreenshotIndicator].
enum ScreenshotResult { idle, success, error }

/// Notifier that holds the latest screenshot result.
class ScreenshotResultNotifier extends Notifier<ScreenshotResult> {
  @override
  ScreenshotResult build() => ScreenshotResult.idle;

  /// Sets the result and auto-resets to idle after 1.5 seconds.
  void setResult(ScreenshotResult result) {
    state = result;
    if (result != ScreenshotResult.idle) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (ref.mounted && state == result) state = ScreenshotResult.idle;
      });
    }
  }
}

/// Provider that holds the latest screenshot result.
final screenshotResultProvider =
    NotifierProvider<ScreenshotResultNotifier, ScreenshotResult>(
      ScreenshotResultNotifier.new,
    );

/// Captures the current video frame from [boundaryKey] and saves
/// it as a PNG file. For clean screenshots, temporarily disables
/// subtitles before capture and restores them afterward.
///
/// Returns the saved [File] path, or null on failure.
Future<String?> captureScreenshot({
  required GlobalKey boundaryKey,
  required WidgetRef ref,
  bool clean = false,
}) async {
  if (kIsWeb) return null;

  final service = ref.read(playerServiceProvider);

  // Clean mode: disable subtitles before capture.
  int? originalSubIndex;
  if (clean) {
    originalSubIndex = _currentSubtitleIndex(service);
    await service.setSubtitleTrack(-1);
    // Wait for the renderer to apply the change.
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  try {
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (byteData == null) return null;

    final bytes = byteData.buffer.asUint8List();
    final path = await _screenshotPath();
    if (path == null) return null;

    final file = File(path);
    await file.writeAsBytes(bytes);

    ref
        .read(screenshotResultProvider.notifier)
        .setResult(ScreenshotResult.success);
    return path;
  } catch (_) {
    ref
        .read(screenshotResultProvider.notifier)
        .setResult(ScreenshotResult.error);
    return null;
  } finally {
    // Restore subtitles after clean capture.
    if (clean && originalSubIndex != null && originalSubIndex >= 0) {
      await service.setSubtitleTrack(originalSubIndex);
    }
  }
}

/// Gets the currently active subtitle track index (-1 = none).
int _currentSubtitleIndex(PlayerService service) {
  return service.state.selectedSubtitleTrackId ?? -1;
}

/// Generates a unique file path in the platform's pictures directory.
Future<String?> _screenshotPath() async {
  try {
    Directory dir;
    if (Platform.isAndroid) {
      // Android: save to Pictures/CrispyTivi
      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return null;
      // Navigate up to the root external storage, then into Pictures.
      final root = extDir.path.split('Android').first;
      dir = Directory('${root}Pictures/CrispyTivi');
    } else if (Platform.isIOS || Platform.isMacOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      dir = Directory('${docsDir.path}/Screenshots');
    } else {
      // Windows / Linux: save next to the app.
      final docsDir = await getApplicationDocumentsDirectory();
      dir = Directory('${docsDir.path}/CrispyTivi/Screenshots');
    }

    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return '${dir.path}/screenshot_$timestamp.png';
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
//  Screenshot Indicator Widget
// ─────────────────────────────────────────────────────────────

/// Brief visual indicator shown after a screenshot is captured.
///
/// Shows a white flash (100ms) then a centered checkmark icon
/// that fades out after 1 second. Hidden when [screenshotResultProvider]
/// is [ScreenshotResult.idle].
class ScreenshotIndicator extends ConsumerStatefulWidget {
  const ScreenshotIndicator({super.key});

  @override
  ConsumerState<ScreenshotIndicator> createState() =>
      _ScreenshotIndicatorState();
}

class _ScreenshotIndicatorState extends ConsumerState<ScreenshotIndicator> {
  bool _showFlash = false;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(screenshotResultProvider);

    // Trigger flash on new capture.
    ref.listen<ScreenshotResult>(screenshotResultProvider, (prev, next) {
      if (next == ScreenshotResult.success &&
          prev != ScreenshotResult.success) {
        setState(() => _showFlash = true);
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 120), () {
          if (mounted) setState(() => _showFlash = false);
        });
      }
    });

    if (result == ScreenshotResult.idle) return const SizedBox.shrink();

    return Stack(
      children: [
        // White flash overlay.
        if (_showFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),

        // Result badge.
        Positioned(
          top: 48,
          right: 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: result != ScreenshotResult.idle ? 1.0 : 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result == ScreenshotResult.success
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color:
                        result == ScreenshotResult.success
                            ? Colors.green
                            : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result == ScreenshotResult.success
                        ? context.l10n.playerScreenshotSaved
                        : context.l10n.playerScreenshotFailed,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
