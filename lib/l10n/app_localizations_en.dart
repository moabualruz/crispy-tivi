// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAll => 'All';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonNone => 'None';

  @override
  String commonError(String message) {
    return 'Error: $message';
  }

  @override
  String get commonOr => 'or';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonDone => 'Done';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonGoToSettings => 'Go to Settings';

  @override
  String get commonNew => 'NEW';

  @override
  String get commonLive => 'LIVE';

  @override
  String get commonFavorites => 'Favorites';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navLiveTv => 'Live TV';

  @override
  String get navGuide => 'Guide';

  @override
  String get navMovies => 'Movies';

  @override
  String get navSeries => 'Series';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navSettings => 'Settings';

  @override
  String get breadcrumbProfiles => 'Profiles';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'Cloud';

  @override
  String get breadcrumbMultiView => 'Multi-View';

  @override
  String get breadcrumbDetail => 'Detail';

  @override
  String get breadcrumbNavigateToParent => 'Navigate to parent';

  @override
  String get sideNavSwitchProfile => 'Switch Profile';

  @override
  String get sideNavManageProfiles => 'Manage profiles';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Switch profile: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'Enter PIN for $name';
  }

  @override
  String get sideNavActive => 'active';

  @override
  String get sideNavPinProtected => 'PIN protected';

  @override
  String get fabWhatsOn => 'What\'s On';

  @override
  String get fabRandomPick => 'Random Pick';

  @override
  String get fabLastChannel => 'Last Channel';

  @override
  String get fabSchedule => 'Schedule';

  @override
  String get fabNewList => 'New List';

  @override
  String get offlineNoConnection => 'No connection';

  @override
  String get offlineConnectionRestored => 'Connection restored';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get pinConfirmPin => 'Confirm PIN';

  @override
  String get pinEnterAllDigits => 'Enter all 4 digits';

  @override
  String get pinDoNotMatch => 'PINs do not match';

  @override
  String get pinTooManyAttempts => 'Too many incorrect attempts.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Try again in $countdown';
  }

  @override
  String get pinEnterSameAgain => 'Enter the same PIN again to confirm';

  @override
  String get pinUseBiometric => 'Use fingerprint or face';

  @override
  String pinDigitN(int n) {
    return 'PIN digit $n';
  }

  @override
  String get pinIncorrect => 'Incorrect PIN';

  @override
  String get pinVerificationFailed => 'Verification failed';

  @override
  String get pinBiometricFailed =>
      'Biometric authentication failed or canceled';

  @override
  String get contextMenuRemoveFromFavorites => 'Remove from Favorites';

  @override
  String get contextMenuAddToFavorites => 'Add to Favorites';

  @override
  String get contextMenuSwitchStreamSource => 'Switch stream source';

  @override
  String get contextMenuSmartGroup => 'Smart Group';

  @override
  String get contextMenuMultiView => 'Multi-View';

  @override
  String get contextMenuAssignEpg => 'Assign EPG';

  @override
  String get contextMenuHideChannel => 'Hide channel';

  @override
  String get contextMenuCopyStreamUrl => 'Copy Stream URL';

  @override
  String get contextMenuPlayExternal => 'Play in External Player';

  @override
  String get contextMenuBlockChannel => 'Block channel';

  @override
  String get contextMenuViewDetails => 'View details';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Remove from Favorite Categories';

  @override
  String get contextMenuAddToFavoriteCategories => 'Add to Favorite Categories';

  @override
  String get contextMenuFilterByCategory => 'Filter by this category';

  @override
  String get contextMenuCloseContextMenu => 'Close context menu';

  @override
  String get sourceAllSources => 'All Sources';

  @override
  String sourceFilterLabel(String label) {
    return '$label source filter';
  }

  @override
  String get categoryLabel => 'Category';

  @override
  String categoryAll(String label) {
    return 'All $label';
  }

  @override
  String categorySelect(String label) {
    return 'Select $label';
  }

  @override
  String get categorySearchHint => 'Search categories…';

  @override
  String get categorySearchLabel => 'Search categories';

  @override
  String get categoryRemoveFromFavorites => 'Remove from favorite categories';

  @override
  String get categoryAddToFavorites => 'Add to favorite categories';

  @override
  String get sidebarExpandSidebar => 'Expand sidebar';

  @override
  String get sidebarCollapseSidebar => 'Collapse sidebar';

  @override
  String get badgeNewEpisode => 'NEW EP';

  @override
  String get badgeNewSeason => 'NEW SEASON';

  @override
  String get badgeRecording => 'REC';

  @override
  String get badgeExpiring => 'EXPIRES';

  @override
  String get toggleFavorite => 'Toggle favorite';

  @override
  String get playerSkipBack => 'Skip back 10 seconds';

  @override
  String get playerSkipForward => 'Skip forward 10 seconds';

  @override
  String get playerChannels => 'Channels';

  @override
  String get playerRecordings => 'Recordings';

  @override
  String get playerCloseGuide => 'Close Guide (G)';

  @override
  String get playerTvGuide => 'TV Guide (G)';

  @override
  String get playerAudioSubtitles => 'Audio & Subtitles';

  @override
  String get playerNoTracksAvailable => 'No tracks available';

  @override
  String get playerExitFullscreen => 'Exit Fullscreen';

  @override
  String get playerFullscreen => 'Fullscreen';

  @override
  String get playerUnlockScreen => 'Unlock Screen';

  @override
  String get playerLockScreen => 'Lock Screen';

  @override
  String get playerStreamQuality => 'Stream Quality';

  @override
  String get playerRotationLock => 'Rotation Lock';

  @override
  String get playerScreenBrightness => 'Screen Brightness';

  @override
  String get playerShaderPreset => 'Shader Preset';

  @override
  String get playerAutoSystem => 'Auto (System)';

  @override
  String get playerResetToAuto => 'Reset to Auto';

  @override
  String get playerPortrait => 'Portrait';

  @override
  String get playerPortraitUpsideDown => 'Portrait (upside down)';

  @override
  String get playerLandscapeLeft => 'Landscape left';

  @override
  String get playerLandscapeRight => 'Landscape right';

  @override
  String get playerDeinterlaceAuto => 'Auto';

  @override
  String get playerMoreOptions => 'More options';

  @override
  String get playerRemoveFavorite => 'Remove Favorite';

  @override
  String get playerAddFavorite => 'Add Favorite';

  @override
  String get playerAudioTrack => 'Audio Track';

  @override
  String playerAspectRatio(String label) {
    return 'Aspect Ratio ($label)';
  }

  @override
  String get playerRefreshStream => 'Refresh Stream';

  @override
  String get playerStreamInfo => 'Stream Info';

  @override
  String get playerPip => 'Picture-in-Picture';

  @override
  String get playerSleepTimer => 'Sleep Timer';

  @override
  String get playerExternalPlayer => 'External Player';

  @override
  String get playerSearchChannels => 'Search Channels';

  @override
  String get playerChannelList => 'Channel List';

  @override
  String get playerScreenshot => 'Screenshot';

  @override
  String playerStreamQualityOption(String label) {
    return 'Stream Quality ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Deinterlace ($mode)';
  }

  @override
  String get playerSyncOffset => 'Sync Offset';

  @override
  String playerAudioPassthrough(String state) {
    return 'Audio Passthrough ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Audio Output Device';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Always on Top ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Shaders ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'AUDIO';

  @override
  String get playerSubtitlesSectionSubtitles => 'SUBTITLES';

  @override
  String get playerSubtitlesSecondHint => '(long-press = 2nd)';

  @override
  String get playerSubtitlesCcStyle => 'CC Style';

  @override
  String get playerSyncOffsetAudio => 'Audio';

  @override
  String get playerSyncOffsetSubtitle => 'Subtitle';

  @override
  String get playerSyncOffsetResetToZero => 'Reset to 0';

  @override
  String get playerNoAudioDevices => 'No audio devices found.';

  @override
  String get playerSpeedLive => 'Speed (live)';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerVolumeLabel => 'Volume';

  @override
  String playerVolumePercent(int percent) {
    return 'Volume $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Switch profile ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '$duration left';
  }

  @override
  String get playerSubtitleFontWeight => 'FONT WEIGHT';

  @override
  String get playerSubtitleBold => 'Bold';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'FONT SIZE';

  @override
  String playerSubtitlePosition(int value) {
    return 'POSITION ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'TEXT COLOR';

  @override
  String get playerSubtitleOutlineColor => 'OUTLINE COLOR';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'OUTLINE SIZE ($value)';
  }

  @override
  String get playerSubtitleBackground => 'BACKGROUND';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'BG OPACITY ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'SHADOW';

  @override
  String get playerSubtitlePreview => 'PREVIEW';

  @override
  String get playerSubtitleSampleText => 'Sample subtitle text';

  @override
  String get playerSubtitleResetDefaults => 'Reset to defaults';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Stopping in $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Cancel Timer';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Set sleep timer to $minutes minutes';
  }

  @override
  String get playerStreamStats => 'Stream Stats';

  @override
  String get playerStreamStatsBuffer => 'Buffer';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Copied!';

  @override
  String get playerStreamStatsCopy => 'Copy stats';

  @override
  String get playerStreamStatsInterlaced => 'Interlaced';

  @override
  String playerNextUpIn(int seconds) {
    return 'Up Next in $seconds';
  }

  @override
  String get playerPlayNow => 'Play Now';

  @override
  String get playerFinished => 'Finished';

  @override
  String get playerWatchAgain => 'Watch Again';

  @override
  String get playerBrowseMore => 'Browse More';

  @override
  String get playerShortcutsTitle => 'Keyboard Shortcuts';

  @override
  String get playerShortcutsCloseEsc => 'Close (Esc)';

  @override
  String get playerShortcutsPlayback => 'Playback';

  @override
  String get playerShortcutsPlayPause => 'Play / Pause';

  @override
  String get playerShortcutsSeek => 'Seek ±10 s';

  @override
  String get playerShortcutsSpeedStep => 'Speed −/+ step';

  @override
  String get playerShortcutsSpeedFine => 'Speed −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => 'Jump to % (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Frame step ±1';

  @override
  String get playerShortcutsAspectRatio => 'Cycle aspect ratio';

  @override
  String get playerShortcutsCycleSubtitles => 'Cycle subtitles';

  @override
  String get playerShortcutsVolume => 'Volume';

  @override
  String get playerShortcutsVolumeAdjust => 'Volume ±10 %';

  @override
  String get playerShortcutsMute => 'Mute / unmute';

  @override
  String get playerShortcutsDisplay => 'Display';

  @override
  String get playerShortcutsFullscreenToggle => 'Fullscreen toggle';

  @override
  String get playerShortcutsExitFullscreen => 'Exit fullscreen / back';

  @override
  String get playerShortcutsStreamInfo => 'Stream info';

  @override
  String get playerShortcutsLiveTv => 'Live TV';

  @override
  String get playerShortcutsChannelUp => 'Channel up';

  @override
  String get playerShortcutsChannelDown => 'Channel down';

  @override
  String get playerShortcutsChannelList => 'Channel list';

  @override
  String get playerShortcutsToggleZap => 'Toggle zap overlay';

  @override
  String get playerShortcutsGeneral => 'General';

  @override
  String get playerShortcutsSubtitlesCc => 'Subtitles / CC';

  @override
  String get playerShortcutsScreenLock => 'Screen lock';

  @override
  String get playerShortcutsThisHelp => 'This help screen';

  @override
  String get playerShortcutsEscToClose => 'Press Esc or ? to close';

  @override
  String get playerZapChannels => 'Channels';

  @override
  String get playerBookmark => 'Bookmark';

  @override
  String get playerEditBookmark => 'Edit Bookmark';

  @override
  String get playerBookmarkLabelHint => 'Bookmark label (optional)';

  @override
  String get playerBookmarkLabelInput => 'Bookmark label';

  @override
  String playerBookmarkAdded(String label) {
    return 'Bookmark added at $label';
  }

  @override
  String get playerExpandToFullscreen => 'Expand to fullscreen';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerStopPlayback => 'Stop playback';

  @override
  String get playerQueueUpNext => 'Up Next';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Season $number Episodes';
  }

  @override
  String get playerQueueEpisodes => 'Episodes';

  @override
  String get playerQueueEmpty => 'Queue is empty';

  @override
  String get playerQueueClose => 'Close Queue';

  @override
  String get playerQueueOpen => 'Queue';

  @override
  String playerEpisodeNumber(String number) {
    return 'Episode $number';
  }

  @override
  String get playerScreenLocked => 'Screen locked';

  @override
  String get playerHoldToUnlock => 'Hold to unlock';

  @override
  String get playerScreenshotSaved => 'Screenshot saved';

  @override
  String get playerScreenshotFailed => 'Screenshot failed';

  @override
  String get playerSkipSegment => 'Skip segment';

  @override
  String playerSkipType(String type) {
    return 'Skip $type';
  }

  @override
  String get playerCouldNotOpenExternal => 'Could not open external player';

  @override
  String get playerExitMultiView => 'Exit Multi-View';

  @override
  String get playerScreensaverBouncingLogo => 'Bouncing Logo';

  @override
  String get playerScreensaverClock => 'Clock';

  @override
  String get playerScreensaverBlackScreen => 'Black Screen';

  @override
  String get streamProfileAuto => 'Auto';

  @override
  String get streamProfileAutoDesc =>
      'Automatically adjust quality based on network';

  @override
  String get streamProfileLow => 'Low';

  @override
  String get streamProfileLowDesc => 'SD quality, ~1 Mbps max';

  @override
  String get streamProfileMedium => 'Medium';

  @override
  String get streamProfileMediumDesc => 'HD quality, ~3 Mbps max';

  @override
  String get streamProfileHigh => 'High';

  @override
  String get streamProfileHighDesc => 'Full HD quality, ~8 Mbps max';

  @override
  String get streamProfileMaximum => 'Maximum';

  @override
  String get streamProfileMaximumDesc => 'Best available quality, no limit';

  @override
  String get segmentIntro => 'Intro';

  @override
  String get segmentOutro => 'Outro / Credits';

  @override
  String get segmentRecap => 'Recap';

  @override
  String get segmentCommercial => 'Commercial';

  @override
  String get segmentPreview => 'Preview';

  @override
  String get segmentSkipNone => 'None';

  @override
  String get segmentSkipAsk => 'Ask to Skip';

  @override
  String get segmentSkipOnce => 'Skip Once';

  @override
  String get segmentSkipAlways => 'Always Skip';

  @override
  String get nextUpOff => 'Off';

  @override
  String get nextUpStatic => 'Static (32s before end)';

  @override
  String get nextUpSmart => 'Smart (credits-aware)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSearchSettings => 'Search settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSources => 'Sources';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System Default';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutUpdates => 'Updates';

  @override
  String get settingsAboutCheckForUpdates => 'Check for Updates';

  @override
  String get settingsAboutUpToDate => 'You are up to date';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Update available: $version';
  }

  @override
  String get settingsAboutLicenses => 'Licenses';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsAccentColor => 'Accent Color';

  @override
  String get settingsTextScale => 'Text Scale';

  @override
  String get settingsDensity => 'Density';

  @override
  String get settingsBackup => 'Backup & Restore';

  @override
  String get settingsBackupCreate => 'Create Backup';

  @override
  String get settingsBackupRestore => 'Restore Backup';

  @override
  String get settingsBackupAuto => 'Auto Backup';

  @override
  String get settingsBackupCloudSync => 'Cloud Sync';

  @override
  String get settingsParentalControls => 'Parental Controls';

  @override
  String get settingsParentalSetPin => 'Set PIN';

  @override
  String get settingsParentalChangePin => 'Change PIN';

  @override
  String get settingsParentalRemovePin => 'Remove PIN';

  @override
  String get settingsParentalBlockedCategories => 'Blocked Categories';

  @override
  String get settingsNetwork => 'Network';

  @override
  String get settingsNetworkDiagnostics => 'Network Diagnostics';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Hardware Decoder';

  @override
  String get settingsPlaybackBufferSize => 'Buffer Size';

  @override
  String get settingsPlaybackDeinterlace => 'Deinterlace';

  @override
  String get settingsPlaybackUpscaling => 'Upscaling';

  @override
  String get settingsPlaybackAudioOutput => 'Audio Output';

  @override
  String get settingsPlaybackLoudnessNorm => 'Loudness Normalization';

  @override
  String get settingsPlaybackVolumeBoost => 'Volume Boost';

  @override
  String get settingsPlaybackAudioPassthrough => 'Audio Passthrough';

  @override
  String get settingsPlaybackSegmentSkip => 'Segment Skip';

  @override
  String get settingsPlaybackNextUp => 'Next Up';

  @override
  String get settingsPlaybackScreensaver => 'Screensaver';

  @override
  String get settingsPlaybackExternalPlayer => 'External Player';

  @override
  String get settingsSourceAdd => 'Add Source';

  @override
  String get settingsSourceEdit => 'Edit Source';

  @override
  String get settingsSourceDelete => 'Delete Source';

  @override
  String get settingsSourceSync => 'Sync Now';

  @override
  String get settingsSourceSortOrder => 'Sort Order';

  @override
  String get settingsDataClearCache => 'Clear Cache';

  @override
  String get settingsDataClearHistory => 'Clear Watch History';

  @override
  String get settingsDataExport => 'Export Data';

  @override
  String get settingsDataImport => 'Import Data';

  @override
  String get settingsAdvancedDebug => 'Debug Mode';

  @override
  String get settingsAdvancedStreamProxy => 'Stream Proxy';

  @override
  String get settingsAdvancedAutoUpdate => 'Auto Update';

  @override
  String get iptvMultiView => 'Multi-View';

  @override
  String get iptvTvGuide => 'TV Guide';

  @override
  String get iptvBackToGroups => 'Back to groups';

  @override
  String get iptvSearchChannels => 'Search channels';

  @override
  String get iptvListGridView => 'List View';

  @override
  String get iptvGridView => 'Grid View';

  @override
  String iptvChannelHidden(String name) {
    return '$name hidden';
  }

  @override
  String get iptvSortDone => 'Done';

  @override
  String get iptvSortResetToDefault => 'Reset to Default';

  @override
  String get iptvSortByPlaylistOrder => 'By Playlist Order';

  @override
  String get iptvSortByName => 'By Name';

  @override
  String get iptvSortByRecent => 'By Recent';

  @override
  String get iptvSortByPopularity => 'By Popularity';

  @override
  String get epgNowPlaying => 'Now';

  @override
  String get epgNoData => 'No EPG data available';

  @override
  String get epgSetReminder => 'Set Reminder';

  @override
  String get epgCancelReminder => 'Cancel Reminder';

  @override
  String get epgRecord => 'Record';

  @override
  String get epgCancelRecording => 'Cancel Recording';

  @override
  String get vodMovies => 'Movies';

  @override
  String get vodSeries => 'Series';

  @override
  String vodSeasonN(int number) {
    return 'Season $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Episode $number';
  }

  @override
  String get vodWatchNow => 'Watch Now';

  @override
  String get vodResume => 'Resume';

  @override
  String get vodContinueWatching => 'Continue Watching';

  @override
  String get vodRecommended => 'Recommended';

  @override
  String get vodRecentlyAdded => 'Recently Added';

  @override
  String get vodNoItems => 'No items found';

  @override
  String get dvrSchedule => 'Schedule';

  @override
  String get dvrRecordings => 'Recordings';

  @override
  String get dvrScheduleRecording => 'Schedule Recording';

  @override
  String get dvrEditRecording => 'Edit Recording';

  @override
  String get dvrDeleteRecording => 'Delete Recording';

  @override
  String get dvrNoRecordings => 'No recordings';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search channels, movies, series…';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchFilterChannels => 'Channels';

  @override
  String get searchFilterMovies => 'Movies';

  @override
  String get searchFilterSeries => 'Series';

  @override
  String get homeWhatsOn => 'What\'s On Now';

  @override
  String get homeContinueWatching => 'Continue Watching';

  @override
  String get homeRecentChannels => 'Recent Channels';

  @override
  String get homeMyList => 'My List';

  @override
  String get homeQuickAccess => 'Quick Access';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get favoritesAddSome =>
      'Add channels, movies, or series to your favorites';

  @override
  String get profilesTitle => 'Profiles';

  @override
  String get profilesCreate => 'Create Profile';

  @override
  String get profilesEdit => 'Edit Profile';

  @override
  String get profilesDelete => 'Delete Profile';

  @override
  String get profilesManage => 'Manage Profiles';

  @override
  String get profilesWhoIsWatching => 'Who\'s Watching?';

  @override
  String get onboardingWelcome => 'Welcome to CrispyTivi';

  @override
  String get onboardingAddSource => 'Add Your First Source';

  @override
  String get onboardingChooseType => 'Choose Source Type';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Connecting and loading channels…';

  @override
  String get onboardingDone => 'All Set!';

  @override
  String get onboardingStartWatching => 'Start Watching';

  @override
  String get cloudSyncTitle => 'Cloud Sync';

  @override
  String get cloudSyncSignInGoogle => 'Sign in with Google';

  @override
  String get cloudSyncSignOut => 'Sign Out';

  @override
  String cloudSyncLastSync(String time) {
    return 'Last sync: $time';
  }

  @override
  String get cloudSyncNever => 'Never';

  @override
  String get cloudSyncConflict => 'Sync Conflict';

  @override
  String get cloudSyncKeepLocal => 'Keep Local';

  @override
  String get cloudSyncKeepRemote => 'Keep Remote';

  @override
  String get castTitle => 'Cast';

  @override
  String get castSearching => 'Searching for devices…';

  @override
  String get castNoDevices => 'No devices found';

  @override
  String get castDisconnect => 'Disconnect';

  @override
  String get multiviewTitle => 'Multi-View';

  @override
  String get multiviewAddStream => 'Add Stream';

  @override
  String get multiviewRemoveStream => 'Remove Stream';

  @override
  String get multiviewSaveLayout => 'Save Layout';

  @override
  String get multiviewLoadLayout => 'Load Layout';

  @override
  String get multiviewLayoutName => 'Layout name';

  @override
  String get multiviewDeleteLayout => 'Delete Layout';

  @override
  String get mediaServerUrl => 'Server URL';

  @override
  String get mediaServerUsername => 'Username';

  @override
  String get mediaServerPassword => 'Password';

  @override
  String get mediaServerSignIn => 'Sign In';

  @override
  String get mediaServerConnecting => 'Connecting…';

  @override
  String get mediaServerConnectionFailed => 'Connection failed';

  @override
  String onboardingChannelsLoaded(int count) {
    return '$count channels loaded!';
  }

  @override
  String get onboardingEnterApp => 'Enter App';

  @override
  String get onboardingEnterAppLabel => 'Enter the app';

  @override
  String get onboardingCouldNotConnect => 'Could not connect';

  @override
  String get onboardingRetryLabel => 'Retry connection';

  @override
  String get onboardingEditSource => 'Edit source details';

  @override
  String get playerAudioSectionLabel => 'AUDIO';

  @override
  String get playerSubtitlesSectionLabel => 'SUBTITLES';

  @override
  String get playerSwitchProfileTitle => 'Switch Profile';

  @override
  String get playerCopyStreamUrl => 'Copy Stream URL';

  @override
  String get cloudSyncSyncing => 'Syncing…';

  @override
  String get cloudSyncNow => 'Sync Now';

  @override
  String get cloudSyncForceUpload => 'Force Upload';

  @override
  String get cloudSyncForceDownload => 'Force Download';

  @override
  String get cloudSyncAutoSync => 'Auto-sync';

  @override
  String get cloudSyncThisDevice => 'This Device';

  @override
  String get cloudSyncCloud => 'Cloud';

  @override
  String get cloudSyncNewer => 'NEWER';

  @override
  String get contextMenuAddFavorite => 'Add to Favorites';

  @override
  String get contextMenuRemoveFavorite => 'Remove from Favorites';

  @override
  String get contextMenuSwitchStream => 'Switch stream source';

  @override
  String get contextMenuCopyUrl => 'Copy Stream URL';

  @override
  String get contextMenuOpenExternal => 'Play in External Player';

  @override
  String get contextMenuPlay => 'Play';

  @override
  String get contextMenuAddFavoriteCategory => 'Add to Favorite Categories';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Remove from Favorite Categories';

  @override
  String get contextMenuFilterCategory => 'Filter by this category';

  @override
  String get confirmDeleteCancel => 'Cancel';

  @override
  String get confirmDeleteAction => 'Delete';
}
