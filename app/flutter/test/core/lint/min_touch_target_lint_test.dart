import 'package:crispy_tivi/core/lint/min_touch_target_lint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MinTouchTargetLint', () {
    test('flags SizedBox wrapping GestureDetector with width < 44', () {
      const source = '''
SizedBox(
  width: 30,
  height: 30,
  child: GestureDetector(
    onTap: () {},
    child: Icon(Icons.close),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('width: 30'));
      expect(violations.first.message, contains('height: 30'));
      expect(violations.first.message, contains('GestureDetector'));
    });

    test('does NOT flag SizedBox wrapping GestureDetector with size >= 44', () {
      const source = '''
SizedBox(
  width: 48,
  height: 48,
  child: GestureDetector(
    onTap: () {},
    child: Icon(Icons.close),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, isEmpty);
    });

    test('does NOT flag ElevatedButton (Material widget, theme-handled)', () {
      const source = '''
SizedBox(
  width: 30,
  height: 30,
  child: ElevatedButton(
    onPressed: () {},
    child: Text('tap'),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, isEmpty);
    });

    test('flags SizedBox wrapping InkWell with height < 44', () {
      const source = '''
SizedBox(
  width: 100,
  height: 20,
  child: InkWell(
    onTap: () {},
    child: Text('tap'),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('height: 20'));
      expect(violations.first.message, contains('InkWell'));
    });

    test('flags SizedBox wrapping IconButton with width < 44', () {
      const source = '''
SizedBox(
  width: 24,
  child: IconButton(
    onPressed: () {},
    icon: Icon(Icons.close),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('IconButton'));
    });

    test('does NOT flag non-interactive child widgets', () {
      const source = '''
SizedBox(
  width: 20,
  height: 20,
  child: Container(
    color: Colors.red,
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, isEmpty);
    });

    test('does NOT flag SizedBox without explicit dimensions', () {
      const source = '''
SizedBox(
  child: GestureDetector(
    onTap: () {},
    child: Icon(Icons.close),
  ),
)
''';

      final violations = MinTouchTargetLint.scanSource(source, 'test.dart');
      expect(violations, isEmpty);
    });

    test('LintViolation toString includes file and line', () {
      const v = LintViolation(
        file: 'lib/foo.dart',
        line: 42,
        message: 'bad touch target',
      );
      expect(v.toString(), 'lib/foo.dart:42: bad touch target');
    });
  });
}
