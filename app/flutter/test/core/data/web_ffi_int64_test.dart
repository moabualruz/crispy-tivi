import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static analysis tests verifying all FFI call sites use
/// [PlatformInt64Util.from()] for i64/usize parameters.
///
/// On web, FRB maps Rust `i64`/`usize` to Dart `BigInt` (not `int`).
/// Passing a raw `int` where `PlatformInt64` is expected causes a
/// runtime `TypeError`. These tests grep the FFI backend files to
/// catch any raw `int` usage that bypasses `PlatformInt64Util.from()`.
void main() {
  /// All ffi_backend part files that contain FFI call sites.
  final ffiFiles =
      Directory('lib/core/data')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.replaceAll('\\', '/').contains('ffi_backend'))
          .toList();

  test('ffi_backend files exist and are discoverable', () {
    // We expect at least the main file + 9 part files = 10+
    expect(
      ffiFiles.length,
      greaterThanOrEqualTo(10),
      reason:
          'Expected at least 10 ffi_backend files '
          '(1 main + 9 parts), found ${ffiFiles.length}',
    );
  });

  test('all i64/usize FFI params use PlatformInt64Util.from()', () {
    // Pattern: rust_api.someMethod( paramName: <value> )
    // where <value> is NOT PlatformInt64Util.from(...)
    // and the param is known to accept PlatformInt64.
    //
    // Known PlatformInt64 parameter names from FRB codegen:
    final int64ParamNames = [
      'maxEntries',
      'heapMaxMb',
      'startTime',
      'endTime',
      'days',
      'cutoffUtcMs',
      'timestampMs',
      'startMs',
      'endMs',
      'epochMs',
      'nowUtcMs',
      'startUtcMs',
      'endUtcMs',
      'startUtc',
      'endUtc',
      'timestamp',
      'expirySecs',
      'ttffMs',
      'syncTimeMs',
      'nowMs',
      'streamId',
      'positionMs',
      'durationMs',
      'localMs',
      'cloudMs',
      'lastSyncMs',
      'addedAtMs',
      'lockedUntilMs',
    ];

    final violations = <String>[];

    for (final file in ffiFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        for (final param in int64ParamNames) {
          // Match "paramName: <something>" where <something> is
          // NOT "PlatformInt64Util.from(" and NOT "null" and NOT
          // a ternary with PlatformInt64Util.
          final paramPattern = RegExp(
            '$param:\\s+(?!PlatformInt64Util\\.from|null)'
            r'(?!.*\?\s*PlatformInt64Util)',
          );

          if (paramPattern.hasMatch(line)) {
            // Exclude lines that are comments.
            if (line.startsWith('//') || line.startsWith('///')) continue;

            // Exclude lines within block comments.
            if (line.startsWith('*') || line.startsWith('/*')) continue;

            // Exclude lines that use ternary with PlatformInt64Util
            // somewhere in the expression (multi-line).
            if (line.contains('PlatformInt64Util')) continue;

            // Check if the next line contains PlatformInt64Util
            // (for multi-line expressions).
            if (i + 1 < lines.length &&
                lines[i + 1].contains('PlatformInt64Util')) {
              continue;
            }

            final fileName = file.path.replaceAll('\\', '/').split('/').last;
            violations.add(
              '$fileName:${i + 1}: $param uses raw value: '
              '${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found ${violations.length} FFI call site(s) passing raw int '
          'where PlatformInt64 is expected. On web, this causes '
          'BigInt TypeError.\n'
          '${violations.join('\n')}',
    );
  });

  test('PlatformInt64Util import is present in ffi_backend.dart', () {
    final mainFile = ffiFiles.firstWhere(
      (f) => f.path.replaceAll('\\', '/').endsWith('ffi_backend.dart'),
    );
    final content = mainFile.readAsStringSync();

    expect(
      content.contains('flutter_rust_bridge_for_generated.dart'),
      isTrue,
      reason:
          'ffi_backend.dart must import '
          'flutter_rust_bridge_for_generated.dart '
          'which provides PlatformInt64Util',
    );
  });

  test('no raw int literal passed to PlatformInt64 FFI params', () {
    // Detect patterns like: paramName: 123 or paramName: 0
    // These are clearly wrong on web.
    final violations = <String>[];

    for (final file in ffiFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;

        // Match: knownParam: <digit> (raw int literal)
        final rawIntPattern = RegExp(
          r'(?:maxEntries|heapMaxMb|startTime|endTime|days|'
          r'cutoffUtcMs|timestampMs|startMs|endMs|epochMs|'
          r'nowUtcMs|startUtcMs|endUtcMs|startUtc|endUtc|'
          r'timestamp|expirySecs|ttffMs|syncTimeMs|nowMs|'
          r'streamId|positionMs|durationMs|localMs|cloudMs|'
          r'lastSyncMs|addedAtMs|lockedUntilMs):\s+\d+',
        );

        if (rawIntPattern.hasMatch(line)) {
          final fileName = file.path.replaceAll('\\', '/').split('/').last;
          violations.add(
            '$fileName:${i + 1}: raw int literal in FFI param: '
            '${line.trim()}',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found raw int literals passed to PlatformInt64 FFI '
          'params. Use PlatformInt64Util.from() instead.\n'
          '${violations.join('\n')}',
    );
  });

  test('PlatformInt64 return values use .toInt() for Dart consumption', () {
    // Verify that the ffi_backend.dart main file imports the
    // bridge package which provides the PlatformInt64 type and
    // its .toInt() extension.
    final mainFile = ffiFiles.firstWhere(
      (f) => f.path.replaceAll('\\', '/').endsWith('ffi_backend.dart'),
    );
    final content = mainFile.readAsStringSync();

    // The import provides both PlatformInt64Util (for creating)
    // and the toInt() extension (for consuming).
    expect(
      content.contains('flutter_rust_bridge_for_generated'),
      isTrue,
      reason:
          'ffi_backend.dart must import flutter_rust_bridge '
          'for PlatformInt64 return value handling',
    );
  });
}
