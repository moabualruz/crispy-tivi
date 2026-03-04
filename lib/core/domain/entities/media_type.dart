/// Types of media content available in media sources.
enum MediaType {
  /// A container for other items (e.g., a folder or library).
  folder,

  /// A movie.
  movie,

  /// A TV series container.
  series,

  /// A season within a TV series.
  season,

  /// A single episode of a TV series.
  episode,

  /// A live TV channel.
  channel,

  /// Unknown or unsupported type.
  unknown,
}
