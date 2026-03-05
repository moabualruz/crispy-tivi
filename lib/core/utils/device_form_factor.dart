import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

/// Physical device form factor, resolved once at app startup.
///
/// Detection methods per platform:
/// - **Desktop** (Win/Lin/Mac): `Platform.isWindows/isLinux/isMacOS`
/// - **Android TV**: Native `PackageManager.FEATURE_LEANBACK` ||
///   `UiModeManager.UI_MODE_TYPE_TELEVISION` via `crispy/device` channel
/// - **Android tablet**: `shortestSide >= 600dp` (heuristic, no native API)
/// - **Android phone**: `shortestSide < 600dp`
/// - **iPad**: Native `UIDevice.userInterfaceIdiom == .pad` via channel
/// - **iPhone**: Native `UIDevice.userInterfaceIdiom == .phone` via channel
/// - **Web**: Always [web] (no further distinction).
enum DeviceFormFactor {
  /// Windows, Linux, macOS.
  desktop,

  /// Android TV (leanback).
  androidTV,

  /// Android tablet (shortestSide >= 600dp, not TV).
  androidTablet,

  /// Android phone (shortestSide < 600dp).
  androidPhone,

  /// iPad (UIDevice idiom == .pad).
  iPad,

  /// iPhone / iPod touch.
  iPhone,

  /// Browser — no further distinction.
  web;

  /// True for form factors where UI auto-scaling should apply.
  bool get supportsAutoScale => this == desktop || this == androidTV;

  /// True for any TV form factor.
  bool get isTV => this == androidTV;

  /// True for any phone form factor.
  bool get isPhone => this == androidPhone || this == iPhone;

  /// True for any tablet form factor.
  bool get isTablet => this == androidTablet || this == iPad;

  /// True for any desktop form factor.
  bool get isDesktop => this == desktop;

  /// True for mobile (phone or tablet, not TV).
  bool get isMobile => isPhone || isTablet;
}

/// Singleton accessor for the detected device form factor.
///
/// Call [init] once in `main()` before `runApp()`. After that,
/// [current] is safe to read synchronously from anywhere.
abstract final class DeviceFormFactorService {
  static DeviceFormFactor _current = DeviceFormFactor.web;
  static const _channel = MethodChannel('crispy/device');

  /// The detected form factor. Safe to read synchronously after [init].
  static DeviceFormFactor get current => _current;

  /// Must be called once in `main()` before `runApp()`.
  static Future<void> init() async {
    if (kIsWeb) {
      _current = DeviceFormFactor.web;
      return;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _current = DeviceFormFactor.desktop;
      return;
    }

    // Android / iOS — ask native layer.
    try {
      final result = await _channel.invokeMethod<String>('getFormFactor');
      if (Platform.isAndroid) {
        if (result == 'tv') {
          _current = DeviceFormFactor.androidTV;
        } else {
          // Tablet vs phone heuristic — use PlatformDispatcher
          // since no BuildContext is available at init time.
          final view = PlatformDispatcher.instance.views.firstOrNull;
          if (view != null) {
            final logicalSize = view.physicalSize / view.devicePixelRatio;
            _current =
                logicalSize.shortestSide >= 600
                    ? DeviceFormFactor.androidTablet
                    : DeviceFormFactor.androidPhone;
          } else {
            _current = DeviceFormFactor.androidPhone;
          }
        }
      } else if (Platform.isIOS) {
        _current = switch (result) {
          'tablet' => DeviceFormFactor.iPad,
          'tv' => DeviceFormFactor.iPad, // tvOS future-proof
          _ => DeviceFormFactor.iPhone,
        };
      }
    } catch (_) {
      // Channel not available (old native build?) — fall back safely.
      if (Platform.isAndroid) {
        _current = DeviceFormFactor.androidPhone;
      } else if (Platform.isIOS) {
        _current = DeviceFormFactor.iPhone;
      }
    }
  }

  /// Override for testing. Pass `null` to reset.
  @visibleForTesting
  static set debugOverride(DeviceFormFactor? value) {
    if (value != null) _current = value;
  }
}
