import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Captures a live HTTP stream (HLS / TS / MP4) to a local file.
///
/// Uses [Dio] for HTTP streaming with chunked transfer to disk.
/// On web, recording to disk is not supported — a no-op stub is used.
class RecordingEngine {
  RecordingEngine({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Active capture sessions: recordingId → cancel token.
  final Map<String, CancelToken> _activeSessions = {};

  /// Whether a recording is currently active.
  bool isCapturing(String recordingId) =>
      _activeSessions.containsKey(recordingId);

  /// Start capturing [streamUrl] to [outputPath].
  ///
  /// Returns a [Stream<int>] emitting cumulative bytes written.
  /// Stream completes when the recording ends (either naturally
  /// or via [stopCapture]).
  ///
  /// On web, this is a no-op that immediately completes with 0 bytes.
  Stream<int> startCapture({
    required String recordingId,
    required String streamUrl,
    required String outputPath,
  }) {
    if (kIsWeb) {
      // Web cannot write to disk — return stub stream.
      return Stream.value(0);
    }

    final controller = StreamController<int>();
    final cancelToken = CancelToken();
    _activeSessions[recordingId] = cancelToken;

    _captureStream(
          streamUrl: streamUrl,
          outputPath: outputPath,
          cancelToken: cancelToken,
          onProgress: (bytes) {
            if (!controller.isClosed) {
              controller.add(bytes);
            }
          },
        )
        .then((_) {
          _activeSessions.remove(recordingId);
          if (!controller.isClosed) controller.close();
        })
        .catchError((Object error) {
          _activeSessions.remove(recordingId);
          if (!controller.isClosed) {
            controller.addError(error);
            controller.close();
          }
        });

    return controller.stream;
  }

  /// Stop an active capture session.
  void stopCapture(String recordingId) {
    final token = _activeSessions.remove(recordingId);
    token?.cancel('Recording stopped by user');
  }

  /// Stop all active captures (e.g. on app shutdown).
  void stopAll() {
    for (final token in _activeSessions.values) {
      token.cancel('App shutting down');
    }
    _activeSessions.clear();
  }

  Future<void> _captureStream({
    required String streamUrl,
    required String outputPath,
    required CancelToken cancelToken,
    required void Function(int bytesWritten) onProgress,
  }) async {
    await _dio.download(
      streamUrl,
      outputPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, _) {
        onProgress(received);
      },
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(hours: 6),
      ),
    );
  }
}
