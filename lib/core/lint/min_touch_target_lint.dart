import 'dart:io';

/// Lint-like source scanner that detects interactive widgets with explicit
/// size constraints under 44x44 logical pixels.
///
/// This is implemented as a regex-based source scanner instead of an
/// analyzer plugin because `custom_lint` has dependency conflicts with
/// `riverpod_generator` (analyzer version mismatch).
///
/// Run via test: `flutter test test/core/lint/min_touch_target_lint_test.dart`
///
/// Detects:
/// - `SizedBox(width: N, ...)` wrapping `GestureDetector`, `InkWell`,
///   `InkResponse`, or `IconButton` where N < 44.
/// - Does NOT flag Material widgets (ElevatedButton, TextButton, etc.)
///   since those are covered by `MaterialTapTargetSize.padded`.
class MinTouchTargetLint {
  /// Minimum touch target size in logical pixels.
  static const double minSize = 44.0;

  /// Interactive widget types that should meet minimum touch target.
  static const interactiveWidgets = {
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'IconButton',
  };

  /// Material widgets exempt from this check (theme handles sizing).
  static const exemptWidgets = {
    'ElevatedButton',
    'FilledButton',
    'TextButton',
    'OutlinedButton',
    'FloatingActionButton',
  };

  /// Scans a Dart source file and returns violations.
  static List<LintViolation> scanFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    return scanSource(file.readAsStringSync(), filePath);
  }

  /// Scans Dart source code and returns violations.
  ///
  /// Looks for patterns like:
  /// ```dart
  /// SizedBox(
  ///   width: 30,  // < 44
  ///   height: 30, // < 44
  ///   child: GestureDetector(...)
  /// )
  /// ```
  static List<LintViolation> scanSource(String source, [String? filePath]) {
    final violations = <LintViolation>[];

    // Pattern: SizedBox with numeric width/height followed by interactive child
    // We scan line-by-line looking for SizedBox blocks with undersized dimensions
    final lines = source.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for SizedBox or ConstrainedBox with explicit small dimensions
      if (!line.startsWith('SizedBox(') && !line.contains('SizedBox(')) {
        continue;
      }

      // Scan the next ~10 lines for width/height and child
      final block = _extractBlock(lines, i, 15);

      final width = _extractDimension(block, 'width');
      final height = _extractDimension(block, 'height');
      final childWidget = _extractChildWidget(block);

      if (childWidget == null) continue;

      // Skip exempt Material widgets
      if (exemptWidgets.contains(childWidget)) continue;

      // Check if child is interactive
      if (!interactiveWidgets.contains(childWidget)) continue;

      // Check dimensions
      final widthViolation = width != null && width < minSize;
      final heightViolation = height != null && height < minSize;

      if (widthViolation || heightViolation) {
        violations.add(
          LintViolation(
            file: filePath ?? '<unknown>',
            line: i + 1,
            message:
                'SizedBox wrapping $childWidget has '
                '${widthViolation ? "width: $width" : ""}'
                '${widthViolation && heightViolation ? ", " : ""}'
                '${heightViolation ? "height: $height" : ""} '
                '(minimum: $minSize).',
          ),
        );
      }
    }

    return violations;
  }

  static String _extractBlock(List<String> lines, int start, int maxLines) {
    final end = (start + maxLines).clamp(0, lines.length);
    return lines.sublist(start, end).join('\n');
  }

  static double? _extractDimension(String block, String name) {
    final pattern = RegExp('$name:\\s*([0-9]+\\.?[0-9]*)');
    final match = pattern.firstMatch(block);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  static String? _extractChildWidget(String block) {
    final pattern = RegExp(r'child:\s*(\w+)\s*\(');
    final match = pattern.firstMatch(block);
    return match?.group(1);
  }
}

/// A single lint violation found by [MinTouchTargetLint].
class LintViolation {
  /// Creates a lint violation.
  const LintViolation({
    required this.file,
    required this.line,
    required this.message,
  });

  /// Source file path.
  final String file;

  /// Line number (1-based).
  final int line;

  /// Human-readable violation message.
  final String message;

  @override
  String toString() => '$file:$line: $message';
}
