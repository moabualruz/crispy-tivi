import 'package:crispy_tivi/core/lint/architecture_boundary_lint.dart';
import 'package:crispy_tivi/core/lint/min_touch_target_lint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArchitectureBoundaryLint', () {
    group('scanSource() with features/ presentation path', () {
      const presentationPath =
          'lib/features/iptv/presentation/screens/channel_screen.dart';

      test('should detect dart:io import as violation', () {
        const source = '''
import 'dart:io';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.line, 1);
        expect(violations.first.message, contains('dart:io'));
        expect(violations.first.file, presentationPath);
      });

      test('should detect dart:convert import as violation', () {
        const source = '''
import 'dart:convert';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('dart:convert'));
      });

      test('should detect package:dio import as violation', () {
        const source = '''
import 'package:dio/dio.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('dio'));
      });

      test('should detect package:http import as violation', () {
        const source = '''
import 'package:http/http.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('http'));
      });

      test('should detect direct FFI src/rust/ import as violation', () {
        const source = '''
import '../../src/rust/api/display.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('FFI'));
      });

      test('should detect package:drift import as violation', () {
        const source = '''
import 'package:drift/drift.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('drift'));
      });

      test('should detect package:sqlite3 import as violation', () {
        const source = '''
import 'package:sqlite3/sqlite3.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('sqlite'));
      });

      test('should return no violations for clean imports', () {
        const source = '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/channel.dart';
import '../../core/widgets/responsive_layout.dart';

class MyWidget extends ConsumerWidget {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, isEmpty);
      });

      test('should detect multiple violations with correct line numbers', () {
        const source = '''
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class Foo {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          presentationPath,
        );
        expect(violations, hasLength(3));
        expect(violations[0].line, 1);
        expect(violations[0].message, contains('dart:io'));
        expect(violations[1].line, 2);
        expect(violations[1].message, contains('dart:convert'));
        expect(violations[2].line, 4);
        expect(violations[2].message, contains('dio'));
      });
    });

    group('scanSource() with features/ domain path', () {
      const domainPath =
          'lib/features/player/domain/entities/audio_output.dart';

      test('should detect dart:io in domain as violation', () {
        const source = "import 'dart:io' show Platform;";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          domainPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('dart:io'));
      });

      test('should detect dart:convert in domain as violation', () {
        const source = "import 'dart:convert';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          domainPath,
        );
        expect(violations, hasLength(1));
        expect(violations.first.message, contains('dart:convert'));
      });
    });

    group('scanSource() with features/ data path (exempt)', () {
      const dataPath = 'lib/features/iptv/data/iptv_repository.dart';

      test('should allow dart:io in data layer', () {
        const source = "import 'dart:io';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          dataPath,
        );
        expect(violations, isEmpty);
      });

      test('should allow dart:convert in data layer', () {
        const source = "import 'dart:convert';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          dataPath,
        );
        expect(violations, isEmpty);
      });

      test('should allow package:dio in data layer', () {
        const source = "import 'package:dio/dio.dart';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          dataPath,
        );
        expect(violations, isEmpty);
      });

      test('should allow package:http in data layer', () {
        const source = "import 'package:http/http.dart';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          dataPath,
        );
        expect(violations, isEmpty);
      });

      test('should allow FFI imports in data layer', () {
        const source = "import '../../src/rust/api/display.dart';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          dataPath,
        );
        expect(violations, isEmpty);
      });

      test('should allow nested data layer (media_servers/plex/data/)', () {
        const source = "import 'package:dio/dio.dart';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          'lib/features/media_servers/plex/data/datasources/plex_api.dart',
        );
        expect(violations, isEmpty);
      });
    });

    group('scanSource() with non-features/ path', () {
      test('should return no violations for core/ files', () {
        const source = '''
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';

class CoreService {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          'lib/core/data/some_service.dart',
        );
        expect(violations, isEmpty);
      });

      test('should return no violations for src/ files', () {
        const source = '''
import 'dart:io';
import '../../src/rust/api/display.dart';

class RustBinding {}
''';
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          'lib/src/rust/api/display.dart',
        );
        expect(violations, isEmpty);
      });
    });

    group('scanSource() with backslash paths (Windows)', () {
      test('should detect violations when path uses backslashes', () {
        // scanSource requires callers to normalize; scanFile does it
        // automatically. This tests that callers who pre-normalize work.
        const source = "import 'dart:io';";
        final violations = ArchitectureBoundaryLint.scanSource(
          source,
          r'lib\features\dvr\presentation\screens\dvr_screen.dart'.replaceAll(
            r'\',
            '/',
          ),
        );
        expect(violations, hasLength(1));
      });
    });

    group('scanFile()', () {
      test('should return empty list for non-existent path', () {
        final violations = ArchitectureBoundaryLint.scanFile(
          'non/existent/path.dart',
        );
        expect(violations, isEmpty);
      });
    });

    group('LintViolation reuse', () {
      test('should use the same LintViolation class as MinTouchTargetLint', () {
        // Both scanners return List<LintViolation> from the same import
        final touchViolations = MinTouchTargetLint.scanSource('');
        final boundaryViolations = ArchitectureBoundaryLint.scanSource(
          "import 'dart:io';",
          'lib/features/x/y.dart',
        );
        // Both should be List<LintViolation> - this compiles only if same type
        final combined = <LintViolation>[
          ...touchViolations,
          ...boundaryViolations,
        ];
        expect(combined, isA<List<LintViolation>>());
      });
    });
  });
}
