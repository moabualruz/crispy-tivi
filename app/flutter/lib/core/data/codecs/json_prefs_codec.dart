import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Codec helpers for reading/writing JSON to [SharedPreferences]
/// and pretty-printing JSON maps.
///
/// Centralises dart:convert usage so presentation-layer code
/// never imports it directly.
abstract final class JsonPrefsCodec {
  /// Reads a JSON-encoded `Map<String, bool>` from [prefs] at [key].
  ///
  /// Returns an empty map if the key is absent or the value is invalid.
  static Map<String, bool> readBoolMap(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  /// Writes a `Map<String, bool>` as JSON to [prefs] at [key].
  static Future<void> writeBoolMap(
    SharedPreferences prefs,
    String key,
    Map<String, bool> value,
  ) async {
    await prefs.setString(key, jsonEncode(value));
  }

  /// Encodes a map as pretty-printed JSON (2-space indent).
  static String prettyEncode(Map<String, dynamic> map) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Decodes a JSON string to a `Map<String, dynamic>`.
  ///
  /// Returns `null` if [text] is not valid JSON or not a map.
  static Map<String, dynamic>? tryDecodeMap(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Decodes a JSON string to a dynamic value.
  ///
  /// Returns `null` if [text] is not valid JSON.
  static dynamic tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
