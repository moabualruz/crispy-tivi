// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRetry => 'Wiederholen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonSubmit => 'Absenden';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonOn => 'Ein';

  @override
  String get commonOff => 'Aus';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonNone => 'Keine';

  @override
  String commonError(String message) {
    return 'Fehler: $message';
  }

  @override
  String get commonOr => 'oder';

  @override
  String get commonRefresh => 'Aktualisieren';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonPlay => 'Abspielen';

  @override
  String get commonPause => 'Pausieren';

  @override
  String get commonLoading => 'Laden...';

  @override
  String get commonGoToSettings => 'Zu den Einstellungen';

  @override
  String get commonNew => 'NEU';

  @override
  String get commonLive => 'LIVE';

  @override
  String get commonFavorites => 'Favoriten';

  @override
  String get navHome => 'Startseite';

  @override
  String get navSearch => 'Suchen';

  @override
  String get navLiveTv => 'Live-TV';

  @override
  String get navGuide => 'Programmführer';

  @override
  String get navMovies => 'Filme';

  @override
  String get navSeries => 'Serien';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favoriten';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get breadcrumbProfiles => 'Profile';

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
  String get breadcrumbDetail => 'Details';

  @override
  String get breadcrumbNavigateToParent => 'Zur übergeordneten Seite';

  @override
  String get sideNavSwitchProfile => 'Profil wechseln';

  @override
  String get sideNavManageProfiles => 'Profile verwalten';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Profil wechseln: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'PIN für $name eingeben';
  }

  @override
  String get sideNavActive => 'aktiv';

  @override
  String get sideNavPinProtected => 'PIN-geschützt';

  @override
  String get fabWhatsOn => 'Aktuelles Programm';

  @override
  String get fabRandomPick => 'Zufällige Auswahl';

  @override
  String get fabLastChannel => 'Letzter Kanal';

  @override
  String get fabSchedule => 'Zeitplan';

  @override
  String get fabNewList => 'Neue Liste';

  @override
  String get offlineNoConnection => 'Keine Verbindung';

  @override
  String get offlineConnectionRestored => 'Verbindung wiederhergestellt';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Seite nicht gefunden';

  @override
  String get pinConfirmPin => 'PIN bestätigen';

  @override
  String get pinEnterAllDigits => 'Alle 4 Ziffern eingeben';

  @override
  String get pinDoNotMatch => 'PINs stimmen nicht überein';

  @override
  String get pinTooManyAttempts => 'Zu viele falsche Versuche.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Erneut versuchen in $countdown';
  }

  @override
  String get pinEnterSameAgain => 'Gleiche PIN erneut eingeben zur Bestätigung';

  @override
  String get pinUseBiometric => 'Fingerabdruck oder Gesicht verwenden';

  @override
  String pinDigitN(int n) {
    return 'PIN-Ziffer $n';
  }

  @override
  String get pinIncorrect => 'Falsche PIN';

  @override
  String get pinVerificationFailed => 'Überprüfung fehlgeschlagen';

  @override
  String get pinBiometricFailed =>
      'Biometrische Authentifizierung fehlgeschlagen oder abgebrochen';

  @override
  String get contextMenuRemoveFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get contextMenuAddToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get contextMenuSwitchStreamSource => 'Streamquelle wechseln';

  @override
  String get contextMenuSmartGroup => 'Intelligente Gruppe';

  @override
  String get contextMenuMultiView => 'Multi-View';

  @override
  String get contextMenuAssignEpg => 'EPG zuweisen';

  @override
  String get contextMenuHideChannel => 'Kanal ausblenden';

  @override
  String get contextMenuCopyStreamUrl => 'Stream-URL kopieren';

  @override
  String get contextMenuPlayExternal => 'In externem Player abspielen';

  @override
  String get contextMenuBlockChannel => 'Kanal sperren';

  @override
  String get contextMenuViewDetails => 'Details anzeigen';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Aus Lieblingskategorien entfernen';

  @override
  String get contextMenuAddToFavoriteCategories =>
      'Zu Lieblingskategorien hinzufügen';

  @override
  String get contextMenuFilterByCategory => 'Nach dieser Kategorie filtern';

  @override
  String get contextMenuCloseContextMenu => 'Kontextmenü schließen';

  @override
  String get sourceAllSources => 'Alle Quellen';

  @override
  String sourceFilterLabel(String label) {
    return '$label Quellenfilter';
  }

  @override
  String get categoryLabel => 'Kategorie';

  @override
  String categoryAll(String label) {
    return 'Alle $label';
  }

  @override
  String categorySelect(String label) {
    return '$label auswählen';
  }

  @override
  String get categorySearchHint => 'Kategorien suchen…';

  @override
  String get categorySearchLabel => 'Kategorien suchen';

  @override
  String get categoryRemoveFromFavorites => 'Aus Lieblingskategorien entfernen';

  @override
  String get categoryAddToFavorites => 'Zu Lieblingskategorien hinzufügen';

  @override
  String get sidebarExpandSidebar => 'Seitenleiste erweitern';

  @override
  String get sidebarCollapseSidebar => 'Seitenleiste einklappen';

  @override
  String get badgeNewEpisode => 'NEUE FOLGE';

  @override
  String get badgeNewSeason => 'NEUE STAFFEL';

  @override
  String get badgeRecording => 'REC';

  @override
  String get badgeExpiring => 'LÄUFT AB';

  @override
  String get toggleFavorite => 'Favorit umschalten';

  @override
  String get playerSkipBack => '10 Sekunden zurückspulen';

  @override
  String get playerSkipForward => '10 Sekunden vorspulen';

  @override
  String get playerChannels => 'Kanäle';

  @override
  String get playerRecordings => 'Aufnahmen';

  @override
  String get playerCloseGuide => 'Programmführer schließen (G)';

  @override
  String get playerTvGuide => 'TV-Programmführer (G)';

  @override
  String get playerAudioSubtitles => 'Audio & Untertitel';

  @override
  String get playerNoTracksAvailable => 'Keine Spuren verfügbar';

  @override
  String get playerExitFullscreen => 'Vollbild beenden';

  @override
  String get playerFullscreen => 'Vollbild';

  @override
  String get playerUnlockScreen => 'Bildschirm entsperren';

  @override
  String get playerLockScreen => 'Bildschirm sperren';

  @override
  String get playerStreamQuality => 'Streamqualität';

  @override
  String get playerRotationLock => 'Rotationssperre';

  @override
  String get playerScreenBrightness => 'Bildschirmhelligkeit';

  @override
  String get playerShaderPreset => 'Shader-Voreinstellung';

  @override
  String get playerAutoSystem => 'Auto (System)';

  @override
  String get playerResetToAuto => 'Auf Auto zurücksetzen';

  @override
  String get playerPortrait => 'Hochformat';

  @override
  String get playerPortraitUpsideDown => 'Hochformat (umgedreht)';

  @override
  String get playerLandscapeLeft => 'Querformat links';

  @override
  String get playerLandscapeRight => 'Querformat rechts';

  @override
  String get playerDeinterlaceAuto => 'Auto';

  @override
  String get playerMoreOptions => 'Weitere Optionen';

  @override
  String get playerRemoveFavorite => 'Favorit entfernen';

  @override
  String get playerAddFavorite => 'Favorit hinzufügen';

  @override
  String get playerAudioTrack => 'Audiospur';

  @override
  String playerAspectRatio(String label) {
    return 'Seitenverhältnis ($label)';
  }

  @override
  String get playerRefreshStream => 'Stream aktualisieren';

  @override
  String get playerStreamInfo => 'Streaminfo';

  @override
  String get playerPip => 'Bild-in-Bild';

  @override
  String get playerSleepTimer => 'Schlaf-Timer';

  @override
  String get playerExternalPlayer => 'Externer Player';

  @override
  String get playerSearchChannels => 'Kanäle suchen';

  @override
  String get playerChannelList => 'Kanalliste';

  @override
  String get playerScreenshot => 'Screenshot';

  @override
  String playerStreamQualityOption(String label) {
    return 'Streamqualität ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Deinterlacing ($mode)';
  }

  @override
  String get playerSyncOffset => 'Synchronisationsversatz';

  @override
  String playerAudioPassthrough(String state) {
    return 'Audio-Passthrough ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Audioausgabegerät';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Immer im Vordergrund ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Shader ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'AUDIO';

  @override
  String get playerSubtitlesSectionSubtitles => 'UNTERTITEL';

  @override
  String get playerSubtitlesSecondHint => '(Gedrückt halten = 2.)';

  @override
  String get playerSubtitlesCcStyle => 'CC-Stil';

  @override
  String get playerSyncOffsetAudio => 'Audio';

  @override
  String get playerSyncOffsetSubtitle => 'Untertitel';

  @override
  String get playerSyncOffsetResetToZero => 'Auf 0 zurücksetzen';

  @override
  String get playerNoAudioDevices => 'Keine Audiogeräte gefunden.';

  @override
  String get playerSpeedLive => 'Geschwindigkeit (live)';

  @override
  String get playerSpeed => 'Geschwindigkeit';

  @override
  String get playerVolumeLabel => 'Lautstärke';

  @override
  String playerVolumePercent(int percent) {
    return 'Lautstärke $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Profil wechseln ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return 'Noch $duration';
  }

  @override
  String get playerSubtitleFontWeight => 'SCHRIFTSTÄRKE';

  @override
  String get playerSubtitleBold => 'Fett';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'SCHRIFTGRÖSSE';

  @override
  String playerSubtitlePosition(int value) {
    return 'POSITION ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'TEXTFARBE';

  @override
  String get playerSubtitleOutlineColor => 'UMRISSFARBE';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'UMRISSGRÖSSE ($value)';
  }

  @override
  String get playerSubtitleBackground => 'HINTERGRUND';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'HINTERGRUNDDECKKRAFT ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'SCHATTEN';

  @override
  String get playerSubtitlePreview => 'VORSCHAU';

  @override
  String get playerSubtitleSampleText => 'Beispiel-Untertiteltext';

  @override
  String get playerSubtitleResetDefaults => 'Standardwerte wiederherstellen';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Stoppt in $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Timer abbrechen';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes Minuten';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Schlaf-Timer auf $minutes Minuten einstellen';
  }

  @override
  String get playerStreamStats => 'Stream-Statistiken';

  @override
  String get playerStreamStatsBuffer => 'Puffer';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Kopiert!';

  @override
  String get playerStreamStatsCopy => 'Statistiken kopieren';

  @override
  String get playerStreamStatsInterlaced => 'Zeilensprungverfahren';

  @override
  String playerNextUpIn(int seconds) {
    return 'Als nächstes in $seconds';
  }

  @override
  String get playerPlayNow => 'Jetzt abspielen';

  @override
  String get playerFinished => 'Beendet';

  @override
  String get playerWatchAgain => 'Nochmals ansehen';

  @override
  String get playerBrowseMore => 'Mehr entdecken';

  @override
  String get playerShortcutsTitle => 'Tastaturkürzel';

  @override
  String get playerShortcutsCloseEsc => 'Schließen (Esc)';

  @override
  String get playerShortcutsPlayback => 'Wiedergabe';

  @override
  String get playerShortcutsPlayPause => 'Abspielen / Pause';

  @override
  String get playerShortcutsSeek => 'Springen ±10 s';

  @override
  String get playerShortcutsSpeedStep => 'Geschwindigkeit −/+ Schritt';

  @override
  String get playerShortcutsSpeedFine => 'Geschwindigkeit −/+ 0,1x';

  @override
  String get playerShortcutsJumpPercent => 'Zu % springen (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Bild-Schritt ±1';

  @override
  String get playerShortcutsAspectRatio => 'Seitenverhältnis wechseln';

  @override
  String get playerShortcutsCycleSubtitles => 'Untertitel wechseln';

  @override
  String get playerShortcutsVolume => 'Lautstärke';

  @override
  String get playerShortcutsVolumeAdjust => 'Lautstärke ±10 %';

  @override
  String get playerShortcutsMute => 'Stumm schalten / aufheben';

  @override
  String get playerShortcutsDisplay => 'Anzeige';

  @override
  String get playerShortcutsFullscreenToggle => 'Vollbild umschalten';

  @override
  String get playerShortcutsExitFullscreen => 'Vollbild beenden / zurück';

  @override
  String get playerShortcutsStreamInfo => 'Streaminfo';

  @override
  String get playerShortcutsLiveTv => 'Live-TV';

  @override
  String get playerShortcutsChannelUp => 'Kanal rauf';

  @override
  String get playerShortcutsChannelDown => 'Kanal runter';

  @override
  String get playerShortcutsChannelList => 'Kanalliste';

  @override
  String get playerShortcutsToggleZap => 'Zap-Overlay umschalten';

  @override
  String get playerShortcutsGeneral => 'Allgemein';

  @override
  String get playerShortcutsSubtitlesCc => 'Untertitel / CC';

  @override
  String get playerShortcutsScreenLock => 'Bildschirmsperre';

  @override
  String get playerShortcutsThisHelp => 'Diese Hilfeseite';

  @override
  String get playerShortcutsEscToClose => 'Esc oder ? zum Schließen drücken';

  @override
  String get playerZapChannels => 'Kanäle';

  @override
  String get playerBookmark => 'Lesezeichen';

  @override
  String get playerEditBookmark => 'Lesezeichen bearbeiten';

  @override
  String get playerBookmarkLabelHint => 'Lesezeichen-Bezeichnung (optional)';

  @override
  String get playerBookmarkLabelInput => 'Lesezeichen-Bezeichnung';

  @override
  String playerBookmarkAdded(String label) {
    return 'Lesezeichen hinzugefügt bei $label';
  }

  @override
  String get playerExpandToFullscreen => 'Im Vollbild öffnen';

  @override
  String get playerUnmute => 'Stummschaltung aufheben';

  @override
  String get playerMute => 'Stumm schalten';

  @override
  String get playerStopPlayback => 'Wiedergabe stoppen';

  @override
  String get playerQueueUpNext => 'Als nächstes';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Staffel $number – Folgen';
  }

  @override
  String get playerQueueEpisodes => 'Folgen';

  @override
  String get playerQueueEmpty => 'Warteschlange ist leer';

  @override
  String get playerQueueClose => 'Warteschlange schließen';

  @override
  String get playerQueueOpen => 'Warteschlange';

  @override
  String playerEpisodeNumber(String number) {
    return 'Folge $number';
  }

  @override
  String get playerScreenLocked => 'Bildschirm gesperrt';

  @override
  String get playerHoldToUnlock => 'Gedrückt halten zum Entsperren';

  @override
  String get playerScreenshotSaved => 'Screenshot gespeichert';

  @override
  String get playerScreenshotFailed => 'Screenshot fehlgeschlagen';

  @override
  String get playerSkipSegment => 'Segment überspringen';

  @override
  String playerSkipType(String type) {
    return '$type überspringen';
  }

  @override
  String get playerCouldNotOpenExternal =>
      'Externer Player konnte nicht geöffnet werden';

  @override
  String get playerExitMultiView => 'Multi-View beenden';

  @override
  String get playerScreensaverBouncingLogo => 'Springendes Logo';

  @override
  String get playerScreensaverClock => 'Uhr';

  @override
  String get playerScreensaverBlackScreen => 'Schwarzer Bildschirm';

  @override
  String get streamProfileAuto => 'Auto';

  @override
  String get streamProfileAutoDesc =>
      'Qualität automatisch an das Netzwerk anpassen';

  @override
  String get streamProfileLow => 'Niedrig';

  @override
  String get streamProfileLowDesc => 'SD-Qualität, max. ~1 Mbit/s';

  @override
  String get streamProfileMedium => 'Mittel';

  @override
  String get streamProfileMediumDesc => 'HD-Qualität, max. ~3 Mbit/s';

  @override
  String get streamProfileHigh => 'Hoch';

  @override
  String get streamProfileHighDesc => 'Full-HD-Qualität, max. ~8 Mbit/s';

  @override
  String get streamProfileMaximum => 'Maximum';

  @override
  String get streamProfileMaximumDesc =>
      'Beste verfügbare Qualität, kein Limit';

  @override
  String get segmentIntro => 'Intro';

  @override
  String get segmentOutro => 'Outro / Abspann';

  @override
  String get segmentRecap => 'Rückblick';

  @override
  String get segmentCommercial => 'Werbung';

  @override
  String get segmentPreview => 'Vorschau';

  @override
  String get segmentSkipNone => 'Keine';

  @override
  String get segmentSkipAsk => 'Zum Überspringen fragen';

  @override
  String get segmentSkipOnce => 'Einmal überspringen';

  @override
  String get segmentSkipAlways => 'Immer überspringen';

  @override
  String get nextUpOff => 'Aus';

  @override
  String get nextUpStatic => 'Statisch (32 s vor Ende)';

  @override
  String get nextUpSmart => 'Intelligent (abspannbewusst)';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSearchSettings => 'Einstellungen durchsuchen';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get settingsSources => 'Quellen';

  @override
  String get settingsPlayback => 'Wiedergabe';

  @override
  String get settingsData => 'Daten';

  @override
  String get settingsAdvanced => 'Erweitert';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutUpdates => 'Updates';

  @override
  String get settingsAboutCheckForUpdates => 'Nach Updates suchen';

  @override
  String get settingsAboutUpToDate => 'Sie sind auf dem neuesten Stand';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Update verfügbar: $version';
  }

  @override
  String get settingsAboutLicenses => 'Lizenzen';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsAccentColor => 'Akzentfarbe';

  @override
  String get settingsTextScale => 'Textskalierung';

  @override
  String get settingsDensity => 'Dichte';

  @override
  String get settingsBackup => 'Sichern & Wiederherstellen';

  @override
  String get settingsBackupCreate => 'Sicherung erstellen';

  @override
  String get settingsBackupRestore => 'Sicherung wiederherstellen';

  @override
  String get settingsBackupAuto => 'Automatische Sicherung';

  @override
  String get settingsBackupCloudSync => 'Cloud-Synchronisation';

  @override
  String get settingsParentalControls => 'Kindersicherung';

  @override
  String get settingsParentalSetPin => 'PIN festlegen';

  @override
  String get settingsParentalChangePin => 'PIN ändern';

  @override
  String get settingsParentalRemovePin => 'PIN entfernen';

  @override
  String get settingsParentalBlockedCategories => 'Gesperrte Kategorien';

  @override
  String get settingsNetwork => 'Netzwerk';

  @override
  String get settingsNetworkDiagnostics => 'Netzwerkdiagnose';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Hardware-Decoder';

  @override
  String get settingsPlaybackBufferSize => 'Puffergröße';

  @override
  String get settingsPlaybackDeinterlace => 'Deinterlacing';

  @override
  String get settingsPlaybackUpscaling => 'Hochskalierung';

  @override
  String get settingsPlaybackAudioOutput => 'Audioausgabe';

  @override
  String get settingsPlaybackLoudnessNorm => 'Lautstärkenormalisierung';

  @override
  String get settingsPlaybackVolumeBoost => 'Lautstärkeverstärkung';

  @override
  String get settingsPlaybackAudioPassthrough => 'Audio-Passthrough';

  @override
  String get settingsPlaybackSegmentSkip => 'Segment überspringen';

  @override
  String get settingsPlaybackNextUp => 'Als nächstes';

  @override
  String get settingsPlaybackScreensaver => 'Bildschirmschoner';

  @override
  String get settingsPlaybackExternalPlayer => 'Externer Player';

  @override
  String get settingsSourceAdd => 'Quelle hinzufügen';

  @override
  String get settingsSourceEdit => 'Quelle bearbeiten';

  @override
  String get settingsSourceDelete => 'Quelle löschen';

  @override
  String get settingsSourceSync => 'Jetzt synchronisieren';

  @override
  String get settingsSourceSortOrder => 'Sortierreihenfolge';

  @override
  String get settingsDataClearCache => 'Cache leeren';

  @override
  String get settingsDataClearHistory => 'Wiedergabeverlauf löschen';

  @override
  String get settingsDataExport => 'Daten exportieren';

  @override
  String get settingsDataImport => 'Daten importieren';

  @override
  String get settingsAdvancedDebug => 'Debug-Modus';

  @override
  String get settingsAdvancedStreamProxy => 'Stream-Proxy';

  @override
  String get settingsAdvancedAutoUpdate => 'Automatische Updates';

  @override
  String get iptvMultiView => 'Multi-View';

  @override
  String get iptvTvGuide => 'TV-Programmführer';

  @override
  String get iptvBackToGroups => 'Zurück zu den Gruppen';

  @override
  String get iptvSearchChannels => 'Kanäle suchen';

  @override
  String get iptvListGridView => 'Listenansicht';

  @override
  String get iptvGridView => 'Rasteransicht';

  @override
  String iptvChannelHidden(String name) {
    return '$name ausgeblendet';
  }

  @override
  String get iptvSortDone => 'Fertig';

  @override
  String get iptvSortResetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get iptvSortByPlaylistOrder => 'Nach Playlist-Reihenfolge';

  @override
  String get iptvSortByName => 'Nach Name';

  @override
  String get iptvSortByRecent => 'Nach Aktualität';

  @override
  String get iptvSortByPopularity => 'Nach Beliebtheit';

  @override
  String get epgNowPlaying => 'Jetzt';

  @override
  String get epgNoData => 'Keine EPG-Daten verfügbar';

  @override
  String get epgSetReminder => 'Erinnerung setzen';

  @override
  String get epgCancelReminder => 'Erinnerung abbrechen';

  @override
  String get epgRecord => 'Aufnehmen';

  @override
  String get epgCancelRecording => 'Aufnahme abbrechen';

  @override
  String get vodMovies => 'Filme';

  @override
  String get vodSeries => 'Serien';

  @override
  String vodSeasonN(int number) {
    return 'Staffel $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Folge $number';
  }

  @override
  String get vodWatchNow => 'Jetzt ansehen';

  @override
  String get vodResume => 'Fortsetzen';

  @override
  String get vodContinueWatching => 'Weiterschauen';

  @override
  String get vodRecommended => 'Empfohlen';

  @override
  String get vodRecentlyAdded => 'Kürzlich hinzugefügt';

  @override
  String get vodNoItems => 'Keine Elemente gefunden';

  @override
  String get dvrSchedule => 'Zeitplan';

  @override
  String get dvrRecordings => 'Aufnahmen';

  @override
  String get dvrScheduleRecording => 'Aufnahme planen';

  @override
  String get dvrEditRecording => 'Aufnahme bearbeiten';

  @override
  String get dvrDeleteRecording => 'Aufnahme löschen';

  @override
  String get dvrNoRecordings => 'Keine Aufnahmen';

  @override
  String get searchTitle => 'Suchen';

  @override
  String get searchHint => 'Kanäle, Filme, Serien suchen…';

  @override
  String get searchNoResults => 'Keine Ergebnisse gefunden';

  @override
  String get searchFilterAll => 'Alle';

  @override
  String get searchFilterChannels => 'Kanäle';

  @override
  String get searchFilterMovies => 'Filme';

  @override
  String get searchFilterSeries => 'Serien';

  @override
  String get homeWhatsOn => 'Aktuelles Programm';

  @override
  String get homeContinueWatching => 'Weiterschauen';

  @override
  String get homeRecentChannels => 'Zuletzt gesehene Kanäle';

  @override
  String get homeMyList => 'Meine Liste';

  @override
  String get homeQuickAccess => 'Schnellzugriff';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get favoritesEmpty => 'Noch keine Favoriten';

  @override
  String get favoritesAddSome =>
      'Kanäle, Filme oder Serien zu Ihren Favoriten hinzufügen';

  @override
  String get profilesTitle => 'Profile';

  @override
  String get profilesCreate => 'Profil erstellen';

  @override
  String get profilesEdit => 'Profil bearbeiten';

  @override
  String get profilesDelete => 'Profil löschen';

  @override
  String get profilesManage => 'Profile verwalten';

  @override
  String get profilesWhoIsWatching => 'Wer schaut?';

  @override
  String get onboardingWelcome => 'Willkommen bei CrispyTivi';

  @override
  String get onboardingAddSource => 'Erste Quelle hinzufügen';

  @override
  String get onboardingChooseType => 'Quellentyp auswählen';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Verbinden und Kanäle laden…';

  @override
  String get onboardingDone => 'Alles bereit!';

  @override
  String get onboardingStartWatching => 'Jetzt ansehen';

  @override
  String get cloudSyncTitle => 'Cloud-Synchronisation';

  @override
  String get cloudSyncSignInGoogle => 'Mit Google anmelden';

  @override
  String get cloudSyncSignOut => 'Abmelden';

  @override
  String cloudSyncLastSync(String time) {
    return 'Letzte Synchronisation: $time';
  }

  @override
  String get cloudSyncNever => 'Nie';

  @override
  String get cloudSyncConflict => 'Synchronisationskonflikt';

  @override
  String get cloudSyncKeepLocal => 'Lokal behalten';

  @override
  String get cloudSyncKeepRemote => 'Remote behalten';

  @override
  String get castTitle => 'Übertragen';

  @override
  String get castSearching => 'Geräte werden gesucht…';

  @override
  String get castNoDevices => 'Keine Geräte gefunden';

  @override
  String get castDisconnect => 'Trennen';

  @override
  String get multiviewTitle => 'Multi-View';

  @override
  String get multiviewAddStream => 'Stream hinzufügen';

  @override
  String get multiviewRemoveStream => 'Stream entfernen';

  @override
  String get multiviewSaveLayout => 'Layout speichern';

  @override
  String get multiviewLoadLayout => 'Layout laden';

  @override
  String get multiviewLayoutName => 'Layout-Name';

  @override
  String get multiviewDeleteLayout => 'Layout löschen';

  @override
  String get mediaServerUrl => 'Server-URL';

  @override
  String get mediaServerUsername => 'Benutzername';

  @override
  String get mediaServerPassword => 'Passwort';

  @override
  String get mediaServerSignIn => 'Anmelden';

  @override
  String get mediaServerConnecting => 'Verbinden…';

  @override
  String get mediaServerConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String onboardingChannelsLoaded(int count) {
    return '$count Kanäle geladen!';
  }

  @override
  String get onboardingEnterApp => 'App betreten';

  @override
  String get onboardingEnterAppLabel => 'Die App betreten';

  @override
  String get onboardingCouldNotConnect => 'Verbindung fehlgeschlagen';

  @override
  String get onboardingRetryLabel => 'Verbindung erneut versuchen';

  @override
  String get onboardingEditSource => 'Quellendetails bearbeiten';

  @override
  String get playerAudioSectionLabel => 'AUDIO';

  @override
  String get playerSubtitlesSectionLabel => 'UNTERTITEL';

  @override
  String get playerSwitchProfileTitle => 'Profil wechseln';

  @override
  String get playerCopyStreamUrl => 'Stream-URL kopieren';

  @override
  String get cloudSyncSyncing => 'Synchronisieren…';

  @override
  String get cloudSyncNow => 'Jetzt synchronisieren';

  @override
  String get cloudSyncForceUpload => 'Hochladen erzwingen';

  @override
  String get cloudSyncForceDownload => 'Herunterladen erzwingen';

  @override
  String get cloudSyncAutoSync => 'Automatische Synchronisation';

  @override
  String get cloudSyncThisDevice => 'Dieses Gerät';

  @override
  String get cloudSyncCloud => 'Cloud';

  @override
  String get cloudSyncNewer => 'NEUER';

  @override
  String get contextMenuAddFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get contextMenuRemoveFavorite => 'Aus Favoriten entfernen';

  @override
  String get contextMenuSwitchStream => 'Streamquelle wechseln';

  @override
  String get contextMenuCopyUrl => 'Stream-URL kopieren';

  @override
  String get contextMenuOpenExternal => 'In externem Player abspielen';

  @override
  String get contextMenuPlay => 'Abspielen';

  @override
  String get contextMenuAddFavoriteCategory =>
      'Zu Lieblingskategorien hinzufügen';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Aus Lieblingskategorien entfernen';

  @override
  String get contextMenuFilterCategory => 'Nach dieser Kategorie filtern';

  @override
  String get confirmDeleteCancel => 'Abbrechen';

  @override
  String get confirmDeleteAction => 'Löschen';
}
