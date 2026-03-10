// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonSave => 'Kaydet';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonRetry => 'Yeniden Dene';

  @override
  String get commonSomethingWentWrong => 'Bir şeyler yanlış gitti';

  @override
  String get commonConfirm => 'Onayla';

  @override
  String get commonSubmit => 'Gönder';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonSearch => 'Ara';

  @override
  String get commonAll => 'Tümü';

  @override
  String get commonOn => 'Açık';

  @override
  String get commonOff => 'Kapalı';

  @override
  String get commonAuto => 'Otomatik';

  @override
  String get commonNone => 'Hiçbiri';

  @override
  String commonError(String message) {
    return 'Hata: $message';
  }

  @override
  String get commonOr => 'veya';

  @override
  String get commonRefresh => 'Yenile';

  @override
  String get commonDone => 'Tamam';

  @override
  String get commonPlay => 'Oynat';

  @override
  String get commonPause => 'Duraklat';

  @override
  String get commonLoading => 'Yükleniyor...';

  @override
  String get commonGoToSettings => 'Ayarlara Git';

  @override
  String get commonNew => 'YENİ';

  @override
  String get commonLive => 'CANLI';

  @override
  String get commonFavorites => 'Favoriler';

  @override
  String get keyboardShortcuts => 'Klavye kısayolları';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navSearch => 'Ara';

  @override
  String get navLiveTv => 'Canlı TV';

  @override
  String get navGuide => 'Rehber';

  @override
  String get navMovies => 'Filmler';

  @override
  String get navSeries => 'Diziler';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favoriler';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get breadcrumbProfiles => 'Profiller';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'Bulut';

  @override
  String get breadcrumbMultiView => 'Çoklu Görünüm';

  @override
  String get breadcrumbDetail => 'Ayrıntı';

  @override
  String get breadcrumbNavigateToParent => 'Üst dizine git';

  @override
  String get sideNavSwitchProfile => 'Profil Değiştir';

  @override
  String get sideNavManageProfiles => 'Profilleri yönet';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Profil değiştir: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return '$name için PIN girin';
  }

  @override
  String get sideNavActive => 'etkin';

  @override
  String get sideNavPinProtected => 'PIN korumalı';

  @override
  String get fabWhatsOn => 'Şu An Ne Var';

  @override
  String get fabRandomPick => 'Rastgele Seç';

  @override
  String get fabLastChannel => 'Son Kanal';

  @override
  String get fabSchedule => 'Program';

  @override
  String get fabNewList => 'Yeni Liste';

  @override
  String get offlineNoConnection => 'Bağlantı yok';

  @override
  String get offlineConnectionRestored => 'Bağlantı yeniden sağlandı';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Sayfa bulunamadı';

  @override
  String get pinConfirmPin => 'PIN\'i Onayla';

  @override
  String get pinEnterAllDigits => '4 rakamın tamamını girin';

  @override
  String get pinDoNotMatch => 'PIN\'ler eşleşmiyor';

  @override
  String get pinTooManyAttempts => 'Çok fazla hatalı deneme.';

  @override
  String pinTryAgainIn(String countdown) {
    return '$countdown içinde tekrar deneyin';
  }

  @override
  String get pinEnterSameAgain => 'Onaylamak için aynı PIN\'i tekrar girin';

  @override
  String get pinUseBiometric => 'Parmak izi veya yüz kullan';

  @override
  String pinDigitN(int n) {
    return 'PIN rakamı $n';
  }

  @override
  String get pinIncorrect => 'Yanlış PIN';

  @override
  String get pinVerificationFailed => 'Doğrulama başarısız';

  @override
  String get pinBiometricFailed =>
      'Biyometrik kimlik doğrulama başarısız oldu veya iptal edildi';

  @override
  String get contextMenuRemoveFromFavorites => 'Favorilerden Kaldır';

  @override
  String get contextMenuAddToFavorites => 'Favorilere Ekle';

  @override
  String get contextMenuSwitchStreamSource => 'Yayın kaynağını değiştir';

  @override
  String get contextMenuSmartGroup => 'Akıllı Grup';

  @override
  String get contextMenuMultiView => 'Çoklu Görünüm';

  @override
  String get contextMenuAssignEpg => 'EPG Ata';

  @override
  String get contextMenuHideChannel => 'Kanalı gizle';

  @override
  String get contextMenuCopyStreamUrl => 'Yayın URL\'sini Kopyala';

  @override
  String get contextMenuPlayExternal => 'Harici Oynatıcıda Oynat';

  @override
  String get contextMenuBlockChannel => 'Kanalı engelle';

  @override
  String get contextMenuViewDetails => 'Ayrıntıları görüntüle';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Favori Kategorilerden Kaldır';

  @override
  String get contextMenuAddToFavoriteCategories => 'Favori Kategorilere Ekle';

  @override
  String get contextMenuFilterByCategory => 'Bu kategoriye göre filtrele';

  @override
  String get contextMenuCloseContextMenu => 'Bağlam menüsünü kapat';

  @override
  String get sourceAllSources => 'Tüm Kaynaklar';

  @override
  String sourceFilterLabel(String label) {
    return '$label kaynak filtresi';
  }

  @override
  String get categoryLabel => 'Kategori';

  @override
  String categoryAll(String label) {
    return 'Tüm $label';
  }

  @override
  String categorySelect(String label) {
    return '$label seç';
  }

  @override
  String get categorySearchHint => 'Kategorilerde ara…';

  @override
  String get categorySearchLabel => 'Kategorilerde ara';

  @override
  String get categoryRemoveFromFavorites => 'Favori kategorilerden kaldır';

  @override
  String get categoryAddToFavorites => 'Favori kategorilere ekle';

  @override
  String get sidebarExpandSidebar => 'Kenar çubuğunu genişlet';

  @override
  String get sidebarCollapseSidebar => 'Kenar çubuğunu daralt';

  @override
  String get badgeNewEpisode => 'YENİ BÖLÜM';

  @override
  String get badgeNewSeason => 'YENİ SEZON';

  @override
  String get badgeRecording => 'KAYIT';

  @override
  String get badgeExpiring => 'SÜRESİ DOLUYOR';

  @override
  String get toggleFavorite => 'Favoriyi değiştir';

  @override
  String get playerSkipBack => '10 saniye geri al';

  @override
  String get playerSkipForward => '10 saniye ileri al';

  @override
  String get playerChannels => 'Kanallar';

  @override
  String get playerRecordings => 'Kayıtlar';

  @override
  String get playerCloseGuide => 'Rehberi Kapat (G)';

  @override
  String get playerTvGuide => 'TV Rehberi (G)';

  @override
  String get playerAudioSubtitles => 'Ses ve Altyazı';

  @override
  String get playerNoTracksAvailable => 'Kullanılabilir parça yok';

  @override
  String get playerExitFullscreen => 'Tam Ekrandan Çık';

  @override
  String get playerFullscreen => 'Tam Ekran';

  @override
  String get playerUnlockScreen => 'Ekran Kilidini Aç';

  @override
  String get playerLockScreen => 'Ekranı Kilitle';

  @override
  String get playerStreamQuality => 'Yayın Kalitesi';

  @override
  String get playerRotationLock => 'Döndürme Kilidi';

  @override
  String get playerScreenBrightness => 'Ekran Parlaklığı';

  @override
  String get playerShaderPreset => 'Gölgelendirici Ön Ayarı';

  @override
  String get playerAutoSystem => 'Otomatik (Sistem)';

  @override
  String get playerResetToAuto => 'Otomatiğe Sıfırla';

  @override
  String get playerPortrait => 'Dikey';

  @override
  String get playerPortraitUpsideDown => 'Dikey (baş aşağı)';

  @override
  String get playerLandscapeLeft => 'Yatay sol';

  @override
  String get playerLandscapeRight => 'Yatay sağ';

  @override
  String get playerDeinterlaceAuto => 'Otomatik';

  @override
  String get playerMoreOptions => 'Daha fazla seçenek';

  @override
  String get playerRemoveFavorite => 'Favoriden Kaldır';

  @override
  String get playerAddFavorite => 'Favoriye Ekle';

  @override
  String get playerAudioTrack => 'Ses Parçası';

  @override
  String playerAspectRatio(String label) {
    return 'En Boy Oranı ($label)';
  }

  @override
  String get playerRefreshStream => 'Yayını Yenile';

  @override
  String get playerStreamInfo => 'Yayın Bilgisi';

  @override
  String get playerPip => 'Pencere İçinde Pencere';

  @override
  String get playerSleepTimer => 'Uyku Zamanlayıcısı';

  @override
  String get playerExternalPlayer => 'Harici Oynatıcı';

  @override
  String get playerSearchChannels => 'Kanallarda Ara';

  @override
  String get playerChannelList => 'Kanal Listesi';

  @override
  String get playerScreenshot => 'Ekran Görüntüsü';

  @override
  String playerStreamQualityOption(String label) {
    return 'Yayın Kalitesi ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Tarama Çözme ($mode)';
  }

  @override
  String get playerSyncOffset => 'Senkronizasyon Gecikmesi';

  @override
  String playerAudioPassthrough(String state) {
    return 'Ses Aktarımı ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Ses Çıkış Cihazı';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Her Zaman Üstte ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Gölgelendiriciler ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'SES';

  @override
  String get playerSubtitlesSectionSubtitles => 'ALTYAZI';

  @override
  String get playerSubtitlesSecondHint => '(uzun basış = 2.)';

  @override
  String get playerSubtitlesCcStyle => 'CC Stili';

  @override
  String get playerSyncOffsetAudio => 'Ses';

  @override
  String get playerSyncOffsetSubtitle => 'Altyazı';

  @override
  String get playerSyncOffsetResetToZero => '0\'a Sıfırla';

  @override
  String get playerNoAudioDevices => 'Ses cihazı bulunamadı.';

  @override
  String get playerSpeedLive => 'Hız (canlı)';

  @override
  String get playerSpeed => 'Hız';

  @override
  String get playerVolumeLabel => 'Ses Seviyesi';

  @override
  String playerVolumePercent(int percent) {
    return 'Ses Seviyesi $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Profil değiştir ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '$duration kaldı';
  }

  @override
  String get playerSubtitleFontWeight => 'YAZI KALINLİĞI';

  @override
  String get playerSubtitleBold => 'Kalın';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'YAZI BOY';

  @override
  String playerSubtitlePosition(int value) {
    return 'KONUM ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'YAZI RENGİ';

  @override
  String get playerSubtitleOutlineColor => 'KENAR RENGİ';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'KENAR BOYUTU ($value)';
  }

  @override
  String get playerSubtitleBackground => 'ARKA PLAN';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'ARKA PLAN SAYDAMLIĞI ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'GÖLGE';

  @override
  String get playerSubtitlePreview => 'ÖNZLEME';

  @override
  String get playerSubtitleSampleText => 'Örnek altyazı metni';

  @override
  String get playerSubtitleResetDefaults => 'Varsayılanlara sıfırla';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return '$duration içinde duruyor';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Zamanlayıcıyı İptal Et';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes dakika';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Uyku zamanlayıcısını $minutes dakikaya ayarla';
  }

  @override
  String get playerStreamStats => 'Yayın İstatistikleri';

  @override
  String get playerStreamStatsBuffer => 'Tampon';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Kopyalandı!';

  @override
  String get playerStreamStatsCopy => 'İstatistikleri kopyala';

  @override
  String get playerStreamStatsInterlaced => 'Taramalı';

  @override
  String playerNextUpIn(int seconds) {
    return 'Sıradaki $seconds saniye içinde';
  }

  @override
  String get playerPlayNow => 'Şimdi Oynat';

  @override
  String get playerFinished => 'Bitti';

  @override
  String get playerWatchAgain => 'Tekrar İzle';

  @override
  String get playerBrowseMore => 'Daha Fazlasına Gözat';

  @override
  String get playerShortcutsTitle => 'Klavye Kısayolları';

  @override
  String get playerShortcutsCloseEsc => 'Kapat (Esc)';

  @override
  String get playerShortcutsPlayback => 'Oynatma';

  @override
  String get playerShortcutsPlayPause => 'Oynat / Duraklat';

  @override
  String get playerShortcutsSeek => 'İleri/Geri Al ±10 sn';

  @override
  String get playerShortcutsSpeedStep => 'Hız −/+ adım';

  @override
  String get playerShortcutsSpeedFine => 'Hız −/+ 0,1x';

  @override
  String get playerShortcutsJumpPercent => '% konumuna atla (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Kare adımı ±1';

  @override
  String get playerShortcutsAspectRatio => 'En boy oranını döngüle';

  @override
  String get playerShortcutsCycleSubtitles => 'Altyazıları döngüle';

  @override
  String get playerShortcutsVolume => 'Ses Seviyesi';

  @override
  String get playerShortcutsVolumeAdjust => 'Ses Seviyesi ±10%';

  @override
  String get playerShortcutsMute => 'Sesi kapat / aç';

  @override
  String get playerShortcutsDisplay => 'Görüntü';

  @override
  String get playerShortcutsFullscreenToggle => 'Tam ekranı değiştir';

  @override
  String get playerShortcutsExitFullscreen => 'Tam ekrandan çık / geri';

  @override
  String get playerShortcutsStreamInfo => 'Yayın bilgisi';

  @override
  String get playerShortcutsLiveTv => 'Canlı TV';

  @override
  String get playerShortcutsChannelUp => 'Kanal yukarı';

  @override
  String get playerShortcutsChannelDown => 'Kanal aşağı';

  @override
  String get playerShortcutsChannelList => 'Kanal listesi';

  @override
  String get playerShortcutsToggleZap => 'Zap katmanını değiştir';

  @override
  String get playerShortcutsGeneral => 'Genel';

  @override
  String get playerShortcutsSubtitlesCc => 'Altyazı / CC';

  @override
  String get playerShortcutsScreenLock => 'Ekran kilidi';

  @override
  String get playerShortcutsThisHelp => 'Bu yardım ekranı';

  @override
  String get playerShortcutsEscToClose =>
      'Kapatmak için Esc veya ? tuşuna basın';

  @override
  String get playerZapChannels => 'Kanallar';

  @override
  String get playerBookmark => 'Yer İşareti';

  @override
  String get playerEditBookmark => 'Yer İşaretini Düzenle';

  @override
  String get playerBookmarkLabelHint => 'Yer işareti etiketi (isteğe bağlı)';

  @override
  String get playerBookmarkLabelInput => 'Yer işareti etiketi';

  @override
  String playerBookmarkAdded(String label) {
    return '$label konumuna yer işareti eklendi';
  }

  @override
  String get playerExpandToFullscreen => 'Tam ekrana genişlet';

  @override
  String get playerUnmute => 'Sesi Aç';

  @override
  String get playerMute => 'Sesi Kapat';

  @override
  String get playerStopPlayback => 'Oynatmayı durdur';

  @override
  String get playerQueueUpNext => 'Sıradaki';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Sezon $number Bölümleri';
  }

  @override
  String get playerQueueEpisodes => 'Bölümler';

  @override
  String get playerQueueEmpty => 'Kuyruk boş';

  @override
  String get playerQueueClose => 'Kuyruğu Kapat';

  @override
  String get playerQueueOpen => 'Kuyruk';

  @override
  String playerEpisodeNumber(String number) {
    return 'Bölüm $number';
  }

  @override
  String get playerScreenLocked => 'Ekran kilitlendi';

  @override
  String get playerHoldToUnlock => 'Kilidini açmak için basılı tutun';

  @override
  String get playerScreenshotSaved => 'Ekran görüntüsü kaydedildi';

  @override
  String get playerScreenshotFailed => 'Ekran görüntüsü alınamadı';

  @override
  String get playerSkipSegment => 'Bölümü atla';

  @override
  String playerSkipType(String type) {
    return '$type atla';
  }

  @override
  String get playerCouldNotOpenExternal => 'Harici oynatıcı açılamadı';

  @override
  String get playerExitMultiView => 'Çoklu Görünümden Çık';

  @override
  String get playerScreensaverBouncingLogo => 'Zıplayan Logo';

  @override
  String get playerScreensaverClock => 'Saat';

  @override
  String get playerScreensaverBlackScreen => 'Siyah Ekran';

  @override
  String get streamProfileAuto => 'Otomatik';

  @override
  String get streamProfileAutoDesc => 'Ağa göre kaliteyi otomatik ayarla';

  @override
  String get streamProfileLow => 'Düşük';

  @override
  String get streamProfileLowDesc => 'SD kalite, maks. ~1 Mbps';

  @override
  String get streamProfileMedium => 'Orta';

  @override
  String get streamProfileMediumDesc => 'HD kalite, maks. ~3 Mbps';

  @override
  String get streamProfileHigh => 'Yüksek';

  @override
  String get streamProfileHighDesc => 'Full HD kalite, maks. ~8 Mbps';

  @override
  String get streamProfileMaximum => 'Maksimum';

  @override
  String get streamProfileMaximumDesc => 'Mevcut en iyi kalite, sınırsız';

  @override
  String get segmentIntro => 'Giriş';

  @override
  String get segmentOutro => 'Bitiş / Jenerik';

  @override
  String get segmentRecap => 'Özet';

  @override
  String get segmentCommercial => 'Reklam';

  @override
  String get segmentPreview => 'Önizleme';

  @override
  String get segmentSkipNone => 'Hiçbiri';

  @override
  String get segmentSkipAsk => 'Atlamak İçin Sor';

  @override
  String get segmentSkipOnce => 'Bir Kez Atla';

  @override
  String get segmentSkipAlways => 'Her Zaman Atla';

  @override
  String get nextUpOff => 'Kapalı';

  @override
  String get nextUpStatic => 'Sabit (bitiş öncesi 32 sn)';

  @override
  String get nextUpSmart => 'Akıllı (jenerik farkındalıklı)';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSearchSettings => 'Ayarlarda ara';

  @override
  String get settingsGeneral => 'Genel';

  @override
  String get settingsSources => 'Kaynaklar';

  @override
  String get settingsPlayback => 'Oynatma';

  @override
  String get settingsData => 'Veri';

  @override
  String get settingsAdvanced => 'Gelişmiş';

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsLanguageSystem => 'Sistem Varsayılanı';

  @override
  String get settingsAboutVersion => 'Sürüm';

  @override
  String get settingsAboutUpdates => 'Güncellemeler';

  @override
  String get settingsAboutCheckForUpdates => 'Güncellemeleri Denetle';

  @override
  String get settingsAboutUpToDate => 'Güncel sürümü kullanıyorsunuz';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Güncelleme mevcut: $version';
  }

  @override
  String get settingsAboutLicenses => 'Lisanslar';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsAccentColor => 'Vurgu Rengi';

  @override
  String get settingsTextScale => 'Metin Ölçeği';

  @override
  String get settingsDensity => 'Yoğunluk';

  @override
  String get settingsBackup => 'Yedekleme ve Geri Yükleme';

  @override
  String get settingsBackupCreate => 'Yedek Oluştur';

  @override
  String get settingsBackupRestore => 'Yedeği Geri Yükle';

  @override
  String get settingsBackupAuto => 'Otomatik Yedekleme';

  @override
  String get settingsBackupCloudSync => 'Bulut Senkronizasyonu';

  @override
  String get settingsParentalControls => 'Ebeveyn Denetimi';

  @override
  String get settingsParentalSetPin => 'PIN Belirle';

  @override
  String get settingsParentalChangePin => 'PIN Değiştir';

  @override
  String get settingsParentalRemovePin => 'PIN Kaldır';

  @override
  String get settingsParentalBlockedCategories => 'Engellenen Kategoriler';

  @override
  String get settingsNetwork => 'Ağ';

  @override
  String get settingsNetworkDiagnostics => 'Ağ Tanılama';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Donanım Kod Çözücü';

  @override
  String get settingsPlaybackBufferSize => 'Tampon Boyutu';

  @override
  String get settingsPlaybackDeinterlace => 'Tarama Çözme';

  @override
  String get settingsPlaybackUpscaling => 'Çözünürlük Artırma';

  @override
  String get settingsPlaybackAudioOutput => 'Ses Çıkışı';

  @override
  String get settingsPlaybackLoudnessNorm => 'Ses Düzeyi Normalizasyonu';

  @override
  String get settingsPlaybackVolumeBoost => 'Ses Güçlendirme';

  @override
  String get settingsPlaybackAudioPassthrough => 'Ses Aktarımı';

  @override
  String get settingsPlaybackSegmentSkip => 'Bölüm Atlama';

  @override
  String get settingsPlaybackNextUp => 'Sıradaki';

  @override
  String get settingsPlaybackScreensaver => 'Ekran Koruyucu';

  @override
  String get settingsPlaybackExternalPlayer => 'Harici Oynatıcı';

  @override
  String get settingsSourceAdd => 'Kaynak Ekle';

  @override
  String get settingsSourceEdit => 'Kaynağı Düzenle';

  @override
  String get settingsSourceDelete => 'Kaynağı Sil';

  @override
  String get settingsSourceSync => 'Şimdi Eşitle';

  @override
  String get settingsSourceSortOrder => 'Sıralama Düzeni';

  @override
  String get settingsDataClearCache => 'Önbelleği Temizle';

  @override
  String get settingsDataClearHistory => 'İzleme Geçmişini Temizle';

  @override
  String get settingsDataExport => 'Verileri Dışa Aktar';

  @override
  String get settingsDataImport => 'Verileri İçe Aktar';

  @override
  String get settingsAdvancedDebug => 'Hata Ayıklama Modu';

  @override
  String get settingsAdvancedStreamProxy => 'Yayın Proxy';

  @override
  String get settingsAdvancedAutoUpdate => 'Otomatik Güncelleme';

  @override
  String get iptvMultiView => 'Çoklu Görünüm';

  @override
  String get iptvTvGuide => 'TV Rehberi';

  @override
  String get iptvBackToGroups => 'Gruplara dön';

  @override
  String get iptvSearchChannels => 'Kanallarda ara';

  @override
  String get iptvListGridView => 'Liste Görünümü';

  @override
  String get iptvGridView => 'Izgara Görünümü';

  @override
  String iptvChannelHidden(String name) {
    return '$name gizlendi';
  }

  @override
  String get iptvSortDone => 'Tamam';

  @override
  String get iptvSortResetToDefault => 'Varsayılana Sıfırla';

  @override
  String get iptvSortByPlaylistOrder => 'Oynatma Listesi Sırasına Göre';

  @override
  String get iptvSortByName => 'Ada Göre';

  @override
  String get iptvSortByRecent => 'En Yeniye Göre';

  @override
  String get iptvSortByPopularity => 'Popülerliğe Göre';

  @override
  String get epgNowPlaying => 'Şimdi';

  @override
  String get epgNoData => 'EPG verisi mevcut değil';

  @override
  String get epgSetReminder => 'Hatırlatıcı Kur';

  @override
  String get epgCancelReminder => 'Hatırlatıcıyı İptal Et';

  @override
  String get epgRecord => 'Kaydet';

  @override
  String get epgCancelRecording => 'Kaydı İptal Et';

  @override
  String get vodMovies => 'Filmler';

  @override
  String get vodSeries => 'Diziler';

  @override
  String vodSeasonN(int number) {
    return 'Sezon $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Bölüm $number';
  }

  @override
  String get vodWatchNow => 'Şimdi İzle';

  @override
  String get vodResume => 'Devam Et';

  @override
  String get vodContinueWatching => 'İzlemeye Devam Et';

  @override
  String get vodRecommended => 'Önerilenler';

  @override
  String get vodRecentlyAdded => 'Yeni Eklenenler';

  @override
  String get vodNoItems => 'Öğe bulunamadı';

  @override
  String get dvrSchedule => 'Program';

  @override
  String get dvrRecordings => 'Kayıtlar';

  @override
  String get dvrScheduleRecording => 'Kayıt Planla';

  @override
  String get dvrEditRecording => 'Kaydı Düzenle';

  @override
  String get dvrDeleteRecording => 'Kaydı Sil';

  @override
  String get dvrNoRecordings => 'Kayıt yok';

  @override
  String get searchTitle => 'Ara';

  @override
  String get searchHint => 'Kanal, film, dizi ara…';

  @override
  String get searchNoResults => 'Sonuç bulunamadı';

  @override
  String get searchFilterAll => 'Tümü';

  @override
  String get searchFilterChannels => 'Kanallar';

  @override
  String get searchFilterMovies => 'Filmler';

  @override
  String get searchFilterSeries => 'Diziler';

  @override
  String get homeWhatsOn => 'Şu An Ne Var';

  @override
  String get homeContinueWatching => 'İzlemeye Devam Et';

  @override
  String get homeRecentChannels => 'Son Kanallar';

  @override
  String get homeMyList => 'Listem';

  @override
  String get homeQuickAccess => 'Hızlı Erişim';

  @override
  String get favoritesTitle => 'Favoriler';

  @override
  String get favoritesEmpty => 'Henüz favori yok';

  @override
  String get favoritesAddSome => 'Favorilerinize kanal, film veya dizi ekleyin';

  @override
  String get profilesTitle => 'Profiller';

  @override
  String get profilesCreate => 'Profil Oluştur';

  @override
  String get profilesEdit => 'Profili Düzenle';

  @override
  String get profilesDelete => 'Profili Sil';

  @override
  String get profilesManage => 'Profilleri Yönet';

  @override
  String get profilesWhoIsWatching => 'Kim İzliyor?';

  @override
  String get onboardingWelcome => 'CrispyTivi\'ye Hoş Geldiniz';

  @override
  String get onboardingAddSource => 'İlk Kaynağınızı Ekleyin';

  @override
  String get onboardingChooseType => 'Kaynak Türü Seçin';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Bağlanılıyor ve kanallar yükleniyor…';

  @override
  String get onboardingDone => 'Her Şey Hazır!';

  @override
  String get onboardingStartWatching => 'İzlemeye Başla';

  @override
  String get cloudSyncTitle => 'Bulut Senkronizasyonu';

  @override
  String get cloudSyncSignInGoogle => 'Google ile Giriş Yap';

  @override
  String get cloudSyncSignOut => 'Çıkış Yap';

  @override
  String cloudSyncLastSync(String time) {
    return 'Son eşitleme: $time';
  }

  @override
  String get cloudSyncNever => 'Hiçbir zaman';

  @override
  String get cloudSyncConflict => 'Senkronizasyon Çakışması';

  @override
  String get cloudSyncKeepLocal => 'Yerel Olanı Tut';

  @override
  String get cloudSyncKeepRemote => 'Uzak Olanı Tut';

  @override
  String get castTitle => 'Yayınla';

  @override
  String get castSearching => 'Cihazlar aranıyor…';

  @override
  String get castNoDevices => 'Cihaz bulunamadı';

  @override
  String get castDisconnect => 'Bağlantıyı Kes';

  @override
  String get multiviewTitle => 'Çoklu Görünüm';

  @override
  String get multiviewAddStream => 'Yayın Ekle';

  @override
  String get multiviewRemoveStream => 'Yayını Kaldır';

  @override
  String get multiviewSaveLayout => 'Düzeni Kaydet';

  @override
  String get multiviewLoadLayout => 'Düzeni Yükle';

  @override
  String get multiviewLayoutName => 'Düzen adı';

  @override
  String get multiviewDeleteLayout => 'Düzeni Sil';

  @override
  String get mediaServerUrl => 'Sunucu URL\'si';

  @override
  String get mediaServerUsername => 'Kullanıcı Adı';

  @override
  String get mediaServerPassword => 'Parola';

  @override
  String get mediaServerSignIn => 'Giriş Yap';

  @override
  String get mediaServerConnecting => 'Bağlanılıyor…';

  @override
  String get mediaServerConnectionFailed => 'Bağlantı başarısız';

  @override
  String onboardingChannelsLoaded(int count) {
    return '$count kanal yüklendi!';
  }

  @override
  String get onboardingEnterApp => 'Uygulamaya Gir';

  @override
  String get onboardingEnterAppLabel => 'Uygulamaya gir';

  @override
  String get onboardingCouldNotConnect => 'Bağlanılamadı';

  @override
  String get onboardingRetryLabel => 'Bağlantıyı yeniden dene';

  @override
  String get onboardingEditSource => 'Kaynak ayrıntılarını düzenle';

  @override
  String get playerAudioSectionLabel => 'SES';

  @override
  String get playerSubtitlesSectionLabel => 'ALTYAZI';

  @override
  String get playerSwitchProfileTitle => 'Profil Değiştir';

  @override
  String get playerCopyStreamUrl => 'Yayın URL\'sini Kopyala';

  @override
  String get cloudSyncSyncing => 'Eşitleniyor…';

  @override
  String get cloudSyncNow => 'Şimdi Eşitle';

  @override
  String get cloudSyncForceUpload => 'Zorla Yükle';

  @override
  String get cloudSyncForceDownload => 'Zorla İndir';

  @override
  String get cloudSyncAutoSync => 'Otomatik eşitleme';

  @override
  String get cloudSyncThisDevice => 'Bu Cihaz';

  @override
  String get cloudSyncCloud => 'Bulut';

  @override
  String get cloudSyncNewer => 'DAHA YENİ';

  @override
  String get contextMenuAddFavorite => 'Favorilere Ekle';

  @override
  String get contextMenuRemoveFavorite => 'Favorilerden Kaldır';

  @override
  String get contextMenuSwitchStream => 'Yayın kaynağını değiştir';

  @override
  String get contextMenuCopyUrl => 'Yayın URL\'sini Kopyala';

  @override
  String get contextMenuOpenExternal => 'Harici Oynatıcıda Oynat';

  @override
  String get contextMenuPlay => 'Oynat';

  @override
  String get contextMenuAddFavoriteCategory => 'Favori Kategorilere Ekle';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Favori Kategorilerden Kaldır';

  @override
  String get contextMenuFilterCategory => 'Bu kategoriye göre filtrele';

  @override
  String get confirmDeleteCancel => 'İptal';

  @override
  String get confirmDeleteAction => 'Sil';
}
