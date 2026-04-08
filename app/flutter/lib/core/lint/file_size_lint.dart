import 'dart:io';

/// Regex-based source scanner that detects files exceeding [maxLines] lines.
///
/// Scans both `lib/` (Dart) and `rust/` (Rust) directories, excluding
/// generated files (FRB bindings, `.g.dart`, `.freezed.dart`) and
/// localization files (`lib/l10n/`).
///
/// Run via test: `flutter test test/core/lint/file_size_lint_test.dart`
class FileSizeLint {
  /// Maximum allowed lines per human-written source file.
  static const int maxLines = 500;

  /// Path patterns to exclude from scanning.
  ///
  /// Uses forward-slash normalized paths for cross-platform compatibility.
  static const _excludePatterns = ['lib/src/rust/', 'lib/l10n/'];

  /// File name suffixes to exclude (generated code).
  static const _excludeSuffixes = ['.g.dart', '.freezed.dart'];

  /// Scans [projectRoot] for source files exceeding [maxLines].
  ///
  /// Returns a list of [FileSizeViolation]s sorted by line count descending.
  static List<FileSizeViolation> scan(String projectRoot) {
    final violations = <FileSizeViolation>[];
    final root = projectRoot.replaceAll(r'\', '/');

    // Scan lib/ for Dart files
    final libDir = Directory('$projectRoot/lib');
    if (libDir.existsSync()) {
      _scanDirectory(libDir, root, ['.dart'], violations);
    }

    // Scan rust/ for Rust files
    final rustDir = Directory('$projectRoot/rust');
    if (rustDir.existsSync()) {
      _scanDirectory(rustDir, root, ['.rs'], violations);
    }

    // Sort by line count descending (worst offenders first)
    violations.sort((a, b) => b.lineCount.compareTo(a.lineCount));

    return violations;
  }

  static void _scanDirectory(
    Directory dir,
    String root,
    List<String> extensions,
    List<FileSizeViolation> violations,
  ) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File) continue;

      final path = entity.path.replaceAll(r'\', '/');
      final relativePath =
          path.startsWith(root) ? path.substring(root.length + 1) : path;

      // Check file extension
      if (!extensions.any((ext) => relativePath.endsWith(ext))) continue;

      // Check exclusion patterns
      if (_isExcluded(relativePath)) continue;

      // Count lines
      final lineCount = entity.readAsLinesSync().length;
      if (lineCount > maxLines) {
        violations.add(
          FileSizeViolation(
            path: relativePath,
            lineCount: lineCount,
            overBy: lineCount - maxLines,
          ),
        );
      }
    }
  }

  /// Returns `true` if [relativePath] matches any exclusion pattern.
  static bool _isExcluded(String relativePath) {
    for (final pattern in _excludePatterns) {
      if (relativePath.contains(pattern)) return true;
    }
    for (final suffix in _excludeSuffixes) {
      if (relativePath.endsWith(suffix)) return true;
    }
    return false;
  }
}

/// A file that exceeds [FileSizeLint.maxLines].
class FileSizeViolation {
  /// Creates a file size violation.
  const FileSizeViolation({
    required this.path,
    required this.lineCount,
    required this.overBy,
  });

  /// Relative path from project root.
  final String path;

  /// Total line count.
  final int lineCount;

  /// Lines over the limit (`lineCount - maxLines`).
  final int overBy;

  @override
  String toString() => '$path: $lineCount lines ($overBy over limit)';
}
