import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crispy_tivi/core/data/ws_backend.dart';

void main() {
  group('WsBackend', () {
    test(
      'BUG-003: _onMessage silently discards binary frames (Uint8List) without crashing',
      () async {
        // Start a real minimal WebSocket server for testing locally
        final server = await HttpServer.bind('127.0.0.1', 0);
        late WebSocket serverSocket;

        final serverFuture = server.first.then((request) async {
          serverSocket = await WebSocketTransformer.upgrade(request);
        });

        final backend = WsBackend();
        // Wait for backend to connect to our dynamic port
        final wsUrl = 'http://127.0.0.1:${server.port}';
        backend.init(wsUrl);

        await serverFuture;

        // Listen for errors from the backend's event stream just in case
        bool gotError = false;
        backend.dataEvents.listen(
          (_) {},
          onError: (e) {
            gotError = true;
          },
        );

        // Send a binary frame from the server to the client (WsBackend)
        serverSocket.add(Uint8List.fromList([1, 2, 3, 4]));

        // Let the event loop process the message
        await Future.delayed(const Duration(milliseconds: 100));

        // The backend should ignore the binary frame, no crash or error
        expect(gotError, isFalse);

        await serverSocket.close();
        await server.close();
      },
    );
  });
}
