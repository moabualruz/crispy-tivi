import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/core/lint/file_size_lint.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_size_lint_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Helper: create a Dart file with [lineCount] lines under [subPath].
  File createFile(String subPath, int lineCount) {
    final file = File('${tempDir.path}/$subPath');
    file.parent.createSync(recursive: true);
    final lines = List.generate(lineCount, (i) => '// line $i');
    file.writeAsStringSync(lines.join('\n'));
    return file;
  }

  group('FileSizeLint', () {
    test('returns empty list when all files are under 500 lines', () {
      createFile('lib/foo.dart', 100);
      createFile('lib/bar.dart', 499);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, isEmpty);
    });

    test('detects file with 501+ lines and returns violation', () {
      createFile('lib/big_file.dart', 501);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, hasLength(1));
      expect(violations.first.lineCount, 501);
      expect(violations.first.overBy, 1);
      expect(violations.first.path, contains('big_file.dart'));
    });

    test('excludes lib/src/rust/ files (FRB generated)', () {
      createFile('lib/src/rust/api.dart', 2000);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, isEmpty);
    });

    test('excludes .g.dart and .freezed.dart files', () {
      createFile('lib/model.g.dart', 800);
      createFile('lib/state.freezed.dart', 900);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, isEmpty);
    });

    test('excludes lib/l10n/ files', () {
      createFile('lib/l10n/app_en.dart', 1000);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, isEmpty);
    });

    test('scans both lib/ and rust/ directories', () {
      createFile('lib/small.dart', 100);
      createFile('rust/crates/core/src/big.rs', 600);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, hasLength(1));
      expect(violations.first.path, contains('big.rs'));
    });

    test('500-line file is not a violation', () {
      createFile('lib/exactly_500.dart', 500);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, isEmpty);
    });

    test('violations are sorted by line count descending', () {
      createFile('lib/a.dart', 600);
      createFile('lib/b.dart', 800);
      createFile('lib/c.dart', 501);

      final violations = FileSizeLint.scan(tempDir.path);

      expect(violations, hasLength(3));
      expect(violations[0].lineCount, 800);
      expect(violations[1].lineCount, 600);
      expect(violations[2].lineCount, 501);
    });
  });
}
