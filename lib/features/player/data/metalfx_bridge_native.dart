/// Native implementation of MetalFX bridge.
///
/// Uses runtime [Platform] check to determine if
/// current device is macOS or iOS. Actual platform
/// channel calls to Swift MTLFXSpatialScaler are
/// implemented here.
///
/// See `.ai/docs/project-specs/video_upscaling_spec.md` Phase 3.
library;

import 'dart:io' show Platform;
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.crispytivi/metalfx');

/// Whether MetalFX is potentially available.
///
/// Returns `true` on macOS and iOS only. Actual
/// availability depends on Apple Silicon GPU and
/// OS version (macOS 13+ / iOS 16+).
bool get isMetalFxPlatform {
  try {
    return Platform.isMacOS || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Initialize MetalFX spatial upscaler.
///
/// Returns `true` if MetalFX is available and
/// initialized successfully.
Future<bool> initMetalFx() async {
  if (!isMetalFxPlatform) return false;
  try {
    final result = await _channel.invokeMethod<bool>('init');
    return result ?? false;
  } on PlatformException {
    return false;
  }
}

/// Apply MetalFX spatial upscaling.
///
/// [scaleFactor] is the target scale (e.g. 2.0).
/// Returns `true` on success.
Future<bool> applyMetalFx({required double scaleFactor}) async {
  if (!isMetalFxPlatform) return false;
  try {
    final result = await _channel.invokeMethod<bool>('apply', {
      'scaleFactor': scaleFactor,
    });
    return result ?? false;
  } on PlatformException {
    return false;
  }
}

/// Remove MetalFX upscaling.
Future<void> removeMetalFx() async {
  if (!isMetalFxPlatform) return;
  try {
    await _channel.invokeMethod<void>('remove');
  } on PlatformException {
    // Ignore.
  }
}

/// Dispose MetalFX resources.
Future<void> disposeMetalFx() async {
  if (!isMetalFxPlatform) return;
  try {
    await _channel.invokeMethod<void>('dispose');
  } on PlatformException {
    // Ignore.
  }
}
