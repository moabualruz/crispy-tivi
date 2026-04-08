import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/casting/data/cast_service.dart';

void main() {
  group('CastState', () {
    test('default state has empty devices and '
        'not scanning', () {
      const state = CastState();
      expect(state.devices, isEmpty);
      expect(state.isScanning, isFalse);
      expect(state.timedOut, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.scanStartedAt, isNull);
      expect(state.connectedDevice, isNull);
      expect(state.currentMedia, isNull);
      expect(state.sessionState, CastSessionState.idle);
    });

    test('isConnected returns true for connected, '
        'playing, paused states', () {
      expect(
        const CastState(sessionState: CastSessionState.connected).isConnected,
        isTrue,
      );
      expect(
        const CastState(sessionState: CastSessionState.playing).isConnected,
        isTrue,
      );
      expect(
        const CastState(sessionState: CastSessionState.paused).isConnected,
        isTrue,
      );
    });

    test('isConnected returns false for idle and '
        'connecting states', () {
      expect(
        const CastState(sessionState: CastSessionState.idle).isConnected,
        isFalse,
      );
      expect(
        const CastState(sessionState: CastSessionState.connecting).isConnected,
        isFalse,
      );
    });

    test('copyWith preserves existing values', () {
      final now = DateTime.now();
      final original = CastState(
        devices: const [
          CastDevice(id: '1', name: 'TV', host: '192.168.1.1', port: 8009),
        ],
        isScanning: true,
        scanStartedAt: now,
        timedOut: false,
        errorMessage: null,
      );

      final copy = original.copyWith();
      expect(copy.devices.length, 1);
      expect(copy.isScanning, isTrue);
      expect(copy.scanStartedAt, now);
      expect(copy.timedOut, isFalse);
    });

    test('copyWith replaces specific fields', () {
      const original = CastState(isScanning: true, timedOut: false);

      final copy = original.copyWith(
        isScanning: false,
        timedOut: true,
        errorMessage: 'Network error',
      );

      expect(copy.isScanning, isFalse);
      expect(copy.timedOut, isTrue);
      expect(copy.errorMessage, 'Network error');
    });

    test('copyWith clearError removes error message', () {
      const original = CastState(errorMessage: 'Some error');

      final copy = original.copyWith(clearError: true);
      expect(copy.errorMessage, isNull);
    });

    test('copyWith clearDevice removes connected device', () {
      const device = CastDevice(
        id: '1',
        name: 'TV',
        host: '192.168.1.1',
        port: 8009,
      );
      const original = CastState(connectedDevice: device);

      final copy = original.copyWith(clearDevice: true);
      expect(copy.connectedDevice, isNull);
    });

    test('copyWith clearMedia removes current media', () {
      const media = CastMedia(
        streamUrl: 'http://example.com/stream.m3u8',
        title: 'Test Stream',
      );
      const original = CastState(currentMedia: media);

      final copy = original.copyWith(clearMedia: true);
      expect(copy.currentMedia, isNull);
    });

    test('copyWith scanStartedAt is set', () {
      final now = DateTime(2026, 2, 20);
      const original = CastState();
      final copy = original.copyWith(scanStartedAt: now);
      expect(copy.scanStartedAt, now);
    });

    test('copyWith timedOut flag', () {
      const original = CastState();
      final copy = original.copyWith(timedOut: true);
      expect(copy.timedOut, isTrue);
    });
  });

  group('CastDevice', () {
    test('creates with required fields', () {
      const device = CastDevice(
        id: '192.168.1.1:8009',
        name: 'Living Room TV',
        host: '192.168.1.1',
        port: 8009,
      );

      expect(device.id, '192.168.1.1:8009');
      expect(device.name, 'Living Room TV');
      expect(device.model, isNull);
      expect(device.host, '192.168.1.1');
      expect(device.port, 8009);
    });

    test('creates with optional model', () {
      const device = CastDevice(
        id: '1',
        name: 'TV',
        model: 'Chromecast Ultra',
        host: '192.168.1.1',
        port: 8009,
      );

      expect(device.model, 'Chromecast Ultra');
    });
  });

  group('CastMedia', () {
    test('creates with required fields', () {
      const media = CastMedia(
        streamUrl: 'http://example.com/stream.m3u8',
        title: 'Test Stream',
      );

      expect(media.streamUrl, 'http://example.com/stream.m3u8');
      expect(media.title, 'Test Stream');
      expect(media.thumbnailUrl, isNull);
    });

    test('creates with optional thumbnail', () {
      const media = CastMedia(
        streamUrl: 'http://example.com/stream.m3u8',
        title: 'Test Stream',
        thumbnailUrl: 'http://example.com/thumb.jpg',
      );

      expect(media.thumbnailUrl, 'http://example.com/thumb.jpg');
    });
  });

  group('CastService', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      // Stop discovery to clean up timers before
      // disposing.
      try {
        container.read(castServiceProvider.notifier).stopDiscovery();
      } catch (_) {
        // May already be disposed.
      }
      container.dispose();
    });

    test('initial state is default CastState', () {
      final state = container.read(castServiceProvider);
      expect(state.devices, isEmpty);
      expect(state.isScanning, isFalse);
      expect(state.timedOut, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('startDiscovery sets isScanning and '
        'scanStartedAt', () {
      container.read(castServiceProvider.notifier).startDiscovery();
      final state = container.read(castServiceProvider);
      expect(state.isScanning, isTrue);
      expect(state.scanStartedAt, isNotNull);

      // Clean up.
      container.read(castServiceProvider.notifier).stopDiscovery();
    });

    test('stopDiscovery sets isScanning to false', () {
      container.read(castServiceProvider.notifier).startDiscovery();
      container.read(castServiceProvider.notifier).stopDiscovery();
      final state = container.read(castServiceProvider);
      expect(state.isScanning, isFalse);
    });

    test('disconnect resets session state', () {
      container.read(castServiceProvider.notifier).disconnect();
      final state = container.read(castServiceProvider);
      expect(state.connectedDevice, isNull);
      expect(state.sessionState, CastSessionState.idle);
    });

    test('retryDiscovery stops then starts', () {
      container.read(castServiceProvider.notifier).startDiscovery();
      container.read(castServiceProvider.notifier).retryDiscovery();
      final state = container.read(castServiceProvider);
      // After retry, scanning is restarted.
      expect(state.isScanning, isTrue);

      // Clean up.
      container.read(castServiceProvider.notifier).stopDiscovery();
    });
  });

  group('CastSessionState', () {
    test('enum has expected values', () {
      expect(CastSessionState.values, hasLength(5));
      expect(
        CastSessionState.values,
        containsAll([
          CastSessionState.idle,
          CastSessionState.connecting,
          CastSessionState.connected,
          CastSessionState.playing,
          CastSessionState.paused,
        ]),
      );
    });
  });
}
