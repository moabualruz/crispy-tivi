import '../domain/entities/saved_layout.dart';

/// Codec for converting [SavedStream] to/from JSON maps.
///
/// Keeps infrastructure concerns out of the domain layer.
abstract final class MultiviewJsonCodec {
  /// Deserializes a [SavedStream] from a JSON map.
  static SavedStream savedStreamFromJson(Map<String, dynamic> json) {
    return SavedStream(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String,
      logoUrl: json['logoUrl'] as String?,
    );
  }

  /// Serializes a [SavedStream] to a JSON map.
  static Map<String, dynamic> savedStreamToJson(SavedStream stream) => {
    'channelId': stream.channelId,
    'channelName': stream.channelName,
    if (stream.logoUrl != null) 'logoUrl': stream.logoUrl,
  };
}
