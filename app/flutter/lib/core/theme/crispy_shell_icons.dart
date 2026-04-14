import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:flutter/material.dart';

enum ShellIconRole { navigation, utility, panel, row, compact, badge, status }

final class CrispyShellIcons {
  const CrispyShellIcons._();

  static double size(ShellIconRole role) {
    return switch (role) {
      ShellIconRole.navigation => 22,
      ShellIconRole.utility => 22,
      ShellIconRole.panel => 22,
      ShellIconRole.row => 20,
      ShellIconRole.compact => 18,
      ShellIconRole.badge => 16,
      ShellIconRole.status => 18,
    };
  }

  static double plateExtent(ShellIconRole role) {
    return switch (role) {
      ShellIconRole.navigation => 38,
      ShellIconRole.utility => 40,
      ShellIconRole.panel => 46,
      ShellIconRole.row => 44,
      ShellIconRole.compact => 36,
      ShellIconRole.badge => 28,
      ShellIconRole.status => 36,
    };
  }

  static const double inlineGap = 12;
  static const double compactGap = 10;

  static IconData route(ShellRoute route) {
    return switch (route) {
      ShellRoute.home => Icons.home_rounded,
      ShellRoute.liveTv => Icons.live_tv_rounded,
      ShellRoute.media => Icons.ondemand_video_rounded,
      ShellRoute.search => Icons.search_rounded,
      ShellRoute.settings => Icons.settings_rounded,
    };
  }

  static String routeLabel(ShellRoute route) {
    return switch (route) {
      ShellRoute.liveTv => 'Live',
      _ => route.label,
    };
  }

  static IconData settingsPanel(SettingsPanel panel) {
    return switch (panel) {
      SettingsPanel.general => Icons.tune_outlined,
      SettingsPanel.playback => Icons.play_circle_outline_rounded,
      SettingsPanel.sources => Icons.hub_outlined,
      SettingsPanel.appearance => Icons.palette_outlined,
      SettingsPanel.system => Icons.developer_board_outlined,
    };
  }

  static IconData settingsRow(String title) {
    return switch (title) {
      'Startup target' => Icons.home_outlined,
      'Recommendations' => Icons.auto_awesome_outlined,
      'Quick play confirmation' => Icons.flash_on_outlined,
      'Preferred quality' => Icons.high_quality_outlined,
      'Focus intensity' => Icons.center_focus_weak_outlined,
      'Clock display' => Icons.schedule_outlined,
      'Storage' => Icons.storage_outlined,
      'About' => Icons.info_outline,
      _ => Icons.settings_outlined,
    };
  }

  static IconData settingsAction(String label) {
    return switch (label) {
      'Clear' => Icons.close_rounded,
      'Add source' => Icons.add_link_outlined,
      'Run import wizard' => Icons.playlist_add_outlined,
      'Reconnect source' => Icons.sync_outlined,
      'Continue' => Icons.arrow_forward_outlined,
      'Back' => Icons.chevron_left_rounded,
      _ => Icons.arrow_forward_outlined,
    };
  }

  static IconData settingsStatus(String status) {
    return switch (status) {
      'Healthy' => Icons.check_circle,
      'Degraded' => Icons.warning_amber_outlined,
      'Needs auth' => Icons.lock_outline,
      _ => Icons.info_outline,
    };
  }

  static IconData sidebarTitle(String title) {
    return switch (title) {
      'Live TV' => Icons.live_tv_outlined,
      'Media' => Icons.video_library_outlined,
      'Settings' => Icons.settings_rounded,
      _ => Icons.dashboard_outlined,
    };
  }

  static IconData sidebarItem(String title, String label) {
    return switch ('$title::$label') {
      'Live TV::Channels' => Icons.live_tv_rounded,
      'Live TV::Guide' => Icons.grid_view_rounded,
      'Media::Movies' => Icons.local_movies_rounded,
      'Media::Series' => Icons.tv_rounded,
      'Settings::General' => Icons.tune_rounded,
      'Settings::Playback' => Icons.play_circle_outline_rounded,
      'Settings::Sources' => Icons.hub_outlined,
      'Settings::Appearance' => Icons.palette_outlined,
      'Settings::System' => Icons.developer_board_outlined,
      _ => Icons.circle_outlined,
    };
  }

