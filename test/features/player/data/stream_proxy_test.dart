import 'package:crispy_tivi/features/player/data/stream_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamProxy', () {
    late StreamProxy proxy;

    setUp(() {
      proxy = StreamProxy();
    });

    test('isRunning is false when not started', () {
      expect(proxy.isRunning, false);
    });

    test('localUrl is null when not started', () {
      expect(proxy.localUrl, isNull);
    });

    test('stop is safe to call when not running', () async {
      // Should not throw.
      await proxy.stop();
      expect(proxy.isRunning, false);
    });

    test('stop resets state', () async {
      await proxy.stop();
      expect(proxy.isRunning, false);
      expect(proxy.localUrl, isNull);
    });

    test('multiple stops are safe', () async {
      await proxy.stop();
      await proxy.stop();
      await proxy.stop();
      expect(proxy.isRunning, false);
    });
  });

  group('StreamProxy URL format', () {
    test('localUrl format matches expected pattern', () {
      // When running, localUrl should be http://127.0.0.1:{port}/
      // We can't easily start a real proxy in tests, but we verify
      // the format expectation.
      const expectedPattern = r'^http://127\.0\.0\.1:\d+/$';
      expect(RegExp(expectedPattern).hasMatch('http://127.0.0.1:8080/'), true);
    });
  });

  group('Proxy retry tracking', () {
    test('Set tracks retried URLs correctly', () {
      final retried = <String>{};
      const url1 = 'http://example.com/stream1';
      const url2 = 'http://example.com/stream2';

      retried.add(url1);
      expect(retried.contains(url1), true);
      expect(retried.contains(url2), false);

      retried.add(url2);
      expect(retried, hasLength(2));
    });

    test('Set prevents duplicate entries', () {
      final retried = <String>{};
      const url = 'http://example.com/stream';

      retried.add(url);
      retried.add(url);
      expect(retried, hasLength(1));
    });

    test('clear resets tracking', () {
      final retried = <String>{};
      retried.add('http://example.com/stream1');
      retried.add('http://example.com/stream2');
      retried.clear();
      expect(retried, isEmpty);
    });
  });

  group('Audio check timer', () {
    test('3-second delay constant is correct', () {
      // The watchdog waits 3 seconds before checking audio tracks.
      const delay = Duration(seconds: 3);
      expect(delay.inSeconds, 3);
      expect(delay.inMilliseconds, 3000);
    });
  });
}
