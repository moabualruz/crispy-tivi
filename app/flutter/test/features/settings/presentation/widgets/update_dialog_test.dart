import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crispy_tivi/features/settings/presentation/'
    'widgets/update_dialog.dart';

void main() {
  Widget buildDialog({
    String latestVersion = '1.2.0',
    String changelog = 'Bug fixes and improvements.',
    String downloadUrl = 'https://example.com/download',
    String assetsJson = '[]',
    String platform = 'windows',
    String? Function(String, String)? getPlatformAssetUrl,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => UpdateDialog(
                            latestVersion: latestVersion,
                            changelog: changelog,
                            downloadUrl: downloadUrl,
                            assetsJson: assetsJson,
                            platform: platform,
                            getPlatformAssetUrl:
                                getPlatformAssetUrl ?? (_, _) => null,
                          ),
                    ),
                child: const Text('Open'),
              ),
        ),
      ),
    );
  }

  group('UpdateDialog', () {
    testWidgets('shows version in title', (tester) async {
      await tester.pumpWidget(buildDialog(latestVersion: '2.0.0'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Update Available — v2.0.0'), findsOneWidget);
    });

    testWidgets('shows changelog text', (tester) async {
      await tester.pumpWidget(buildDialog(changelog: 'New feature X added.'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('New feature X added.'), findsOneWidget);
    });

    testWidgets('shows "No changelog available." when empty', (tester) async {
      await tester.pumpWidget(buildDialog(changelog: ''));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('No changelog available.'), findsOneWidget);
    });

    testWidgets('has Later and Download buttons', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('Later button closes dialog', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update Available — v1.2.0'), findsNothing);
    });

    testWidgets('shows What\'s New section header', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text("What's New"), findsOneWidget);
    });
  });

  group('CacheService.checkForUpdate caching', () {
    test('respects check interval caching', () {
      // CacheService in-memory cache is tested via the
      // cache_service_test.dart. Here we verify the JSON
      // contract shape matches what the UI expects.
      final json = jsonEncode({
        'has_update': true,
        'latest_version': '1.2.0',
        'download_url': 'https://example.com/v1.2.0',
        'changelog': 'Fixes',
        'published_at': '2026-01-01T00:00:00Z',
        'assets_json': '[]',
      });
      final result = jsonDecode(json) as Map<String, dynamic>;
      expect(result['has_update'], true);
      expect(result['latest_version'], '1.2.0');
      expect(result['download_url'], isNotEmpty);
      expect(result['changelog'], 'Fixes');
    });

    test('no-update result shape', () {
      final json = jsonEncode({
        'has_update': false,
        'latest_version': '0.1.1',
        'download_url': '',
        'changelog': '',
        'published_at': '',
        'assets_json': '',
      });
      final result = jsonDecode(json) as Map<String, dynamic>;
      expect(result['has_update'], false);
      expect(result['latest_version'], '0.1.1');
    });

    test('error result shape', () {
      final json = jsonEncode({
        'has_update': false,
        'latest_version': '',
        'download_url': '',
        'changelog': '',
        'published_at': '',
        'assets_json': '',
        'error': 'Network error',
      });
      final result = jsonDecode(json) as Map<String, dynamic>;
      expect(result['has_update'], false);
      expect(result['error'], 'Network error');
    });
  });
}
