import 'dart:convert';

import 'package:crispy_tivi/core/domain/entities/xtream_account_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XtreamAccountInfo', () {
    test('fromJson parses full response', () {
      final json = {
        'username': 'testuser',
        'message': 'Welcome',
        'auth': 1,
        'status': 'Active',
        'exp_date': '1735689600',
        'is_trial': '0',
        'active_cons': '1',
        'created_at': '1609459200',
        'max_connections': '2',
        'allowed_output_formats': ['m3u8', 'ts', 'rtmp'],
        'server_url': 'server.example.com',
        'server_port': '80',
        'server_https_port': '443',
        'server_protocol': 'http',
        'server_rtmp_port': '8088',
        'server_timezone': 'Europe/London',
        'server_timestamp_now': 1711000000,
        'server_time_now': '2024-03-21 12:00:00',
      };

      final info = XtreamAccountInfo.fromJson(json);

      expect(info.username, 'testuser');
      expect(info.message, 'Welcome');
      expect(info.auth, 1);
      expect(info.status, 'Active');
      expect(info.expDate, '1735689600');
      expect(info.isTrial, '0');
      expect(info.activeCons, '1');
      expect(info.createdAt, '1609459200');
      expect(info.maxConnections, '2');
      expect(info.allowedOutputFormats, ['m3u8', 'ts', 'rtmp']);
      expect(info.serverUrl, 'server.example.com');
      expect(info.serverPort, '80');
      expect(info.serverHttpsPort, '443');
      expect(info.serverProtocol, 'http');
      expect(info.serverRtmpPort, '8088');
      expect(info.serverTimezone, 'Europe/London');
      expect(info.serverTimestampNow, 1711000000);
      expect(info.serverTimeNow, '2024-03-21 12:00:00');
    });

    test('fromJson handles minimal response', () {
      final json = <String, dynamic>{'auth': 1};

      final info = XtreamAccountInfo.fromJson(json);

      expect(info.auth, 1);
      expect(info.username, isNull);
      expect(info.status, isNull);
      expect(info.expDate, isNull);
      expect(info.serverUrl, isNull);
      expect(info.allowedOutputFormats, isEmpty);
    });

    test('fromJson defaults auth to 0 when missing', () {
      final info = XtreamAccountInfo.fromJson(<String, dynamic>{});

      expect(info.auth, 0);
    });

    test('isAuthenticated returns true when auth == 1', () {
      const info = XtreamAccountInfo(auth: 1);
      expect(info.isAuthenticated, isTrue);
    });

    test('isAuthenticated returns false when auth == 0', () {
      const info = XtreamAccountInfo();
      expect(info.isAuthenticated, isFalse);
    });

    test('isTrialAccount returns true for "1"', () {
      const info = XtreamAccountInfo(isTrial: '1');
      expect(info.isTrialAccount, isTrue);
    });

    test('isTrialAccount returns false for "0"', () {
      const info = XtreamAccountInfo(isTrial: '0');
      expect(info.isTrialAccount, isFalse);
    });

    test('isActive returns true for "Active"', () {
      const info = XtreamAccountInfo(status: 'Active');
      expect(info.isActive, isTrue);
    });

    test('isActive is case-insensitive', () {
      const info = XtreamAccountInfo(status: 'active');
      expect(info.isActive, isTrue);
    });

    test('isActive returns false for non-active statuses', () {
      const info = XtreamAccountInfo(status: 'Expired');
      expect(info.isActive, isFalse);
    });

    test('expirationDate parses Unix timestamp', () {
      const info = XtreamAccountInfo(expDate: '1735689600');

      final dt = info.expirationDate;

      expect(dt, isNotNull);
      expect(dt!.year, 2025);
      expect(dt.isUtc, isTrue);
    });

    test('expirationDate returns null for missing expDate', () {
      const info = XtreamAccountInfo();
      expect(info.expirationDate, isNull);
    });

    test('expirationDate returns null for unparseable expDate', () {
      const info = XtreamAccountInfo(expDate: 'not-a-number');
      expect(info.expirationDate, isNull);
    });

    test('maxConnectionsInt parses string to int', () {
      const info = XtreamAccountInfo(maxConnections: '2');
      expect(info.maxConnectionsInt, 2);
    });

    test('maxConnectionsInt returns null when absent', () {
      const info = XtreamAccountInfo();
      expect(info.maxConnectionsInt, isNull);
    });

    test('activeConsInt parses string to int', () {
      const info = XtreamAccountInfo(activeCons: '3');
      expect(info.activeConsInt, 3);
    });

    test('toJson roundtrips through fromJson', () {
      const original = XtreamAccountInfo(
        username: 'user',
        auth: 1,
        status: 'Active',
        expDate: '1735689600',
        maxConnections: '2',
        allowedOutputFormats: ['m3u8', 'ts'],
        serverUrl: 'server.example.com',
        serverTimezone: 'Europe/London',
        serverTimestampNow: 1711000000,
      );

      final json = original.toJson();
      final restored = XtreamAccountInfo.fromJson(json);

      expect(restored.username, original.username);
      expect(restored.auth, original.auth);
      expect(restored.status, original.status);
      expect(restored.expDate, original.expDate);
      expect(restored.maxConnections, original.maxConnections);
      expect(restored.allowedOutputFormats, original.allowedOutputFormats);
      expect(restored.serverUrl, original.serverUrl);
      expect(restored.serverTimezone, original.serverTimezone);
      expect(restored.serverTimestampNow, original.serverTimestampNow);
    });

    test('toJson produces valid JSON string', () {
      const info = XtreamAccountInfo(auth: 1, status: 'Active');

      final jsonStr = jsonEncode(info.toJson());
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['auth'], 1);
      expect(decoded['status'], 'Active');
    });

    test('equality compares key fields', () {
      const a = XtreamAccountInfo(
        username: 'user',
        auth: 1,
        status: 'Active',
        expDate: '123',
        maxConnections: '2',
      );
      const b = XtreamAccountInfo(
        username: 'user',
        auth: 1,
        status: 'Active',
        expDate: '123',
        maxConnections: '2',
        serverUrl: 'different.com',
      );

      expect(a, equals(b));
    });

    test('toString includes key fields', () {
      const info = XtreamAccountInfo(
        username: 'testuser',
        status: 'Active',
        auth: 1,
        expDate: '123',
      );

      final str = info.toString();

      expect(str, contains('testuser'));
      expect(str, contains('Active'));
    });

    test('default constructor has sensible defaults', () {
      const info = XtreamAccountInfo();

      expect(info.auth, 0);
      expect(info.username, isNull);
      expect(info.status, isNull);
      expect(info.expDate, isNull);
      expect(info.allowedOutputFormats, isEmpty);
      expect(info.isAuthenticated, isFalse);
      expect(info.isActive, isFalse);
    });
  });
}
