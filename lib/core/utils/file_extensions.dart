/// Canonical file-extension sets for video, audio, subtitle, and image files.
///
/// Single source of truth shared by DVR file-type filters,
/// cloud file grids, and algorithm fallbacks.
class FileExtensions {
  FileExtensions._();

  /// Video container formats.
  static const Set<String> video = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'ts',
    'mpg',
    'mpeg',
    'm2ts',
    'wmv',
    'flv',
    'webm',
    'm4v',
  };

  /// Audio container formats.
  static const Set<String> audio = {
    'mp3',
    'aac',
    'flac',
    'ogg',
    'wav',
    'opus',
    'm4a',
    'wma',
    'ac3',
    'eac3',
  };

  /// Subtitle / caption formats.
  static const Set<String> subtitle = {
    'srt',
    'ass',
    'ssa',
    'vtt',
    'sub',
    'idx',
    'sup',
    'dfxp',
    'ttml',
  };

  /// Image formats.
  static const Set<String> image = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
}
