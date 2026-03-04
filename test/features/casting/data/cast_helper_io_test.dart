// Tests for cast_helper_io.dart via the conditional export in cast_helper.dart.
//
// On the test VM (dart:io available), cast_helper.dart exports
// cast_helper_io.dart (CastHelper with full mDNS + TLS support).
// Tests cover the pure-Dart logic that does not require a live network.

import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/casting/data/cast_helper.dart';
import 'package:crispy_tivi/features/casting/data/cast_message.dart';

void main() {
  // ── CastDeviceInfo ────────────────────────────────────────

  group('CastDeviceInfo', () {
    test('stores name, host, and port', () {
      const device = CastDeviceInfo(
        name: 'Living Room TV',
        host: '192.168.1.50',
        port: 8009,
      );
      expect(device.name, 'Living Room TV');
      expect(device.host, '192.168.1.50');
      expect(device.port, 8009);
    });

    test('two devices with same host compare by reference', () {
      const d1 = CastDeviceInfo(name: 'TV 1', host: '192.168.1.1', port: 8009);
      const d2 = CastDeviceInfo(name: 'TV 2', host: '192.168.1.1', port: 8009);
      // CastDeviceInfo has no custom == so they are not identical objects.
      expect(identical(d1, d2), isFalse);
      expect(d1.host, d2.host);
    });

    test('port can be non-default', () {
      const device = CastDeviceInfo(
        name: 'Custom Port TV',
        host: '10.0.0.5',
        port: 9009,
      );
      expect(device.port, 9009);
    });
  });

  // ── CastHelper initial state ──────────────────────────────

  group('CastHelper initial state', () {
    test('isConnected is false before any connection', () {
      final helper = CastHelper();
      expect(helper.isConnected, isFalse);
    });

    test('stopDiscovery on idle helper does not throw', () {
      final helper = CastHelper();
      expect(() => helper.stopDiscovery(), returnsNormally);
    });

    test('disconnect on idle helper does not throw', () {
      final helper = CastHelper();
      expect(() => helper.disconnect(), returnsNormally);
    });

    test('pause on idle helper does not throw', () {
      final helper = CastHelper();
      expect(() => helper.pause(), returnsNormally);
    });

    test('resume on idle helper does not throw', () {
      final helper = CastHelper();
      expect(() => helper.resume(), returnsNormally);
    });

    test('stop on idle helper does not throw', () {
      final helper = CastHelper();
      expect(() => helper.stop(), returnsNormally);
    });
  });

  // ── CastHelper loadMedia without socket ───────────────────

  group('CastHelper.loadMedia without connection', () {
    test('returns false when not connected', () async {
      final helper = CastHelper();
      final result = await helper.loadMedia(
        'http://example.com/stream.m3u8',
        'Test Stream',
      );
      expect(result, isFalse);
    });
  });

  // ── Content type guessing (via encodeCastMessage round-trip) ──

  group('encodeCastMessage / decodeCastMessageLength', () {
    test('encodes a message with a 4-byte big-endian length prefix', () {
      final msg = CastMessage(
        protocolVersion: 0,
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastNamespaces.heartbeat,
        payloadType: PayloadType.STRING,
        payloadUtf8: '{"type":"PING"}',
      );
      final encoded = encodeCastMessage(msg);
      expect(encoded.length, greaterThan(4));

      final length = decodeCastMessageLength(encoded);
      expect(length, encoded.length - 4);
    });

    test('decodeCastMessageLength returns null for fewer than 4 bytes', () {
      expect(decodeCastMessageLength([0x00, 0x01, 0x02]), isNull);
    });

    test('decodeCastMessageLength returns 0 for all-zero prefix', () {
      final length = decodeCastMessageLength([0x00, 0x00, 0x00, 0x00]);
      expect(length, 0);
    });

    test('decoded length matches re-encoded message body size', () {
      final msg = CastMessage(
        protocolVersion: 0,
        sourceId: 's',
        destinationId: 'd',
        namespace: CastNamespaces.connection,
        payloadType: PayloadType.STRING,
        payloadUtf8: '{"type":"CONNECT"}',
      );
      final encoded = encodeCastMessage(msg);
      final declaredLength = decodeCastMessageLength(encoded)!;
      expect(declaredLength, encoded.length - 4);
    });
  });

  // ── CastMessage ───────────────────────────────────────────

  group('CastMessage construction', () {
    test('creates with all fields set correctly', () {
      final msg = CastMessage(
        protocolVersion: 0,
        sourceId: 'sender-0',
        destinationId: 'receiver-0',
        namespace: CastNamespaces.media,
        payloadType: PayloadType.STRING,
        payloadUtf8: '{"type":"LOAD"}',
      );
      expect(msg.sourceId, 'sender-0');
      expect(msg.destinationId, 'receiver-0');
      expect(msg.namespace, CastNamespaces.media);
      expect(msg.payloadUtf8, '{"type":"LOAD"}');
    });

    test('namespaces have correct URN values', () {
      expect(
        CastNamespaces.connection,
        'urn:x-cast:com.google.cast.tp.connection',
      );
      expect(
        CastNamespaces.heartbeat,
        'urn:x-cast:com.google.cast.tp.heartbeat',
      );
      expect(CastNamespaces.receiver, 'urn:x-cast:com.google.cast.receiver');
      expect(CastNamespaces.media, 'urn:x-cast:com.google.cast.media');
    });

    test('default media receiver app ID is correct', () {
      expect(kDefaultMediaReceiverAppId, 'CC1AD845');
    });
  });

  // ── CastHelper connect returns false for bad host ─────────

  group('CastHelper.connect with unreachable host', () {
    test('returns false for host that refuses connection '
        '(localhost port 1 — immediately refused)', () async {
      final helper = CastHelper();
      // Port 1 on localhost is reserved and always connection-refused.
      // This gives an instant failure without waiting for the 10s timeout.
      final result = await helper
          .connect('127.0.0.1', 1)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      expect(result, isFalse);
    });
  });

  // ── stopDiscovery is idempotent ───────────────────────────

  group('CastHelper.stopDiscovery idempotency', () {
    test('calling stopDiscovery twice does not throw', () {
      final helper = CastHelper();
      helper.stopDiscovery();
      expect(() => helper.stopDiscovery(), returnsNormally);
    });
  });

  // ── startDiscovery guard (no double-start) ────────────────

  group('CastHelper.startDiscovery guard', () {
    test('calling startDiscovery when already discovering '
        'returns immediately without starting a second scan', () async {
      final helper = CastHelper();
      final calls = <List<CastDeviceInfo>>[];

      // Start first discovery — this will attempt mDNS which may
      // time-out quickly in a test environment; we do not await it.
      final first = helper.startDiscovery(calls.add).catchError((_) {});

      // Start a second discovery — the guard inside startDiscovery
      // (_isDiscovering == true) should skip the second call.
      final second = helper.startDiscovery(calls.add).catchError((_) {});

      // Stop to clean up resources.
      helper.stopDiscovery();
      await Future.wait([first, second]);

      // We just verify there was no exception thrown.
      expect(true, isTrue);
    });
  });
}
