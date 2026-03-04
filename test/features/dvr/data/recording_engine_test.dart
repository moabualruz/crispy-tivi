import 'dart:async';

import 'package:crispy_tivi/features/dvr/data/'
    'recording_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late RecordingEngine engine;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    engine = RecordingEngine(dio: mockDio);
  });

  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(Options(responseType: ResponseType.stream));
  });

  group('RecordingEngine', () {
    group('isCapturing', () {
      test('returns false for unknown recordingId', () {
        expect(engine.isCapturing('unknown'), isFalse);
      });

      test('returns true after startCapture is called', () {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => Completer<Response>().future);

        engine.startCapture(
          recordingId: 'rec-1',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        expect(engine.isCapturing('rec-1'), isTrue);
      });

      test('returns false after stopCapture is called', () {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => Completer<Response>().future);

        engine.startCapture(
          recordingId: 'rec-1',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        engine.stopCapture('rec-1');
        expect(engine.isCapturing('rec-1'), isFalse);
      });

      test('returns false after recording completes '
          'naturally', () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

        final stream = engine.startCapture(
          recordingId: 'rec-2',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        // Wait for stream to complete.
        await stream.toList();

        expect(engine.isCapturing('rec-2'), isFalse);
      });
    });

    group('startCapture', () {
      test('calls Dio.download with correct URL and path', () {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => Completer<Response>().future);

        engine.startCapture(
          recordingId: 'rec-1',
          streamUrl: 'http://example.com/stream.ts',
          outputPath: '/tmp/recording.ts',
        );

        verify(
          () => mockDio.download(
            'http://example.com/stream.ts',
            '/tmp/recording.ts',
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).called(1);
      });

      test('emits progress via onReceiveProgress', () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final onProgress =
              invocation.namedArguments[const Symbol('onReceiveProgress')]
                  as void Function(int, int);
          onProgress(100, -1);
          onProgress(200, -1);
          onProgress(300, -1);
          return Response(requestOptions: RequestOptions());
        });

        final stream = engine.startCapture(
          recordingId: 'rec-progress',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        final events = await stream.toList();
        expect(events, [100, 200, 300]);
      });

      test('stream closes when download completes', () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

        final stream = engine.startCapture(
          recordingId: 'rec-done',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        // Should complete without hanging.
        await expectLater(stream, emitsDone);
      });

      test('stream emits error on download failure', () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(),
            message: 'Network error',
          ),
        );

        final stream = engine.startCapture(
          recordingId: 'rec-err',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        await expectLater(stream, emitsError(isA<DioException>()));
      });

      test('removes session on error', () async {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenThrow(DioException(requestOptions: RequestOptions()));

        final stream = engine.startCapture(
          recordingId: 'rec-err-remove',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        // Drain to trigger the error path.
        await stream.drain<void>().catchError((_) {});

        expect(engine.isCapturing('rec-err-remove'), isFalse);
      });
    });

    group('stopCapture', () {
      test('does nothing for unknown recordingId', () {
        // Should not throw.
        engine.stopCapture('nonexistent');
      });

      test('cancels the CancelToken for active session', () {
        CancelToken? capturedToken;

        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) {
          capturedToken =
              invocation.namedArguments[const Symbol('cancelToken')]
                  as CancelToken;
          return Completer<Response>().future;
        });

        engine.startCapture(
          recordingId: 'rec-cancel',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        engine.stopCapture('rec-cancel');

        expect(capturedToken, isNotNull);
        expect(capturedToken!.isCancelled, isTrue);
      });

      test('removes session from active sessions', () {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => Completer<Response>().future);

        engine.startCapture(
          recordingId: 'rec-stop',
          streamUrl: 'http://example.com/stream',
          outputPath: '/tmp/out.ts',
        );

        expect(engine.isCapturing('rec-stop'), isTrue);
        engine.stopCapture('rec-stop');
        expect(engine.isCapturing('rec-stop'), isFalse);
      });
    });

    group('stopAll', () {
      test('stops all active sessions', () {
        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((_) => Completer<Response>().future);

        engine.startCapture(
          recordingId: 'rec-a',
          streamUrl: 'http://example.com/a',
          outputPath: '/tmp/a.ts',
        );
        engine.startCapture(
          recordingId: 'rec-b',
          streamUrl: 'http://example.com/b',
          outputPath: '/tmp/b.ts',
        );

        expect(engine.isCapturing('rec-a'), isTrue);
        expect(engine.isCapturing('rec-b'), isTrue);

        engine.stopAll();

        expect(engine.isCapturing('rec-a'), isFalse);
        expect(engine.isCapturing('rec-b'), isFalse);
      });

      test('cancels all tokens when stopping all', () {
        final tokens = <CancelToken>[];

        when(
          () => mockDio.download(
            any(),
            any(),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) {
          final token =
              invocation.namedArguments[const Symbol('cancelToken')]
                  as CancelToken;
          tokens.add(token);
          return Completer<Response>().future;
        });

        engine.startCapture(
          recordingId: 'rec-x',
          streamUrl: 'http://example.com/x',
          outputPath: '/tmp/x.ts',
        );
        engine.startCapture(
          recordingId: 'rec-y',
          streamUrl: 'http://example.com/y',
          outputPath: '/tmp/y.ts',
        );

        engine.stopAll();

        expect(tokens.length, 2);
        for (final token in tokens) {
          expect(token.isCancelled, isTrue);
        }
      });

      test('is safe to call with no active sessions', () {
        // Should not throw.
        engine.stopAll();
      });
    });
  });
}
