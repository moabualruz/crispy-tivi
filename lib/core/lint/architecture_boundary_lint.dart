import 'dart:io';

import 'min_touch_target_lint.dart';

/// Regex-based source scanner that detects forbidden imports in `lib/features/`.
///
/// Architecture boundary rule: files under `features/` must not import
/// platform I/O (`dart:io`, `dart:convert`), HTTP packages (`dio`, `http`),
/// direct FFI bindings (`src/rust/`), or database packages (`drift`, `sqlite`).
///
/// These imports belong in `lib/core/` or `lib/src/` — never in feature code.
///
/// Run via test:
/// `flutter test test/core/lint/architecture_boundary_lint_test.dart`
class ArchitectureBoundaryLint {
  /// Forbidden import rules applied to files whose path contains `features/`.
  ///
  /// Each entry maps a regex pattern to a human-readable category description.
  static final _rules = <_ForbiddenImportRule>[
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]dart:io['";\s]'''),
      category: 'Platform I/O',
      reason:
          'dart:io is forbidden in features/ — use core/ abstractions instead',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]dart:convert['";\s]'''),
      category: 'JSON/encoding',
      reason:
          'dart:convert is forbidden in features/ — data layer handles '
          'serialization',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]package:dio/'''),
      category: 'HTTP client',
      reason:
          'package:dio is forbidden in features/ — HTTP calls belong in '
          'core/data',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]package:http/'''),
      category: 'HTTP client',
      reason:
          'package:http is forbidden in features/ — HTTP calls belong in '
          'core/data',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"][^'"]*src/rust/'''),
      category: 'Direct FFI',
      reason:
          'Direct FFI imports are forbidden in features/ — use CacheService '
          'providers instead',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]package:drift/'''),
      category: 'Database',
      reason:
          'package:drift is forbidden in features/ — database access belongs '
          'in core/data',
    ),
    _ForbiddenImportRule(
      pattern: RegExp(r'''import\s+['"]package:sqlite'''),
      category: 'Database',
      reason:
          'package:sqlite is forbidden in features/ — database access belongs '
          'in core/data',
    ),
  ];

  /// Scans a Dart source file at [filePath] and returns violations.
  ///
  /// Returns an empty list if the file does not exist or is not under
  /// `features/`.
  static List<LintViolation> scanFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    // Normalize path separators for cross-platform compatibility
    final normalizedPath = filePath.replaceAll(r'\', '/');
    return scanSource(file.readAsStringSync(), normalizedPath);
  }

  /// Scans Dart [source] code and returns architecture boundary violations.
  ///
  /// Only enforced when [filePath] contains `features/`. Files in `core/`,
  /// `src/`, or other directories are exempt.
  ///
  /// Note: [filePath] should use forward slashes. [scanFile] normalizes
  /// automatically; callers of [scanSource] should normalize if needed.
  static List<LintViolation> scanSource(String source, [String? filePath]) {
    // Only enforce on files under features/
    if (filePath == null || !filePath.contains('features/')) return [];

    final violations = <LintViolation>[];
    final lines = source.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Skip non-import lines for performance
      if (!line.trimLeft().startsWith('import ')) continue;

      for (final rule in _rules) {
        if (rule.pattern.hasMatch(line)) {
          violations.add(
            LintViolation(file: filePath, line: i + 1, message: rule.reason),
          );
          break; // One violation per line
        }
      }
    }

    return violations;
  }
}

/// Internal rule definition for forbidden import patterns.
class _ForbiddenImportRule {
  const _ForbiddenImportRule({
    required this.pattern,
    required this.category,
    required this.reason,
  });

  /// Regex pattern to match against import lines.
  final RegExp pattern;

  /// Human-readable category (e.g., 'Platform I/O', 'HTTP client').
  final String category;

  /// Explanation of why this import is forbidden.
  final String reason;
}
