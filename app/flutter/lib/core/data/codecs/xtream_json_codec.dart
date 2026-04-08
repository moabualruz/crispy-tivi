import '../../domain/entities/xtream_account_info.dart';

/// Codec for converting [XtreamAccountInfo] to/from JSON maps.
///
/// Keeps infrastructure concerns out of the domain layer.
/// JSON shape mirrors the Xtream Codes authentication API response.
abstract final class XtreamJsonCodec {
  /// Deserializes an [XtreamAccountInfo] from a JSON map.
  static XtreamAccountInfo fromJson(Map<String, dynamic> json) {
    return XtreamAccountInfo(
      username: json['username'] as String?,
      message: json['message'] as String?,
      auth: json['auth'] as int? ?? 0,
      status: json['status'] as String?,
      expDate: json['exp_date'] as String?,
      isTrial: json['is_trial'] as String?,
      activeCons: json['active_cons'] as String?,
      createdAt: json['created_at'] as String?,
      maxConnections: json['max_connections'] as String?,
      allowedOutputFormats:
          (json['allowed_output_formats'] as List<dynamic>?)?.cast<String>() ??
          const [],
      serverUrl: json['server_url'] as String?,
      serverPort: json['server_port'] as String?,
      serverHttpsPort: json['server_https_port'] as String?,
      serverProtocol: json['server_protocol'] as String?,
      serverRtmpPort: json['server_rtmp_port'] as String?,
      serverTimezone: json['server_timezone'] as String?,
      serverTimestampNow: json['server_timestamp_now'] as int?,
      serverTimeNow: json['server_time_now'] as String?,
    );
  }

  /// Serializes an [XtreamAccountInfo] to a JSON-compatible map.
  static Map<String, dynamic> toJson(XtreamAccountInfo info) => {
    'username': info.username,
    'message': info.message,
    'auth': info.auth,
    'status': info.status,
    'exp_date': info.expDate,
    'is_trial': info.isTrial,
    'active_cons': info.activeCons,
    'created_at': info.createdAt,
    'max_connections': info.maxConnections,
    'allowed_output_formats': info.allowedOutputFormats,
    'server_url': info.serverUrl,
    'server_port': info.serverPort,
    'server_https_port': info.serverHttpsPort,
    'server_protocol': info.serverProtocol,
    'server_rtmp_port': info.serverRtmpPort,
    'server_timezone': info.serverTimezone,
    'server_timestamp_now': info.serverTimestampNow,
    'server_time_now': info.serverTimeNow,
  };
}