  static IconData searchGroup(String title) {
    return switch (title) {
      'Live TV' => Icons.live_tv_rounded,
      'Movies' => Icons.local_movies_rounded,
      'Series' => Icons.tv_rounded,
      _ => Icons.search_rounded,
    };
  }

  static IconData searchAction(String label) {
    return switch (label) {
      'Tune live channel' => Icons.play_circle_filled_outlined,
      'Open movie detail' => Icons.open_in_new_outlined,
      'Open series detail' => Icons.open_in_new_outlined,
      _ => Icons.open_in_new_outlined,
    };
  }

  static IconData playerBadge(String label) {
    final String value = label.toLowerCase();
    if (value.contains('news')) {
      return Icons.campaign_outlined;
    }
    if (value.contains('sports')) {
      return Icons.sports_soccer_outlined;
    }
    if (value.contains('movies')) {
      return Icons.local_movies_outlined;
    }
    if (value.contains('docs')) {
      return Icons.article_outlined;
    }
    if (value.contains('4k') ||
        value.contains('hd') ||
        value.contains('dolby')) {
      return Icons.high_quality_outlined;
    }
    if (value.contains('archive') || value.contains('catch-up')) {
      return Icons.history_outlined;
    }
    if (value.contains('start over')) {
      return Icons.restart_alt_outlined;
    }
    return Icons.label_outline;
  }

  static IconData playerChooser(PlayerChooserKind kind) {
    return switch (kind) {
      PlayerChooserKind.audio => Icons.audiotrack_outlined,
      PlayerChooserKind.subtitles => Icons.subtitles_outlined,
      PlayerChooserKind.quality => Icons.tune_outlined,
      PlayerChooserKind.source => Icons.swap_horiz_outlined,
    };
  }

  static IconData playerAction(String label) {
    final String value = label.toLowerCase();
    if (value == 'resume') {
      return Icons.play_arrow_rounded;
    }
    if (value == 'restart') {
      return Icons.replay_rounded;
    }
    if (value == 'go live') {
      return Icons.radio_button_checked_rounded;
    }
    if (value == 'next episode') {
      return Icons.skip_next_rounded;
    }
    if (value.contains('more info')) {
      return Icons.info_outline_rounded;
    }
    if (value.contains('audio')) {
      return Icons.audiotrack_outlined;
    }
    if (value.contains('subtitle')) {
      return Icons.subtitles_outlined;
    }
    if (value.contains('quality')) {
      return Icons.tune_outlined;
    }
    if (value.contains('source')) {
      return Icons.swap_horiz_outlined;
    }
    return Icons.arrow_forward_outlined;
  }

  static IconData back() => Icons.arrow_back_rounded;

  static IconData info() => Icons.info_outline_rounded;

  static IconData live() => Icons.live_tv_rounded;

  static IconData contentAction(String label) {
    final String value = label.toLowerCase();
    if (value.contains('resume') || value.contains('play')) {
      return Icons.play_arrow_rounded;
    }
    if (value.contains('restart') || value.contains('start over')) {
      return Icons.replay_rounded;
    }
    if (value.contains('detail') || value.contains('info')) {
      return Icons.info_outline_rounded;
    }
    if (value.contains('watchlist') || value.contains('add')) {
      return Icons.add_rounded;
    }
    if (value.contains('episode') || value.contains('season')) {
      return Icons.playlist_play_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  static IconData playerPrimary(PlayerContentKind kind) {
    return switch (kind) {
      PlayerContentKind.live => Icons.play_arrow_outlined,
      PlayerContentKind.movie => Icons.play_arrow_outlined,
      PlayerContentKind.episode => Icons.play_arrow_outlined,
    };
  }

  static IconData playerSecondary(PlayerContentKind kind) {
    return switch (kind) {
      PlayerContentKind.live => Icons.restart_alt_outlined,
      PlayerContentKind.movie => Icons.replay_outlined,
      PlayerContentKind.episode => Icons.skip_next_outlined,
    };
  }
}
