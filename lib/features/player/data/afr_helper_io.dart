import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'afr_windows_helper.dart';

/// Platform-specific AFR helper for display mode switching.
///
/// Supports:
/// - Android: Uses [flutter_displaymode] package.
/// - Linux: Uses `xrandr` command-line tool.
/// - Windows: Uses win32 ChangeDisplaySettings API.
/// - macOS/iOS: Not supported (OS doesn't allow app-controlled refresh).
class AfrHelper {
  DisplayMode? _originalAndroidMode;
  String? _originalLinuxMode;
  String? _linuxDisplay;
  final _windowsHelper = WindowsAfrHelper();

  /// Switches display to the best matching refresh rate for the given FPS.
  Future<void> switchToBestMode(double fps) async {
    if (Platform.isAndroid) {
      await _switchAndroid(fps);
    } else if (Platform.isLinux) {
      await _switchLinux(fps);
    } else if (Platform.isWindows) {
      await _windowsHelper.switchMode(fps);
    } else if (Platform.isMacOS || Platform.isIOS) {
      debugPrint(
        'AFR: ${Platform.operatingSystem} does not support '
        'app-controlled display refresh rates.',
      );
    }
  }

  /// Restores the original display mode.
  Future<void> restoreMode() async {
    if (Platform.isAndroid) {
      await _restoreAndroid();
    } else if (Platform.isLinux) {
      await _restoreLinux();
    } else if (Platform.isWindows) {
      await _windowsHelper.restoreMode();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Android Implementation (flutter_displaymode)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _switchAndroid(double fps) async {
    try {
      _originalAndroidMode ??= await FlutterDisplayMode.active;

      final modes = await FlutterDisplayMode.supported;

      DisplayMode? bestMode;
      for (final mode in modes) {
        final refreshRate = mode.refreshRate;
        // Match within 1.0 Hz tolerance
        if ((refreshRate - fps).abs() < 1.0) {
          bestMode = mode;
          break;
        }
        // Also accept integer multiples (e.g., 48Hz for 24fps)
        if ((refreshRate - fps * 2).abs() < 1.0) {
          bestMode = mode;
          break;
        }
      }

      if (bestMode != null && bestMode != await FlutterDisplayMode.active) {
        await FlutterDisplayMode.setPreferredMode(bestMode);
        debugPrint(
          'AFR: Android switched to ${bestMode.refreshRate}Hz '
          'for ${fps}fps content.',
        );
      }
    } catch (e) {
      debugPrint('AFR: Android error: $e');
    }
  }

  Future<void> _restoreAndroid() async {
    if (_originalAndroidMode != null) {
      try {
        await FlutterDisplayMode.setPreferredMode(_originalAndroidMode!);
        debugPrint('AFR: Android restored to original mode.');
        _originalAndroidMode = null;
      } catch (e) {
        debugPrint('AFR: Android restore error: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Linux Implementation (xrandr)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _switchLinux(double fps) async {
    try {
      // Get current display info
      final result = await Process.run('xrandr', ['--current']);
      if (result.exitCode != 0) {
        debugPrint('AFR: xrandr not available');
        return;
      }

      final output = result.stdout as String;
      final lines = output.split('\n');

      // Parse connected display and modes
      String? display;
      String? currentMode;
      final modes = <_LinuxMode>[];

      for (final line in lines) {
        // Find connected display (e.g., "HDMI-1 connected primary 1920x1080+0+0")
        if (line.contains(' connected')) {
          display = line.split(' ').first;
          _linuxDisplay = display;
        }

        // Parse mode lines (e.g., "   1920x1080     60.00*+  50.00    59.94")
        if (display != null && line.startsWith('   ')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isEmpty) continue;

          final resolution = parts[0];
          for (var i = 1; i < parts.length; i++) {
            var rateStr = parts[i].replaceAll('*', '').replaceAll('+', '');
            final rate = double.tryParse(rateStr);
            if (rate != null) {
              final isCurrent = parts[i].contains('*');
              modes.add(_LinuxMode(resolution, rate));
              if (isCurrent) {
                currentMode = '$resolution@$rate';
              }
            }
          }
        }
      }

      if (display == null || modes.isEmpty) {
        debugPrint('AFR: No display or modes found');
        return;
      }

      // Store original mode
      _originalLinuxMode ??= currentMode;

      // Find best matching mode
      _LinuxMode? bestMode;
      for (final mode in modes) {
        if ((mode.rate - fps).abs() < 1.0) {
          bestMode = mode;
          break;
        }
        // Accept integer multiples
        if ((mode.rate - fps * 2).abs() < 1.0) {
          bestMode = mode;
          break;
        }
      }

      if (bestMode != null) {
        final modeStr = '${bestMode.resolution}@${bestMode.rate}';
        if (modeStr != currentMode) {
          await Process.run('xrandr', [
            '--output',
            display,
            '--mode',
            bestMode.resolution,
            '--rate',
            bestMode.rate.toString(),
          ]);
          debugPrint(
            'AFR: Linux switched to ${bestMode.rate}Hz for ${fps}fps content.',
          );
        }
      }
    } catch (e) {
      debugPrint('AFR: Linux error: $e');
    }
  }

  Future<void> _restoreLinux() async {
    if (_originalLinuxMode != null && _linuxDisplay != null) {
      try {
        final parts = _originalLinuxMode!.split('@');
        if (parts.length == 2) {
          await Process.run('xrandr', [
            '--output',
            _linuxDisplay!,
            '--mode',
            parts[0],
            '--rate',
            parts[1],
          ]);
          debugPrint('AFR: Linux restored to original mode.');
        }
        _originalLinuxMode = null;
      } catch (e) {
        debugPrint('AFR: Linux restore error: $e');
      }
    }
  }
}

/// Helper class for Linux display modes.
class _LinuxMode {
  _LinuxMode(this.resolution, this.rate);

  final String resolution;
  final double rate;
}
