import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_service.dart';

/// Service for device identification and naming.
///
/// Generates a unique device ID on first run and allows users to set a
/// custom device name for cross-device continuity features.
class DeviceService {
  DeviceService(this._cache);

  final CacheService _cache;

  static const _deviceIdKey = 'crispy_tivi_device_id';
  static const _deviceNameKey = 'crispy_tivi_device_name';

  String? _cachedDeviceId;
  String? _cachedDeviceName;

  /// Gets the unique device ID, generating one if needed.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    // Check if we have a stored ID.
    final stored = await _cache.getSetting(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedDeviceId = stored;
      return stored;
    }

    // Generate a new UUID-style device ID.
    final newId = _generateUuid();
    await _cache.setSetting(_deviceIdKey, newId);
    _cachedDeviceId = newId;
    return newId;
  }

  /// Generates a UUID v4-style random identifier.
  String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant (8, 9, a, or b).
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    // Format as UUID string.
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Gets the user-set device name, or auto-generates one from system info.
  Future<String> getDeviceName() async {
    if (_cachedDeviceName != null) return _cachedDeviceName!;

    // Check for user-set name.
    final stored = await _cache.getSetting(_deviceNameKey);
    if (stored != null && stored.isNotEmpty) {
      _cachedDeviceName = stored;
      return stored;
    }

    // Auto-generate from system info.
    final autoName = _generateDeviceName();
    _cachedDeviceName = autoName;
    return autoName;
  }

  /// Sets a custom device name.
  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _cache.setSetting(_deviceNameKey, trimmed);
    _cachedDeviceName = trimmed;
  }

  /// Clears the custom device name, reverting to auto-generated.
  Future<void> clearDeviceName() async {
    await _cache.removeSetting(_deviceNameKey);
    _cachedDeviceName = null;
  }

  /// Generates a device name from platform information.
  String _generateDeviceName() {
    if (kIsWeb) {
      return 'Web Browser';
    }

    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      } else if (Platform.isMacOS) {
        return 'Mac';
      } else if (Platform.isWindows) {
        // Try to get computer name from environment.
        final name = Platform.environment['COMPUTERNAME'];
        return name?.isNotEmpty == true ? name! : 'Windows PC';
      } else if (Platform.isLinux) {
        return 'Linux Device';
      }
    } catch (e) {
      debugPrint('DeviceService: Failed to get device info: $e');
    }

    return 'Unknown Device';
  }

  /// Gets device info summary for display in settings.
  Future<DeviceInfo> getDeviceInfo() async {
    final customName = await _cache.getSetting(_deviceNameKey);
    return DeviceInfo(
      id: await getDeviceId(),
      name: await getDeviceName(),
      isCustomName: customName != null && customName.isNotEmpty,
    );
  }
}

/// Device information summary.
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.isCustomName,
  });

  /// Unique device identifier.
  final String id;

  /// Display name (custom or auto-generated).
  final String name;

  /// Whether the name was set by the user.
  final bool isCustomName;
}

/// Provider for the device service.
final deviceServiceProvider = Provider<DeviceService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  return DeviceService(cache);
});
