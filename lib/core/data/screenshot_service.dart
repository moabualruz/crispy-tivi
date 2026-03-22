import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_io/io.dart';

import '../../features/player/domain/crispy_player.dart';
import 'app_directories.dart';

/// Manages per-content screenshot lifecycle.
///
/// Screenshots are captured from the player's last frame
/// on exit and stored in the app cache directory. They
/// serve as fallback poster images when the server does
/// not provide one.
///
/// ## Naming convention
/// `screenshot_{contentType}_{contentId}.jpg`
///
/// ## Lifecycle rules
/// - **Continue watching**: last frame overwrites previous;
///   deleted when finished watching.
/// - **Episodes missing poster**: captured once, kept until
///   server provides a real poster.
/// - **Channels**: last frame from last viewing session,
///   overwritten each time.
/// - **Movies missing poster**: captured once, kept until
///   server provides a poster.
class ScreenshotService {
  ScreenshotService();

  /// Directory where screenshots are stored.
  ///
  /// Lazily resolved from [AppDirectories.cache].
  String get _screenshotDir => '${AppDirectories.cache}/screenshots';

  /// Capture the current frame from [player] and save it
  /// as a JPEG file for the given content item.
  ///
  /// Returns the saved file path, or `null` if capture
  /// fails or the platform is web.
  Future<String?> captureLastFrame({
    required CrispyPlayer player,
    required String contentType,
    required String contentId,
  }) async {
    if (kIsWeb) return null;

    final Uint8List? bytes = await player.screenshotRawBytes();
    if (bytes == null || bytes.isEmpty) return null;

    try {
      final dir = Directory(_screenshotDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final path = _filePath(contentType, contentId);
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      debugPrint(
        'ScreenshotService: saved $contentType/$contentId '
        '(${bytes.length} bytes)',
      );
      return path;
    } catch (e) {
      debugPrint('ScreenshotService: save failed: $e');
      return null;
    }
  }

  /// Get the screenshot file path for a content item.
  ///
  /// Returns `null` if no screenshot exists on disk.
  String? getScreenshotPath(String contentType, String contentId) {
    if (kIsWeb) return null;
    final path = _filePath(contentType, contentId);
    return File(path).existsSync() ? path : null;
  }

  /// Delete the screenshot for a content item.
  ///
  /// No-op if the file does not exist.
  Future<void> deleteScreenshot(String contentType, String contentId) async {
    if (kIsWeb) return;
    final file = File(_filePath(contentType, contentId));
    if (file.existsSync()) {
      await file.delete();
      debugPrint('ScreenshotService: deleted $contentType/$contentId');
    }
  }

  /// Delete all cached screenshots.
  Future<void> clearAll() async {
    if (kIsWeb) return;
    final dir = Directory(_screenshotDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
      debugPrint('ScreenshotService: cleared all screenshots');
    }
  }

  /// If [serverPosterUrl] is a non-empty URL, delete our
  /// locally cached screenshot since the server now provides
  /// a real poster.
  Future<void> cleanupIfServerPosterExists(
    String contentType,
    String contentId,
    String? serverPosterUrl,
  ) async {
    if (serverPosterUrl == null || serverPosterUrl.isEmpty) return;
    await deleteScreenshot(contentType, contentId);
  }

  /// Canonical file path for a content screenshot.
  String _filePath(String contentType, String contentId) {
    // Sanitize IDs to prevent path traversal.
    final safeType = contentType.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeId = contentId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$_screenshotDir/screenshot_${safeType}_$safeId.jpg';
  }
}

/// Global [ScreenshotService] provider.
final screenshotServiceProvider = Provider<ScreenshotService>((ref) {
  return ScreenshotService();
});
