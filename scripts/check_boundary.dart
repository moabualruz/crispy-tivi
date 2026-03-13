// ignore_for_file: avoid_print
import 'dart:io';

import 'package:crispy_tivi/core/lint/architecture_boundary_lint.dart';

/// CI boundary checker: scans all Dart files under `lib/features/` for
/// architecture boundary violations (forbidden imports in presentation/,
/// domain/, application/ layers).
///
/// Usage:
///   dart run scripts/check_boundary.dart          # check with allowlist
///   dart run scripts/check_boundary.dart --strict  # zero-tolerance mode
///
/// Exit codes:
///   0 - no new violations (beyond allowlisted baseline)
///   1 - new violations found
void main(List<String> args) {
  final strict = args.contains('--strict');
  final featuresDir = Directory('lib/features');

  if (!featuresDir.existsSync()) {
    print('ERROR: lib/features/ directory not found');
    exit(1);
  }

  final files =
      featuresDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

  var totalViolations = 0;
  var allowlistedCount = 0;
  final newViolations = <String>[];

  for (final file in files) {
    final violations = ArchitectureBoundaryLint.scanFile(file.path);
    for (final v in violations) {
      totalViolations++;
      final normalized = v.file.replaceAll(r'\', '/');
      final key = '$normalized:${v.line}';

      if (!strict && _allowlist.contains(normalized)) {
        allowlistedCount++;
      } else {
        newViolations.add('  $key: ${v.message}');
      }
    }
  }

  // Summary
  print('Architecture Boundary Check');
  print('===========================');
  print('Files scanned: ${files.length}');
  print('Total violations: $totalViolations');
  if (!strict) {
    print('Allowlisted (baseline): $allowlistedCount');
  }
  print('New violations: ${newViolations.length}');

  if (newViolations.isNotEmpty) {
    print('');
    print('NEW VIOLATIONS (must fix before merge):');
    for (final v in newViolations) {
      print(v);
    }
    exit(1);
  }

  if (strict && totalViolations > 0) {
    print('');
    print('STRICT MODE: $totalViolations violations remain.');
    exit(1);
  }

  print('');
  print('PASS: No new architecture boundary violations.');
  exit(0);
}

/// Known violations from the initial audit (2026-03-13).
///
/// These are pre-existing imports in presentation/, domain/, application/,
/// and utils/ layers that will be migrated incrementally. The allowlist
/// ensures CI catches NEW violations while tracking the migration backlog.
///
/// To shrink this list: fix a violation, remove it from here, commit.
/// CI will prevent re-introduction of any removed entry.
const _allowlist = <String>{
  // ── dart:convert in presentation/ ───────────────────────────
  'lib/features/dvr/presentation/screens/cloud_browser_screen.dart',
  'lib/features/dvr/presentation/widgets/recording_search_delegate.dart',
  'lib/features/dvr/presentation/widgets/storage_breakdown_sheet.dart',
  'lib/features/home/presentation/providers/home_providers.dart',
  'lib/features/iptv/presentation/providers/channel_providers.dart',
  'lib/features/iptv/presentation/providers/smart_group_providers.dart',
  'lib/features/iptv/presentation/widgets/sports_score_overlay.dart',
  'lib/features/player/presentation/providers/upscale_providers.dart',
  'lib/features/player/presentation/widgets/player_fullscreen_overlay.dart',
  'lib/features/player/presentation/widgets/player_osd/osd_bottom_bar.dart',
  'lib/features/profiles/presentation/providers/biometric_provider.dart',
  'lib/features/profiles/presentation/widgets/profile_management_widgets.dart',
  'lib/features/profiles/presentation/widgets/profile_viewing_stats_tile.dart',
  'lib/features/search/presentation/providers/search_providers.dart',
  'lib/features/settings/presentation/widgets/about_settings.dart',
  'lib/features/settings/presentation/widgets/backup_settings.dart',
  'lib/features/vod/presentation/providers/vod_derived_providers.dart',
  'lib/features/vod/presentation/widgets/series_episodes_tab.dart',

  // ── dart:io in presentation/ ────────────────────────────────
  'lib/features/multiview/presentation/screens/multi_view_screen.dart',
  'lib/features/player/presentation/screens/multi_view_screen.dart',
  // profile_management_widgets.dart already listed above (dart:convert + dart:io)
  'lib/features/settings/presentation/widgets/network_diagnostics_settings.dart',
  'lib/features/media_servers/shared/presentation/screens/media_server_login_screen.dart',

  // ── package:http in presentation/ ───────────────────────────
  // sports_score_overlay.dart already listed above (dart:convert + package:http)

  // ── dart:convert in domain/ ─────────────────────────────────
  'lib/features/dvr/domain/utils/dvr_payload.dart',
  'lib/features/player/domain/segment_skip_config.dart',
  'lib/features/vod/domain/utils/episode_utils.dart',

  // ── package:dio in presentation/ ───────────────────────────
  'lib/features/media_servers/emby/presentation/screens/emby_login_screen.dart',
  'lib/features/media_servers/jellyfin/presentation/screens/jellyfin_login_screen.dart',
  'lib/features/media_servers/jellyfin/presentation/screens/jellyfin_quick_connect_screen.dart',
  'lib/features/media_servers/plex/presentation/screens/plex_login_screen.dart',
  'lib/features/media_servers/shared/presentation/providers/public_users_provider.dart',

  // ── dart:io in domain/ ──────────────────────────────────────
  'lib/features/player/domain/entities/audio_output.dart',
  'lib/features/player/domain/entities/hardware_decoder.dart',

  // ── package:dio in domain/ ──────────────────────────────────
  'lib/features/media_servers/plex/domain/plex_source.dart',

  // ── dart:convert in application/ ────────────────────────────
  'lib/features/iptv/application/duplicate_detection_service.dart',
  'lib/features/iptv/application/media_server_sync.dart',
  'lib/features/iptv/application/playlist_epg_helper.dart',
  'lib/features/iptv/application/playlist_sync_helpers.dart',
  'lib/features/iptv/application/playlist_sync_service.dart',

  // ── dart:convert in utils/ ──────────────────────────────────
  'lib/features/media_servers/shared/utils/dio_error_utils.dart',
  'lib/features/media_servers/shared/utils/error_sanitizer.dart',
  'lib/features/media_servers/shared/utils/media_server_auth.dart',
};
