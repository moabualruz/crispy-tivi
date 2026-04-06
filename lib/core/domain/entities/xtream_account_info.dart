import 'package:meta/meta.dart';

/// Parsed Xtream Codes account and server information.
///
/// Populated from the Xtream authentication response at
/// `player_api.php?username=X&password=Y` (no action param
/// or `action=get_account_info`). Contains subscription
/// status, connection limits, and server configuration.
@immutable
class XtreamAccountInfo {
  const XtreamAccountInfo({
    this.username,
    this.message,
    this.auth = 0,
    this.status,
    this.expDate,
    this.isTrial,
    this.activeCons,
    this.createdAt,
    this.maxConnections,
    this.allowedOutputFormats = const [],
    this.serverUrl,
    this.serverPort,
    this.serverHttpsPort,
    this.serverProtocol,
    this.serverRtmpPort,
    this.serverTimezone,
    this.serverTimestampNow,
    this.serverTimeNow,
  });

  // ── user_info fields ──────────────────────────────

  /// Username on the Xtream server.
  final String? username;

  /// Server-provided status message.
  final String? message;

  /// Whether the user is authenticated (1 = yes).
  final int auth;

  /// Account status string (e.g. "Active", "Banned",
  /// "Disabled", "Expired").
  final String? status;

  /// Subscription expiration as a Unix timestamp string.
  final String? expDate;

  /// Whether this is a trial account ("0" or "1").
  final String? isTrial;

  /// Number of currently active connections.
  final String? activeCons;

  /// Account creation Unix timestamp string.
  final String? createdAt;

  /// Maximum simultaneous connections allowed.
  final String? maxConnections;

  /// Allowed output stream formats
  /// (e.g. ["m3u8", "ts", "rtmp"]).
  final List<String> allowedOutputFormats;

  // ── server_info fields ────────────────────────────

  /// Server hostname or IP.
  final String? serverUrl;

  /// HTTP port.
  final String? serverPort;

  /// HTTPS port.
  final String? serverHttpsPort;

  /// Server protocol ("http" or "https").
  final String? serverProtocol;

  /// RTMP port.
  final String? serverRtmpPort;

  /// Server timezone (e.g. "Europe/London").
  final String? serverTimezone;

  /// Server current Unix timestamp.
  final int? serverTimestampNow;

  /// Server current time as readable string.
  final String? serverTimeNow;

  /// Whether the account is authenticated.
  bool get isAuthenticated => auth == 1;

  /// Whether this is a trial subscription.
  bool get isTrialAccount => isTrial == '1';

  /// Whether the account status is "Active".
  bool get isActive => status?.toLowerCase() == 'active';

  /// Subscription expiration as a [DateTime], or null if
  /// not available or unparseable.
  DateTime? get expirationDate {
    if (expDate == null) return null;
    final epoch = int.tryParse(expDate!);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
  }

  /// Maximum connections as an integer, or null.
  int? get maxConnectionsInt =>
      maxConnections != null ? int.tryParse(maxConnections!) : null;

  /// Active connections as an integer, or null.
  int? get activeConsInt =>
      activeCons != null ? int.tryParse(activeCons!) : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XtreamAccountInfo &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          auth == other.auth &&
          status == other.status &&
          expDate == other.expDate &&
          maxConnections == other.maxConnections;

  @override
  int get hashCode =>
      Object.hash(runtimeType, username, auth, status, expDate, maxConnections);

  @override
  String toString() =>
      'XtreamAccountInfo(user=$username, status=$status, '
      'auth=$auth, exp=$expDate)';
}
