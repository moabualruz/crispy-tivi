// ignore_for_file: avoid_print
import 'dart:io';

import 'package:crispy_tivi/core/lint/architecture_boundary_lint.dart';

/// CI boundary checker: scans all Dart files under `lib/features/` for
/// architecture boundary violations (forbidden imports in presentation/,
/// domain/, application/ layers).
///
/// Zero-tolerance mode: ANY violation fails the build. No allowlist,
/// no exceptions. All forbidden imports must be remediated before merge.
///
/// Usage:
///   dart run scripts/check_boundary.dart
///
/// Exit codes:
///   0 - zero violations
///   1 - violations found
void main() {
  final featuresDir = Directory('lib/features');

  if (!featuresDir.existsSync()) {
    print('ERROR: lib/features/ directory not found');
    exit(1);
  }

  final files =
      featuresDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  var totalViolations = 0;
  final violations = <String>[];

  for (final file in files) {
    final fileViolations = ArchitectureBoundaryLint.scanFile(file.path);
    for (final v in fileViolations) {
      totalViolations++;
      final normalized = v.file.replaceAll(r'\', '/');
      violations.add('  $normalized:${v.line}: ${v.message}');
    }
  }

  // Summary
  print('Architecture Boundary Check');
  print('===========================');
  print('Files scanned: ${files.length}');
  print('Violations: $totalViolations');

  if (violations.isNotEmpty) {
    print('');
    print('VIOLATIONS (must fix before merge):');
    for (final v in violations) {
      print(v);
    }
    exit(1);
  }

  print('');
  print('PASS: Zero architecture boundary violations.');
  exit(0);
}
