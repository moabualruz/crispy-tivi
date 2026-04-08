import 'package:equatable/equatable.dart';

/// Represents a Plex Media Server connection.
class PlexServer extends Equatable {
  const PlexServer({
    required this.url,
    required this.name,
    required this.accessToken,
    required this.clientIdentifier,
  });

  final String url;
  final String name;
  final String accessToken; // X-Plex-Token
  final String clientIdentifier; // X-Plex-Client-Identifier

  @override
  List<Object?> get props => [url, name, accessToken, clientIdentifier];
}
