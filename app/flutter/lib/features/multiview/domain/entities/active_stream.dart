import 'package:equatable/equatable.dart';

/// Represents a single active stream in a Multi-View slot.
class ActiveStream extends Equatable {
  const ActiveStream({
    required this.url,
    required this.channelName,
    this.logoUrl,
    this.isMuted = true,
  });

  final String url;
  final String channelName;
  final String? logoUrl;
  final bool isMuted;

  ActiveStream copyWith({
    String? url,
    String? channelName,
    String? logoUrl,
    bool? isMuted,
  }) {
    return ActiveStream(
      url: url ?? this.url,
      channelName: channelName ?? this.channelName,
      logoUrl: logoUrl ?? this.logoUrl,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object?> get props => [url, channelName, logoUrl, isMuted];
}
