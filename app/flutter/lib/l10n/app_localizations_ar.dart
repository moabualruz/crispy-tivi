// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonSomethingWentWrong => 'حدث خطأ ما';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonAll => 'الكل';

  @override
  String get commonOn => 'تشغيل';

  @override
  String get commonOff => 'إيقاف';

  @override
  String get commonAuto => 'تلقائي';

  @override
  String get commonNone => 'لا شيء';

  @override
  String commonError(String message) {
    return 'خطأ: $message';
  }

  @override
  String get commonOr => 'أو';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonDone => 'تم';

  @override
  String get commonPlay => 'تشغيل';

  @override
  String get commonPause => 'إيقاف مؤقت';

  @override
  String get commonLoading => 'جارٍ التحميل...';

  @override
  String get commonGoToSettings => 'الذهاب إلى الإعدادات';

  @override
  String get commonNew => 'جديد';

  @override
  String get commonLive => 'مباشر';

  @override
  String get commonFavorites => 'المفضلة';

  @override
  String get keyboardShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSearch => 'بحث';

  @override
  String get navLiveTv => 'التلفاز المباشر';

  @override
  String get navGuide => 'الدليل';

  @override
  String get navMovies => 'أفلام';

  @override
  String get navSeries => 'مسلسلات';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get breadcrumbProfiles => 'الملفات الشخصية';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'السحابة';

  @override
  String get breadcrumbMultiView => 'عرض متعدد';

  @override
  String get breadcrumbDetail => 'التفاصيل';

  @override
  String get breadcrumbNavigateToParent => 'الانتقال إلى المستوى الأعلى';

  @override
  String get sideNavSwitchProfile => 'تبديل الملف الشخصي';

  @override
  String get sideNavManageProfiles => 'إدارة الملفات الشخصية';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'تبديل الملف الشخصي: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'أدخل رمز PIN لـ $name';
  }

  @override
  String get sideNavActive => 'نشط';

  @override
  String get sideNavPinProtected => 'محمي برمز PIN';

  @override
  String get fabWhatsOn => 'ماذا يعرض الآن';

  @override
  String get fabRandomPick => 'اختيار عشوائي';

  @override
  String get fabLastChannel => 'القناة الأخيرة';

  @override
  String get fabSchedule => 'الجدول';

  @override
  String get fabNewList => 'قائمة جديدة';

  @override
  String get offlineNoConnection => 'لا يوجد اتصال';

  @override
  String get offlineConnectionRestored => 'تم استعادة الاتصال';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'الصفحة غير موجودة';

  @override
  String get pinConfirmPin => 'تأكيد رمز PIN';

  @override
  String get pinEnterAllDigits => 'أدخل الأرقام الأربعة كاملة';

  @override
  String get pinDoNotMatch => 'رموز PIN غير متطابقة';

  @override
  String get pinTooManyAttempts => 'محاولات خاطئة كثيرة جداً.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'أعد المحاولة خلال $countdown';
  }

  @override
  String get pinEnterSameAgain => 'أدخل رمز PIN نفسه مرة أخرى للتأكيد';

  @override
  String get pinUseBiometric => 'استخدم بصمة الإصبع أو الوجه';

  @override
  String pinDigitN(int n) {
    return 'رقم PIN $n';
  }

  @override
  String get pinIncorrect => 'رمز PIN غير صحيح';

  @override
  String get pinVerificationFailed => 'فشل التحقق';

  @override
  String get pinBiometricFailed => 'فشل التحقق البيومتري أو تم إلغاؤه';

  @override
  String get contextMenuRemoveFromFavorites => 'إزالة من المفضلة';

  @override
  String get contextMenuAddToFavorites => 'إضافة إلى المفضلة';

  @override
  String get contextMenuSwitchStreamSource => 'تبديل مصدر البث';

  @override
  String get contextMenuSmartGroup => 'مجموعة ذكية';

  @override
  String get contextMenuMultiView => 'عرض متعدد';

  @override
  String get contextMenuAssignEpg => 'تعيين EPG';

  @override
  String get contextMenuHideChannel => 'إخفاء القناة';

  @override
  String get contextMenuCopyStreamUrl => 'نسخ رابط البث';

  @override
  String get contextMenuPlayExternal => 'تشغيل في مشغل خارجي';

  @override
  String get contextMenuBlockChannel => 'حجب القناة';

  @override
  String get contextMenuViewDetails => 'عرض التفاصيل';

  @override
  String get contextMenuRemoveFromFavoriteCategories => 'إزالة من فئات المفضلة';

  @override
  String get contextMenuAddToFavoriteCategories => 'إضافة إلى فئات المفضلة';

  @override
  String get contextMenuFilterByCategory => 'تصفية حسب هذه الفئة';

  @override
  String get contextMenuCloseContextMenu => 'إغلاق القائمة السياقية';

  @override
  String get sourceAllSources => 'جميع المصادر';

  @override
  String sourceFilterLabel(String label) {
    return 'فلتر مصدر $label';
  }

  @override
  String get categoryLabel => 'الفئة';

  @override
  String categoryAll(String label) {
    return 'جميع $label';
  }

  @override
  String categorySelect(String label) {
    return 'اختر $label';
  }

  @override
  String get categorySearchHint => 'بحث في الفئات…';

  @override
  String get categorySearchLabel => 'بحث في الفئات';

  @override
  String get categoryRemoveFromFavorites => 'إزالة من فئات المفضلة';

  @override
  String get categoryAddToFavorites => 'إضافة إلى فئات المفضلة';

  @override
  String get sidebarExpandSidebar => 'توسيع الشريط الجانبي';

  @override
  String get sidebarCollapseSidebar => 'طي الشريط الجانبي';

  @override
  String get badgeNewEpisode => 'حلقة جديدة';

  @override
  String get badgeNewSeason => 'موسم جديد';

  @override
  String get badgeRecording => 'تسجيل';

  @override
  String get badgeExpiring => 'ينتهي قريباً';

  @override
  String get toggleFavorite => 'تبديل المفضلة';

  @override
  String get playerSkipBack => 'تخطٍّ للخلف 10 ثوانٍ';

  @override
  String get playerSkipForward => 'تخطٍّ للأمام 10 ثوانٍ';

  @override
  String get playerChannels => 'القنوات';

  @override
  String get playerRecordings => 'التسجيلات';

  @override
  String get playerCloseGuide => 'إغلاق الدليل (G)';

  @override
  String get playerTvGuide => 'دليل التلفاز (G)';

  @override
  String get playerAudioSubtitles => 'الصوت والترجمة';

  @override
  String get playerNoTracksAvailable => 'لا تتوفر مسارات';

  @override
  String get playerExitFullscreen => 'الخروج من وضع ملء الشاشة';

  @override
  String get playerFullscreen => 'ملء الشاشة';

  @override
  String get playerUnlockScreen => 'إلغاء قفل الشاشة';

  @override
  String get playerLockScreen => 'قفل الشاشة';

  @override
  String get playerStreamQuality => 'جودة البث';

  @override
  String get playerRotationLock => 'قفل الدوران';

  @override
  String get playerScreenBrightness => 'سطوع الشاشة';

  @override
  String get playerShaderPreset => 'إعداد تأثيرات الصورة مسبقاً';

  @override
  String get playerAutoSystem => 'تلقائي (النظام)';

  @override
  String get playerResetToAuto => 'إعادة الضبط إلى التلقائي';

  @override
  String get playerPortrait => 'عمودي';

  @override
  String get playerPortraitUpsideDown => 'عمودي (مقلوب)';

  @override
  String get playerLandscapeLeft => 'أفقي لليسار';

  @override
  String get playerLandscapeRight => 'أفقي لليمين';

  @override
  String get playerDeinterlaceAuto => 'تلقائي';

  @override
  String get playerMoreOptions => 'خيارات إضافية';

  @override
  String get playerRemoveFavorite => 'إزالة من المفضلة';

  @override
  String get playerAddFavorite => 'إضافة إلى المفضلة';

  @override
  String get playerAudioTrack => 'المسار الصوتي';

  @override
  String playerAspectRatio(String label) {
    return 'نسبة العرض إلى الارتفاع ($label)';
  }

  @override
  String get playerRefreshStream => 'تحديث البث';

  @override
  String get playerStreamInfo => 'معلومات البث';

  @override
  String get playerPip => 'صورة داخل صورة';

  @override
  String get playerSleepTimer => 'مؤقت النوم';

  @override
  String get playerExternalPlayer => 'مشغل خارجي';

  @override
  String get playerSearchChannels => 'البحث في القنوات';

  @override
  String get playerChannelList => 'قائمة القنوات';

  @override
  String get playerScreenshot => 'لقطة شاشة';

  @override
  String playerStreamQualityOption(String label) {
    return 'جودة البث ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'إزالة التشابك ($mode)';
  }

  @override
  String get playerSyncOffset => 'إزاحة المزامنة';

  @override
  String playerAudioPassthrough(String state) {
    return 'تمرير الصوت ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'جهاز إخراج الصوت';

  @override
  String playerAlwaysOnTop(String state) {
    return 'دائماً في الأعلى ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'تأثيرات الصورة ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'الصوت';

  @override
  String get playerSubtitlesSectionSubtitles => 'الترجمة';

  @override
  String get playerSubtitlesSecondHint => '(ضغط طويل = الثانية)';

  @override
  String get playerSubtitlesCcStyle => 'نمط الترجمة';

  @override
  String get playerSyncOffsetAudio => 'الصوت';

  @override
  String get playerSyncOffsetSubtitle => 'الترجمة';

  @override
  String get playerSyncOffsetResetToZero => 'إعادة الضبط إلى 0';

  @override
  String get playerNoAudioDevices => 'لم يتم العثور على أجهزة صوت.';

  @override
  String get playerSpeedLive => 'السرعة (مباشر)';

  @override
  String get playerSpeed => 'السرعة';

  @override
  String get playerVolumeLabel => 'مستوى الصوت';

  @override
  String playerVolumePercent(int percent) {
    return 'مستوى الصوت $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'تبديل الملف الشخصي ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return 'متبقٍّ $duration';
  }

  @override
  String get playerSubtitleFontWeight => 'وزن الخط';

  @override
  String get playerSubtitleBold => 'عريض';

  @override
  String get playerSubtitleNormal => 'عادي';

  @override
  String get playerSubtitleFontSize => 'حجم الخط';

  @override
  String playerSubtitlePosition(int value) {
    return 'الموضع ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'لون النص';

  @override
  String get playerSubtitleOutlineColor => 'لون الحدود';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'حجم الحدود ($value)';
  }

  @override
  String get playerSubtitleBackground => 'الخلفية';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'شفافية الخلفية ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'الظل';

  @override
  String get playerSubtitlePreview => 'معاينة';

  @override
  String get playerSubtitleSampleText => 'نص ترجمة تجريبي';

  @override
  String get playerSubtitleResetDefaults => 'إعادة الضبط إلى الافتراضي';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'يتوقف خلال $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'إلغاء المؤقت';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'ضبط مؤقت النوم على $minutes دقيقة';
  }

  @override
  String get playerStreamStats => 'إحصائيات البث';

  @override
  String get playerStreamStatsBuffer => 'المخزن المؤقت';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'تم النسخ!';

  @override
  String get playerStreamStatsCopy => 'نسخ الإحصائيات';

  @override
  String get playerStreamStatsInterlaced => 'متشابك';

  @override
  String playerNextUpIn(int seconds) {
    return 'التالي خلال $seconds';
  }

  @override
  String get playerPlayNow => 'تشغيل الآن';

  @override
  String get playerFinished => 'انتهى';

  @override
  String get playerWatchAgain => 'مشاهدة مرة أخرى';

  @override
  String get playerBrowseMore => 'استعراض المزيد';

  @override
  String get playerShortcutsTitle => 'اختصارات لوحة المفاتيح';

  @override
  String get playerShortcutsCloseEsc => 'إغلاق (Esc)';

  @override
  String get playerShortcutsPlayback => 'التشغيل';

  @override
  String get playerShortcutsPlayPause => 'تشغيل / إيقاف مؤقت';

  @override
  String get playerShortcutsSeek => 'تقديم/تأخير ±10 ثانية';

  @override
  String get playerShortcutsSpeedStep => 'السرعة −/+ خطوة';

  @override
  String get playerShortcutsSpeedFine => 'السرعة −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => 'القفز إلى نسبة مئوية (VOD)';

  @override
  String get playerShortcutsFrameStep => 'تقديم/تأخير إطار ±1';

  @override
  String get playerShortcutsAspectRatio => 'تبديل نسبة العرض';

  @override
  String get playerShortcutsCycleSubtitles => 'تبديل الترجمة';

  @override
  String get playerShortcutsVolume => 'مستوى الصوت';

  @override
  String get playerShortcutsVolumeAdjust => 'مستوى الصوت ±10%';

  @override
  String get playerShortcutsMute => 'كتم / إلغاء الكتم';

  @override
  String get playerShortcutsDisplay => 'العرض';

  @override
  String get playerShortcutsFullscreenToggle => 'تبديل ملء الشاشة';

  @override
  String get playerShortcutsExitFullscreen => 'الخروج من ملء الشاشة / رجوع';

  @override
  String get playerShortcutsStreamInfo => 'معلومات البث';

  @override
  String get playerShortcutsLiveTv => 'التلفاز المباشر';

  @override
  String get playerShortcutsChannelUp => 'القناة التالية';

  @override
  String get playerShortcutsChannelDown => 'القناة السابقة';

  @override
  String get playerShortcutsChannelList => 'قائمة القنوات';

  @override
  String get playerShortcutsToggleZap => 'تبديل طبقة التنقل السريع';

  @override
  String get playerShortcutsGeneral => 'عام';

  @override
  String get playerShortcutsSubtitlesCc => 'الترجمة / CC';

  @override
  String get playerShortcutsScreenLock => 'قفل الشاشة';

  @override
  String get playerShortcutsThisHelp => 'شاشة المساعدة هذه';

  @override
  String get playerShortcutsEscToClose => 'اضغط Esc أو ? للإغلاق';

  @override
  String get playerZapChannels => 'القنوات';

  @override
  String get playerBookmark => 'إشارة مرجعية';

  @override
  String get playerEditBookmark => 'تعديل الإشارة المرجعية';

  @override
  String get playerBookmarkLabelHint => 'تسمية الإشارة المرجعية (اختياري)';

  @override
  String get playerBookmarkLabelInput => 'تسمية الإشارة المرجعية';

  @override
  String playerBookmarkAdded(String label) {
    return 'تمت إضافة الإشارة المرجعية عند $label';
  }

  @override
  String get playerExpandToFullscreen => 'توسيع إلى ملء الشاشة';

  @override
  String get playerUnmute => 'إلغاء الكتم';

  @override
  String get playerMute => 'كتم الصوت';

  @override
  String get playerStopPlayback => 'إيقاف التشغيل';

  @override
  String get playerQueueUpNext => 'التالي';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'حلقات الموسم $number';
  }

  @override
  String get playerQueueEpisodes => 'الحلقات';

  @override
  String get playerQueueEmpty => 'قائمة التشغيل فارغة';

  @override
  String get playerQueueClose => 'إغلاق القائمة';

  @override
  String get playerQueueOpen => 'القائمة';

  @override
  String playerEpisodeNumber(String number) {
    return 'الحلقة $number';
  }

  @override
  String get playerScreenLocked => 'الشاشة مقفلة';

  @override
  String get playerHoldToUnlock => 'اضغط مطولاً لإلغاء القفل';

  @override
  String get playerScreenshotSaved => 'تم حفظ لقطة الشاشة';

  @override
  String get playerScreenshotFailed => 'فشل التقاط الشاشة';

  @override
  String get playerSkipSegment => 'تخطي المقطع';

  @override
  String playerSkipType(String type) {
    return 'تخطي $type';
  }

  @override
  String get playerCouldNotOpenExternal => 'تعذّر فتح المشغل الخارجي';

  @override
  String get playerExitMultiView => 'الخروج من العرض المتعدد';

  @override
  String get playerScreensaverBouncingLogo => 'شعار متحرك';

  @override
  String get playerScreensaverClock => 'ساعة';

  @override
  String get playerScreensaverBlackScreen => 'شاشة سوداء';

  @override
  String get streamProfileAuto => 'تلقائي';

  @override
  String get streamProfileAutoDesc => 'ضبط الجودة تلقائياً حسب الشبكة';

  @override
  String get streamProfileLow => 'منخفض';

  @override
  String get streamProfileLowDesc => 'جودة SD، بحد أقصى ~1 ميجابت/ث';

  @override
  String get streamProfileMedium => 'متوسط';

  @override
  String get streamProfileMediumDesc => 'جودة HD، بحد أقصى ~3 ميجابت/ث';

  @override
  String get streamProfileHigh => 'عالٍ';

  @override
  String get streamProfileHighDesc => 'جودة Full HD، بحد أقصى ~8 ميجابت/ث';

  @override
  String get streamProfileMaximum => 'أعلى جودة';

  @override
  String get streamProfileMaximumDesc => 'أفضل جودة متاحة، بلا حد أقصى';

  @override
  String get segmentIntro => 'مقدمة';

  @override
  String get segmentOutro => 'خاتمة / تترات';

  @override
  String get segmentRecap => 'ملخص';

  @override
  String get segmentCommercial => 'إعلان';

  @override
  String get segmentPreview => 'معاينة';

  @override
  String get segmentSkipNone => 'لا شيء';

  @override
  String get segmentSkipAsk => 'السؤال قبل التخطي';

  @override
  String get segmentSkipOnce => 'تخطي مرة واحدة';

  @override
  String get segmentSkipAlways => 'التخطي دائماً';

  @override
  String get nextUpOff => 'إيقاف';

  @override
  String get nextUpStatic => 'ثابت (32 ثانية قبل النهاية)';

  @override
  String get nextUpSmart => 'ذكي (يدرك التتر)';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsSearchSettings => 'البحث في الإعدادات';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get settingsSources => 'المصادر';

  @override
  String get settingsPlayback => 'التشغيل';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsAdvanced => 'متقدم';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSystem => 'الإعداد الافتراضي للنظام';

  @override
  String get settingsAboutVersion => 'الإصدار';

  @override
  String get settingsAboutUpdates => 'التحديثات';

  @override
  String get settingsAboutCheckForUpdates => 'التحقق من التحديثات';

  @override
  String get settingsAboutUpToDate => 'أنت تستخدم أحدث إصدار';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'تحديث متاح: $version';
  }

  @override
  String get settingsAboutLicenses => 'التراخيص';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get settingsAccentColor => 'لون التمييز';

  @override
  String get settingsTextScale => 'حجم النص';

  @override
  String get settingsDensity => 'الكثافة';

  @override
  String get settingsBackup => 'النسخ الاحتياطي والاستعادة';

  @override
  String get settingsBackupCreate => 'إنشاء نسخة احتياطية';

  @override
  String get settingsBackupRestore => 'استعادة نسخة احتياطية';

  @override
  String get settingsBackupAuto => 'نسخ احتياطي تلقائي';

  @override
  String get settingsBackupCloudSync => 'المزامنة السحابية';

  @override
  String get settingsParentalControls => 'الرقابة الأبوية';

  @override
  String get settingsParentalSetPin => 'تعيين رمز PIN';

  @override
  String get settingsParentalChangePin => 'تغيير رمز PIN';

  @override
  String get settingsParentalRemovePin => 'إزالة رمز PIN';

  @override
  String get settingsParentalBlockedCategories => 'الفئات المحجوبة';

  @override
  String get settingsNetwork => 'الشبكة';

  @override
  String get settingsNetworkDiagnostics => 'تشخيص الشبكة';

  @override
  String get settingsNetworkProxy => 'الوكيل (Proxy)';

  @override
  String get settingsPlaybackHardwareDecoder => 'فك التشفير بالعتاد';

  @override
  String get settingsPlaybackBufferSize => 'حجم المخزن المؤقت';

  @override
  String get settingsPlaybackDeinterlace => 'إزالة التشابك';

  @override
  String get settingsPlaybackUpscaling => 'تحسين الدقة';

  @override
  String get settingsPlaybackAudioOutput => 'إخراج الصوت';

  @override
  String get settingsPlaybackLoudnessNorm => 'تطبيع مستوى الصوت';

  @override
  String get settingsPlaybackVolumeBoost => 'تعزيز الصوت';

  @override
  String get settingsPlaybackAudioPassthrough => 'تمرير الصوت';

  @override
  String get settingsPlaybackSegmentSkip => 'تخطي المقطع';

  @override
  String get settingsPlaybackNextUp => 'التالي';

  @override
  String get settingsPlaybackScreensaver => 'شاشة التوقف';

  @override
  String get settingsPlaybackExternalPlayer => 'مشغل خارجي';

  @override
  String get settingsSourceAdd => 'إضافة مصدر';

  @override
  String get settingsSourceEdit => 'تعديل المصدر';

  @override
  String get settingsSourceDelete => 'حذف المصدر';

  @override
  String get settingsSourceSync => 'مزامنة الآن';

  @override
  String get settingsSourceSortOrder => 'ترتيب الفرز';

  @override
  String get settingsDataClearCache => 'مسح ذاكرة التخزين المؤقت';

  @override
  String get settingsDataClearHistory => 'مسح سجل المشاهدة';

  @override
  String get settingsDataExport => 'تصدير البيانات';

  @override
  String get settingsDataImport => 'استيراد البيانات';

  @override
  String get settingsAdvancedDebug => 'وضع التصحيح';

  @override
  String get settingsAdvancedStreamProxy => 'وكيل البث';

  @override
  String get settingsAdvancedAutoUpdate => 'التحديث التلقائي';

  @override
  String get iptvMultiView => 'عرض متعدد';

  @override
  String get iptvTvGuide => 'دليل التلفاز';

  @override
  String get iptvBackToGroups => 'العودة إلى المجموعات';

  @override
  String get iptvSearchChannels => 'البحث في القنوات';

  @override
  String get iptvListGridView => 'عرض القائمة';

  @override
  String get iptvGridView => 'عرض الشبكة';

  @override
  String iptvChannelHidden(String name) {
    return 'تم إخفاء $name';
  }

  @override
  String get iptvSortDone => 'تم';

  @override
  String get iptvSortResetToDefault => 'إعادة الضبط إلى الافتراضي';

  @override
  String get iptvSortByPlaylistOrder => 'حسب ترتيب قائمة التشغيل';

  @override
  String get iptvSortByName => 'حسب الاسم';

  @override
  String get iptvSortByRecent => 'حسب الأحدث';

  @override
  String get iptvSortByPopularity => 'حسب الشعبية';

  @override
  String get epgNowPlaying => 'الآن';

  @override
  String get epgNoData => 'لا تتوفر بيانات EPG';

  @override
  String get epgSetReminder => 'تعيين تذكير';

  @override
  String get epgCancelReminder => 'إلغاء التذكير';

  @override
  String get epgRecord => 'تسجيل';

  @override
  String get epgCancelRecording => 'إلغاء التسجيل';

  @override
  String get vodMovies => 'أفلام';

  @override
  String get vodSeries => 'مسلسلات';

  @override
  String vodSeasonN(int number) {
    return 'الموسم $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'الحلقة $number';
  }

  @override
  String get vodWatchNow => 'مشاهدة الآن';

  @override
  String get vodResume => 'استئناف';

  @override
  String get vodContinueWatching => 'متابعة المشاهدة';

  @override
  String get vodRecommended => 'موصى به';

  @override
  String get vodRecentlyAdded => 'أضيف حديثاً';

  @override
  String get vodNoItems => 'لم يتم العثور على عناصر';

  @override
  String get dvrSchedule => 'الجدول';

  @override
  String get dvrRecordings => 'التسجيلات';

  @override
  String get dvrScheduleRecording => 'جدولة التسجيل';

  @override
  String get dvrEditRecording => 'تعديل التسجيل';

  @override
  String get dvrDeleteRecording => 'حذف التسجيل';

  @override
  String get dvrNoRecordings => 'لا توجد تسجيلات';

  @override
  String get searchTitle => 'بحث';

  @override
  String get searchHint => 'ابحث في القنوات والأفلام والمسلسلات…';

  @override
  String get searchNoResults => 'لم يتم العثور على نتائج';

  @override
  String get searchFilterAll => 'الكل';

  @override
  String get searchFilterChannels => 'القنوات';

  @override
  String get searchFilterMovies => 'أفلام';

  @override
  String get searchFilterSeries => 'مسلسلات';

  @override
  String get searchFilterPrograms => 'Programs';

  @override
  String get searchEmptyHint =>
      'Search for channels, movies, series, or programs';

  @override
  String get searchRecentSearches => 'Recent Searches';

  @override
  String get searchClearAll => 'Clear All';

  @override
  String get searchRemoveFromHistory => 'Remove from history';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get homeWhatsOn => 'ماذا يعرض الآن';

  @override
  String get homeContinueWatching => 'متابعة المشاهدة';

  @override
  String get homeRecentChannels => 'القنوات الأخيرة';

  @override
  String get homeMyList => 'قائمتي';

  @override
  String get homeQuickAccess => 'الوصول السريع';

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get favoritesEmpty => 'لا توجد مفضلة بعد';

  @override
  String get favoritesAddSome => 'أضف قنوات أو أفلاماً أو مسلسلات إلى مفضلتك';

  @override
  String get profilesTitle => 'الملفات الشخصية';

  @override
  String get profilesCreate => 'إنشاء ملف شخصي';

  @override
  String get profilesEdit => 'تعديل الملف الشخصي';

  @override
  String get profilesDelete => 'حذف الملف الشخصي';

  @override
  String get profilesManage => 'إدارة الملفات الشخصية';

  @override
  String get profilesWhoIsWatching => 'من يشاهد؟';

  @override
  String get onboardingWelcome => 'مرحباً بك في CrispyTivi';

  @override
  String get onboardingAddSource => 'أضف مصدرك الأول';

  @override
  String get onboardingChooseType => 'اختر نوع المصدر';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'جارٍ الاتصال وتحميل القنوات…';

  @override
  String get onboardingDone => 'تم الإعداد!';

  @override
  String get onboardingStartWatching => 'ابدأ المشاهدة';

  @override
  String get cloudSyncTitle => 'المزامنة السحابية';

  @override
  String get cloudSyncSignInGoogle => 'تسجيل الدخول بحساب Google';

  @override
  String get cloudSyncSignOut => 'تسجيل الخروج';

  @override
  String cloudSyncLastSync(String time) {
    return 'آخر مزامنة: $time';
  }

  @override
  String get cloudSyncNever => 'أبداً';

  @override
  String get cloudSyncConflict => 'تعارض في المزامنة';

  @override
  String get cloudSyncKeepLocal => 'الاحتفاظ بالنسخة المحلية';

  @override
  String get cloudSyncKeepRemote => 'الاحتفاظ بالنسخة البعيدة';

  @override
  String get castTitle => 'البث إلى جهاز';

  @override
  String get castSearching => 'جارٍ البحث عن أجهزة…';

  @override
  String get castNoDevices => 'لم يتم العثور على أجهزة';

  @override
  String get castDisconnect => 'قطع الاتصال';

  @override
  String get multiviewTitle => 'عرض متعدد';

  @override
  String get multiviewAddStream => 'إضافة بث';

  @override
  String get multiviewRemoveStream => 'إزالة بث';

  @override
  String get multiviewSaveLayout => 'حفظ التخطيط';

  @override
  String get multiviewLoadLayout => 'تحميل التخطيط';

  @override
  String get multiviewLayoutName => 'اسم التخطيط';

  @override
  String get multiviewDeleteLayout => 'حذف التخطيط';

  @override
  String get mediaServerUrl => 'عنوان URL للخادم';

  @override
  String get mediaServerUsername => 'اسم المستخدم';

  @override
  String get mediaServerPassword => 'كلمة المرور';

  @override
  String get mediaServerSignIn => 'تسجيل الدخول';

  @override
  String get mediaServerConnecting => 'جارٍ الاتصال…';

  @override
  String get mediaServerConnectionFailed => 'فشل الاتصال';

  @override
  String onboardingChannelsLoaded(int count) {
    return 'تم تحميل $count قناة!';
  }

  @override
  String get onboardingEnterApp => 'الدخول إلى التطبيق';

  @override
  String get onboardingEnterAppLabel => 'الدخول إلى التطبيق';

  @override
  String get onboardingCouldNotConnect => 'تعذّر الاتصال';

  @override
  String get onboardingRetryLabel => 'إعادة محاولة الاتصال';

  @override
  String get onboardingEditSource => 'تعديل تفاصيل المصدر';

  @override
  String get playerAudioSectionLabel => 'الصوت';

  @override
  String get playerSubtitlesSectionLabel => 'الترجمة';

  @override
  String get playerSwitchProfileTitle => 'تبديل الملف الشخصي';

  @override
  String get playerCopyStreamUrl => 'نسخ رابط البث';

  @override
  String get cloudSyncSyncing => 'جارٍ المزامنة…';

  @override
  String get cloudSyncNow => 'مزامنة الآن';

  @override
  String get cloudSyncForceUpload => 'رفع إجباري';

  @override
  String get cloudSyncForceDownload => 'تنزيل إجباري';

  @override
  String get cloudSyncAutoSync => 'مزامنة تلقائية';

  @override
  String get cloudSyncThisDevice => 'هذا الجهاز';

  @override
  String get cloudSyncCloud => 'السحابة';

  @override
  String get cloudSyncNewer => 'أحدث';

  @override
  String get contextMenuAddFavorite => 'إضافة إلى المفضلة';

  @override
  String get contextMenuRemoveFavorite => 'إزالة من المفضلة';

  @override
  String get contextMenuSwitchStream => 'تبديل مصدر البث';

  @override
  String get contextMenuCopyUrl => 'نسخ رابط البث';

  @override
  String get contextMenuOpenExternal => 'تشغيل في مشغل خارجي';

  @override
  String get contextMenuPlay => 'تشغيل';

  @override
  String get contextMenuAddFavoriteCategory => 'إضافة إلى فئات المفضلة';

  @override
  String get contextMenuRemoveFavoriteCategory => 'إزالة من فئات المفضلة';

  @override
  String get contextMenuFilterCategory => 'تصفية حسب هذه الفئة';

  @override
  String get confirmDeleteCancel => 'إلغاء';

  @override
  String get confirmDeleteAction => 'حذف';
}
