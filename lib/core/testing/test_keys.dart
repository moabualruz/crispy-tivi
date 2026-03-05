import 'package:flutter/foundation.dart';

/// Centralized registry of all test-facing widget keys.
///
/// Use [ValueKey] constants from this class to tag widgets in production code
/// and look them up in integration / e2e tests via `find.byKey(TestKeys.xxx)`.
///
/// **Rules:**
/// - Every screen scaffold gets a `*Screen` key.
/// - Structural sections, tabs, and list containers get descriptive keys.
/// - Interactive elements that need direct test access get named keys.
/// - Dynamic keys (items in lists, nav destinations) use factory methods.
/// - **Never** use inline `ValueKey('...')` strings in lib/ — always go
///   through this class so test code and production code stay in sync.
abstract final class TestKeys {
  // ──────────────────────────────────────────────────────────────
  // Screens
  // ──────────────────────────────────────────────────────────────

  static const homeScreen = ValueKey('home_screen');
  static const settingsScreen = ValueKey('settings_screen');
  static const dvrScreen = ValueKey('dvr_screen');
  static const cloudBrowserScreen = ValueKey('cloud_browser_screen');
  static const epgScreen = ValueKey('epg_screen');
  static const channelListScreen = ValueKey('channel_list_screen');
  static const vodBrowserScreen = ValueKey('vod_browser_screen');
  static const seriesBrowserScreen = ValueKey('series_browser_screen');
  static const vodDetailsScreen = ValueKey('vod_details_screen');
  static const seriesDetailScreen = ValueKey('series_detail_screen');
  static const profileSelectionScreen = ValueKey('profile_selection_screen');
  static const profileManagementScreen = ValueKey('profile_management_screen');
  static const searchScreen = ValueKey('search_screen');
  static const onboardingScreen = ValueKey('onboarding_screen');
  static const favoritesScreen = ValueKey('favorites_screen');
  static const playerScreen = ValueKey('player_screen');
  static const appShell = ValueKey('app_shell');
  static const multiViewScreen = ValueKey('multi_view_screen');
  static const profileWatchHistoryScreen = ValueKey(
    'profile_watch_history_screen',
  );
  static const notFoundScreen = ValueKey('not_found_screen');

  // Media server screens
  static const mediaServerLoginScreen = ValueKey('media_server_login_screen');
  static const mediaServerHomeScreen = ValueKey('media_server_home_screen');
  static const mediaServerBrowserScreen = ValueKey(
    'media_server_browser_screen',
  );
  static const mediaItemDetailsScreen = ValueKey('media_item_details_screen');
  static const paginatedLibraryScreen = ValueKey('paginated_library_screen');
  static const plexHomeScreen = ValueKey('plex_home_screen');
  static const plexUserSwitcherScreen = ValueKey('plex_user_switcher_screen');
  static const plexLoginScreen = ValueKey('plex_login_screen');
  static const embySeriesScreen = ValueKey('emby_series_screen');
  static const jellyfinSeriesScreen = ValueKey('jellyfin_series_screen');
  static const jellyfinQuickConnectScreen = ValueKey(
    'jellyfin_quick_connect_screen',
  );

  // ──────────────────────────────────────────────────────────────
  // Sections & structural containers
  // ──────────────────────────────────────────────────────────────

  static const heroBanner = ValueKey('hero_banner');
  static const sectionContinueWatching = ValueKey('section_continue_watching');
  static const sectionTop10 = ValueKey('section_top_10');
  static const sectionLatestVod = ValueKey('section_latest_vod');
  static const epgChannelList = ValueKey('epg_list');
  static const tabCloudStorage = ValueKey('tab_cloud_storage');
  static const tabLocalRecordings = ValueKey('tab_local_recordings');
  static const configS3Storage = ValueKey('config_s3_storage');
  static const configWebDavStorage = ValueKey('config_webdav_storage');
  static const epgNowLine = ValueKey('nowLine');

  // ──────────────────────────────────────────────────────────────
  // Named interactive widgets
  // ──────────────────────────────────────────────────────────────

  static const guestAvatar = ValueKey('guest_avatar');
  static const addProfileButton = ValueKey('add_profile_btn');
  static const playerGestureDetector = ValueKey('player_gesture_detector');
  static const homeFavoritesButton = ValueKey('home_favorites_btn');
  static const channelListFavoriteButton = ValueKey(
    'channel_list_favorite_btn',
  );
  static const navProfileSwitcherButton = ValueKey('nav_profile_switcher_btn');

  // Onboarding wizard
  static const onboardingStepIndicator = ValueKey('onboarding_step_indicator');

  // ──────────────────────────────────────────────────────────────
  // Dynamic keys — factory methods for data-driven suffixes
  // ──────────────────────────────────────────────────────────────

  /// Navigation rail/bar item key. [label] is the destination label
  /// (e.g. `'Live TV'`); lowercased to produce `'nav_item_live tv'`.
  static ValueKey<String> navItem(String label) =>
      ValueKey('nav_item_${label.toLowerCase()}');

  /// Channel list item by zero-based [index].
  static ValueKey<String> channelItem(int index) => ValueKey('channel_$index');

  /// VOD item by content [id].
  static ValueKey<String> vodItem(String id) => ValueKey('vod_item_$id');

  /// Profile tile by profile [id].
  static ValueKey<String> profileItem(String id) => ValueKey('profile_$id');

  /// OSD overflow menu item by [value].
  static ValueKey<String> osdOverflowItem(String value) =>
      ValueKey('osd_overflow_item_$value');

  /// Featured hero carousel item by content [id].
  static ValueKey<String> heroItem(String id) => ValueKey('hero_$id');

  /// Featured hero metadata overlay by content [id].
  static ValueKey<String> metaItem(String id) => ValueKey('meta_$id');

  /// Channel swipe-action dismissible by channel [id].
  static ValueKey<String> swipeChannel(String id) => ValueKey('swipe_$id');

  /// Onboarding source-type card by [type] (e.g. `'m3u'`, `'xtream'`).
  static ValueKey<String> onboardingSourceType(String type) =>
      ValueKey('onboarding_source_$type');
}
