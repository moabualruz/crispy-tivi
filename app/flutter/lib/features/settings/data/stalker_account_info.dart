import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/cache_service.dart';
import '../../../core/domain/entities/playlist_source.dart';

/// Stalker portal account/subscription information.
@immutable
class StalkerAccountInfo {
  const StalkerAccountInfo({
    this.status,
    this.expiryDate,
    this.maxConnections,
    this.isTrial = false,
    this.phone,
    this.tariffPlan,
  });

  /// Account status (e.g., "Active", "Expired").
  final String? status;

  /// Subscription expiry date as a display string.
  final String? expiryDate;

  /// Maximum simultaneous connections allowed.
  final String? maxConnections;

  /// Whether this is a trial account.
  final bool isTrial;

  /// Account phone number.
  final String? phone;

  /// Tariff plan name.
  final String? tariffPlan;

  /// Creates from the JSON string returned by Rust.
  factory StalkerAccountInfo.fromJson(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return StalkerAccountInfo(
        status: data['status'] as String?,
        expiryDate: _formatExpiry(data['exp_date']),
        maxConnections: data['max_connections']?.toString(),
        isTrial: data['is_trial'] == '1' || data['is_trial'] == true,
        phone: data['phone'] as String?,
        tariffPlan:
            data['tariff_plan_name'] as String? ??
            data['tariff_plan'] as String?,
      );
    } catch (e) {
      debugPrint('StalkerAccountInfo: parse error: $e');
      return const StalkerAccountInfo();
    }
  }

  /// Formats an expiry date from various formats (Unix timestamp
  /// string, ISO date string, etc.) to a human-readable date.
  static String? _formatExpiry(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty || str == '0') return null;

    // Try Unix timestamp (seconds since epoch).
    final seconds = int.tryParse(str);
    if (seconds != null && seconds > 1000000000) {
      final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
    }

    // Try ISO date string.
    final dt = DateTime.tryParse(str);
    if (dt != null) {
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
    }

    // Return as-is.
    return str;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  String toString() => 'StalkerAccountInfo(status=$status, expiry=$expiryDate)';
}

/// Fetches Stalker account info using [WidgetRef] to access the backend.
///
/// Call this from the widget layer where you have the source object
/// and a [WidgetRef].
Future<StalkerAccountInfo?> fetchStalkerAccountInfoFromRef(
  WidgetRef ref,
  PlaylistSource source,
) async {
  if (source.type != PlaylistSourceType.stalkerPortal) return null;

  try {
    final backend = ref.read(crispyBackendProvider);
    final json = await backend.fetchStalkerAccountInfo(
      baseUrl: source.url,
      macAddress: source.macAddress ?? '',
      acceptInvalidCerts: source.acceptSelfSigned,
    );
    return StalkerAccountInfo.fromJson(json);
  } catch (e) {
    debugPrint('StalkerAccountInfo: fetch failed for ${source.name}: $e');
    return null;
  }
}
