// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonSomethingWentWrong => 'Что-то пошло не так';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonSubmit => 'Отправить';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonAll => 'Все';

  @override
  String get commonOn => 'Вкл';

  @override
  String get commonOff => 'Выкл';

  @override
  String get commonAuto => 'Авто';

  @override
  String get commonNone => 'Нет';

  @override
  String commonError(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get commonOr => 'или';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonPlay => 'Воспроизвести';

  @override
  String get commonPause => 'Пауза';

  @override
  String get commonLoading => 'Загрузка...';

  @override
  String get commonGoToSettings => 'Перейти в настройки';

  @override
  String get commonNew => 'НОВОЕ';

  @override
  String get commonLive => 'ПРЯМОЙ ЭФИР';

  @override
  String get commonFavorites => 'Избранное';

  @override
  String get keyboardShortcuts => 'Горячие клавиши';

  @override
  String get navHome => 'Главная';

  @override
  String get navSearch => 'Поиск';

  @override
  String get navLiveTv => 'Прямой эфир';

  @override
  String get navGuide => 'Программа';

  @override
  String get navMovies => 'Фильмы';

  @override
  String get navSeries => 'Сериалы';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Избранное';

  @override
  String get navSettings => 'Настройки';

  @override
  String get breadcrumbProfiles => 'Профили';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'Облако';

  @override
  String get breadcrumbMultiView => 'Multi-View';

  @override
  String get breadcrumbDetail => 'Подробности';

  @override
  String get breadcrumbNavigateToParent => 'Перейти к родительскому элементу';

  @override
  String get sideNavSwitchProfile => 'Сменить профиль';

  @override
  String get sideNavManageProfiles => 'Управление профилями';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Сменить профиль: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'Введите PIN для $name';
  }

  @override
  String get sideNavActive => 'активный';

  @override
  String get sideNavPinProtected => 'Защищён PIN-кодом';

  @override
  String get fabWhatsOn => 'Сейчас в эфире';

  @override
  String get fabRandomPick => 'Случайный выбор';

  @override
  String get fabLastChannel => 'Последний канал';

  @override
  String get fabSchedule => 'Расписание';

  @override
  String get fabNewList => 'Новый список';

  @override
  String get offlineNoConnection => 'Нет соединения';

  @override
  String get offlineConnectionRestored => 'Соединение восстановлено';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Страница не найдена';

  @override
  String get pinConfirmPin => 'Подтвердите PIN';

  @override
  String get pinEnterAllDigits => 'Введите все 4 цифры';

  @override
  String get pinDoNotMatch => 'PIN-коды не совпадают';

  @override
  String get pinTooManyAttempts => 'Слишком много неверных попыток.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Повторите через $countdown';
  }

  @override
  String get pinEnterSameAgain =>
      'Введите тот же PIN ещё раз для подтверждения';

  @override
  String get pinUseBiometric => 'Использовать отпечаток пальца или лицо';

  @override
  String pinDigitN(int n) {
    return 'Цифра PIN $n';
  }

  @override
  String get pinIncorrect => 'Неверный PIN';

  @override
  String get pinVerificationFailed => 'Проверка не пройдена';

  @override
  String get pinBiometricFailed =>
      'Биометрическая аутентификация не удалась или отменена';

  @override
  String get contextMenuRemoveFromFavorites => 'Удалить из избранного';

  @override
  String get contextMenuAddToFavorites => 'Добавить в избранное';

  @override
  String get contextMenuSwitchStreamSource => 'Сменить источник потока';

  @override
  String get contextMenuSmartGroup => 'Умная группа';

  @override
  String get contextMenuMultiView => 'Multi-View';

  @override
  String get contextMenuAssignEpg => 'Назначить EPG';

  @override
  String get contextMenuHideChannel => 'Скрыть канал';

  @override
  String get contextMenuCopyStreamUrl => 'Копировать URL потока';

  @override
  String get contextMenuPlayExternal => 'Открыть во внешнем плеере';

  @override
  String get contextMenuBlockChannel => 'Заблокировать канал';

  @override
  String get contextMenuViewDetails => 'Просмотреть сведения';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Удалить из избранных категорий';

  @override
  String get contextMenuAddToFavoriteCategories =>
      'Добавить в избранные категории';

  @override
  String get contextMenuFilterByCategory => 'Фильтровать по этой категории';

  @override
  String get contextMenuCloseContextMenu => 'Закрыть контекстное меню';

  @override
  String get sourceAllSources => 'Все источники';

  @override
  String sourceFilterLabel(String label) {
    return 'Фильтр источника: $label';
  }

  @override
  String get categoryLabel => 'Категория';

  @override
  String categoryAll(String label) {
    return 'Все $label';
  }

  @override
  String categorySelect(String label) {
    return 'Выбрать $label';
  }

  @override
  String get categorySearchHint => 'Поиск категорий…';

  @override
  String get categorySearchLabel => 'Поиск категорий';

  @override
  String get categoryRemoveFromFavorites => 'Удалить из избранных категорий';

  @override
  String get categoryAddToFavorites => 'Добавить в избранные категории';

  @override
  String get sidebarExpandSidebar => 'Развернуть боковую панель';

  @override
  String get sidebarCollapseSidebar => 'Свернуть боковую панель';

  @override
  String get badgeNewEpisode => 'НОВЫЙ ЭП.';

  @override
  String get badgeNewSeason => 'НОВЫЙ СЕЗОН';

  @override
  String get badgeRecording => 'ЗАПИСЬ';

  @override
  String get badgeExpiring => 'ИСТЕКАЕТ';

  @override
  String get toggleFavorite => 'В избранное';

  @override
  String get playerSkipBack => 'Назад на 10 секунд';

  @override
  String get playerSkipForward => 'Вперёд на 10 секунд';

  @override
  String get playerChannels => 'Каналы';

  @override
  String get playerRecordings => 'Записи';

  @override
  String get playerCloseGuide => 'Закрыть программу (G)';

  @override
  String get playerTvGuide => 'ТВ-программа (G)';

  @override
  String get playerAudioSubtitles => 'Аудио и субтитры';

  @override
  String get playerNoTracksAvailable => 'Дорожки недоступны';

  @override
  String get playerExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get playerFullscreen => 'Полный экран';

  @override
  String get playerUnlockScreen => 'Разблокировать экран';

  @override
  String get playerLockScreen => 'Заблокировать экран';

  @override
  String get playerStreamQuality => 'Качество потока';

  @override
  String get playerRotationLock => 'Блокировка поворота';

  @override
  String get playerScreenBrightness => 'Яркость экрана';

  @override
  String get playerShaderPreset => 'Шейдерный пресет';

  @override
  String get playerAutoSystem => 'Авто (системное)';

  @override
  String get playerResetToAuto => 'Сбросить до авто';

  @override
  String get playerPortrait => 'Портретный';

  @override
  String get playerPortraitUpsideDown => 'Портретный (перевёрнутый)';

  @override
  String get playerLandscapeLeft => 'Альбомный влево';

  @override
  String get playerLandscapeRight => 'Альбомный вправо';

  @override
  String get playerDeinterlaceAuto => 'Авто';

  @override
  String get playerMoreOptions => 'Ещё параметры';

  @override
  String get playerRemoveFavorite => 'Удалить из избранного';

  @override
  String get playerAddFavorite => 'Добавить в избранное';

  @override
  String get playerAudioTrack => 'Аудиодорожка';

  @override
  String playerAspectRatio(String label) {
    return 'Соотношение сторон ($label)';
  }

  @override
  String get playerRefreshStream => 'Обновить поток';

  @override
  String get playerStreamInfo => 'Сведения о потоке';

  @override
  String get playerPip => 'Картинка в картинке';

  @override
  String get playerSleepTimer => 'Таймер сна';

  @override
  String get playerExternalPlayer => 'Внешний плеер';

  @override
  String get playerSearchChannels => 'Поиск каналов';

  @override
  String get playerChannelList => 'Список каналов';

  @override
  String get playerScreenshot => 'Снимок экрана';

  @override
  String playerStreamQualityOption(String label) {
    return 'Качество потока ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Деинтерлейсинг ($mode)';
  }

  @override
  String get playerSyncOffset => 'Смещение синхронизации';

  @override
  String playerAudioPassthrough(String state) {
    return 'Аудио транзит ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Устройство вывода звука';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Поверх всех окон ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Шейдеры ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'АУДИО';

  @override
  String get playerSubtitlesSectionSubtitles => 'СУБТИТРЫ';

  @override
  String get playerSubtitlesSecondHint => '(долгое нажатие = 2-я)';

  @override
  String get playerSubtitlesCcStyle => 'Стиль субтитров';

  @override
  String get playerSyncOffsetAudio => 'Аудио';

  @override
  String get playerSyncOffsetSubtitle => 'Субтитры';

  @override
  String get playerSyncOffsetResetToZero => 'Сбросить до 0';

  @override
  String get playerNoAudioDevices => 'Аудиоустройства не найдены.';

  @override
  String get playerSpeedLive => 'Скорость (прямой эфир)';

  @override
  String get playerSpeed => 'Скорость';

  @override
  String get playerVolumeLabel => 'Громкость';

  @override
  String playerVolumePercent(int percent) {
    return 'Громкость $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Сменить профиль ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return 'Осталось $duration';
  }

  @override
  String get playerSubtitleFontWeight => 'НАСЫЩЕННОСТЬ ШРИФТА';

  @override
  String get playerSubtitleBold => 'Жирный';

  @override
  String get playerSubtitleNormal => 'Обычный';

  @override
  String get playerSubtitleFontSize => 'РАЗМЕР ШРИФТА';

  @override
  String playerSubtitlePosition(int value) {
    return 'ПОЛОЖЕНИЕ ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'ЦВЕТ ТЕКСТА';

  @override
  String get playerSubtitleOutlineColor => 'ЦВЕТ КОНТУРА';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'ТОЛЩИНА КОНТУРА ($value)';
  }

  @override
  String get playerSubtitleBackground => 'ФОН';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'ПРОЗРАЧНОСТЬ ФОНА ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'ТЕНЬ';

  @override
  String get playerSubtitlePreview => 'ПРЕДПРОСМОТР';

  @override
  String get playerSubtitleSampleText => 'Пример текста субтитров';

  @override
  String get playerSubtitleResetDefaults => 'Сбросить до стандартных';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Остановка через $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Отменить таймер';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes минут';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Установить таймер сна на $minutes минут';
  }

  @override
  String get playerStreamStats => 'Статистика потока';

  @override
  String get playerStreamStatsBuffer => 'Буфер';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Скопировано!';

  @override
  String get playerStreamStatsCopy => 'Копировать статистику';

  @override
  String get playerStreamStatsInterlaced => 'Чересстрочный';

  @override
  String playerNextUpIn(int seconds) {
    return 'Следующий через $seconds с';
  }

  @override
  String get playerPlayNow => 'Смотреть сейчас';

  @override
  String get playerFinished => 'Просмотр завершён';

  @override
  String get playerWatchAgain => 'Смотреть снова';

  @override
  String get playerBrowseMore => 'Смотреть ещё';

  @override
  String get playerShortcutsTitle => 'Горячие клавиши';

  @override
  String get playerShortcutsCloseEsc => 'Закрыть (Esc)';

  @override
  String get playerShortcutsPlayback => 'Воспроизведение';

  @override
  String get playerShortcutsPlayPause => 'Воспроизведение / Пауза';

  @override
  String get playerShortcutsSeek => 'Перемотка ±10 с';

  @override
  String get playerShortcutsSpeedStep => 'Скорость −/+ шаг';

  @override
  String get playerShortcutsSpeedFine => 'Скорость −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => 'Перейти к % (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Кадр ±1';

  @override
  String get playerShortcutsAspectRatio => 'Переключить соотношение сторон';

  @override
  String get playerShortcutsCycleSubtitles => 'Переключить субтитры';

  @override
  String get playerShortcutsVolume => 'Громкость';

  @override
  String get playerShortcutsVolumeAdjust => 'Громкость ±10 %';

  @override
  String get playerShortcutsMute => 'Вкл/выкл звук';

  @override
  String get playerShortcutsDisplay => 'Экран';

  @override
  String get playerShortcutsFullscreenToggle => 'Переключить полный экран';

  @override
  String get playerShortcutsExitFullscreen => 'Выйти из полного экрана / назад';

  @override
  String get playerShortcutsStreamInfo => 'Сведения о потоке';

  @override
  String get playerShortcutsLiveTv => 'Прямой эфир';

  @override
  String get playerShortcutsChannelUp => 'Канал вверх';

  @override
  String get playerShortcutsChannelDown => 'Канал вниз';

  @override
  String get playerShortcutsChannelList => 'Список каналов';

  @override
  String get playerShortcutsToggleZap => 'Переключить оверлей каналов';

  @override
  String get playerShortcutsGeneral => 'Общие';

  @override
  String get playerShortcutsSubtitlesCc => 'Субтитры / CC';

  @override
  String get playerShortcutsScreenLock => 'Блокировка экрана';

  @override
  String get playerShortcutsThisHelp => 'Этот экран помощи';

  @override
  String get playerShortcutsEscToClose => 'Нажмите Esc или ? для закрытия';

  @override
  String get playerZapChannels => 'Каналы';

  @override
  String get playerBookmark => 'Закладка';

  @override
  String get playerEditBookmark => 'Редактировать закладку';

  @override
  String get playerBookmarkLabelHint => 'Название закладки (необязательно)';

  @override
  String get playerBookmarkLabelInput => 'Название закладки';

  @override
  String playerBookmarkAdded(String label) {
    return 'Закладка добавлена: $label';
  }

  @override
  String get playerExpandToFullscreen => 'Развернуть на весь экран';

  @override
  String get playerUnmute => 'Включить звук';

  @override
  String get playerMute => 'Выключить звук';

  @override
  String get playerStopPlayback => 'Остановить воспроизведение';

  @override
  String get playerQueueUpNext => 'Далее';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Эпизоды сезона $number';
  }

  @override
  String get playerQueueEpisodes => 'Эпизоды';

  @override
  String get playerQueueEmpty => 'Очередь пуста';

  @override
  String get playerQueueClose => 'Закрыть очередь';

  @override
  String get playerQueueOpen => 'Очередь';

  @override
  String playerEpisodeNumber(String number) {
    return 'Эпизод $number';
  }

  @override
  String get playerScreenLocked => 'Экран заблокирован';

  @override
  String get playerHoldToUnlock => 'Удерживайте для разблокировки';

  @override
  String get playerScreenshotSaved => 'Снимок экрана сохранён';

  @override
  String get playerScreenshotFailed => 'Не удалось сделать снимок экрана';

  @override
  String get playerSkipSegment => 'Пропустить сегмент';

  @override
  String playerSkipType(String type) {
    return 'Пропустить $type';
  }

  @override
  String get playerCouldNotOpenExternal => 'Не удалось открыть внешний плеер';

  @override
  String get playerExitMultiView => 'Выйти из Multi-View';

  @override
  String get playerScreensaverBouncingLogo => 'Прыгающий логотип';

  @override
  String get playerScreensaverClock => 'Часы';

  @override
  String get playerScreensaverBlackScreen => 'Чёрный экран';

  @override
  String get streamProfileAuto => 'Авто';

  @override
  String get streamProfileAutoDesc => 'Автоматическое качество по сети';

  @override
  String get streamProfileLow => 'Низкое';

  @override
  String get streamProfileLowDesc => 'SD качество, макс. ~1 Мбит/с';

  @override
  String get streamProfileMedium => 'Среднее';

  @override
  String get streamProfileMediumDesc => 'HD качество, макс. ~3 Мбит/с';

  @override
  String get streamProfileHigh => 'Высокое';

  @override
  String get streamProfileHighDesc => 'Full HD качество, макс. ~8 Мбит/с';

  @override
  String get streamProfileMaximum => 'Максимальное';

  @override
  String get streamProfileMaximumDesc =>
      'Лучшее доступное качество без ограничений';

  @override
  String get segmentIntro => 'Вступление';

  @override
  String get segmentOutro => 'Финальные титры';

  @override
  String get segmentRecap => 'Ранее в серии';

  @override
  String get segmentCommercial => 'Реклама';

  @override
  String get segmentPreview => 'Предпросмотр';

  @override
  String get segmentSkipNone => 'Нет';

  @override
  String get segmentSkipAsk => 'Спросить';

  @override
  String get segmentSkipOnce => 'Пропустить однажды';

  @override
  String get segmentSkipAlways => 'Пропускать всегда';

  @override
  String get nextUpOff => 'Выкл';

  @override
  String get nextUpStatic => 'Статичный (за 32 с до конца)';

  @override
  String get nextUpSmart => 'Умный (с учётом титров)';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSearchSettings => 'Поиск настроек';

  @override
  String get settingsGeneral => 'Основные';

  @override
  String get settingsSources => 'Источники';

  @override
  String get settingsPlayback => 'Воспроизведение';

  @override
  String get settingsData => 'Данные';

  @override
  String get settingsAdvanced => 'Дополнительно';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Системный по умолчанию';

  @override
  String get settingsAboutVersion => 'Версия';

  @override
  String get settingsAboutUpdates => 'Обновления';

  @override
  String get settingsAboutCheckForUpdates => 'Проверить обновления';

  @override
  String get settingsAboutUpToDate => 'У вас последняя версия';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Доступно обновление: $version';
  }

  @override
  String get settingsAboutLicenses => 'Лицензии';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsAccentColor => 'Акцентный цвет';

  @override
  String get settingsTextScale => 'Масштаб текста';

  @override
  String get settingsDensity => 'Плотность';

  @override
  String get settingsBackup => 'Резервное копирование и восстановление';

  @override
  String get settingsBackupCreate => 'Создать резервную копию';

  @override
  String get settingsBackupRestore => 'Восстановить резервную копию';

  @override
  String get settingsBackupAuto => 'Автоматическое резервное копирование';

  @override
  String get settingsBackupCloudSync => 'Облачная синхронизация';

  @override
  String get settingsParentalControls => 'Родительский контроль';

  @override
  String get settingsParentalSetPin => 'Установить PIN';

  @override
  String get settingsParentalChangePin => 'Изменить PIN';

  @override
  String get settingsParentalRemovePin => 'Удалить PIN';

  @override
  String get settingsParentalBlockedCategories => 'Заблокированные категории';

  @override
  String get settingsNetwork => 'Сеть';

  @override
  String get settingsNetworkDiagnostics => 'Диагностика сети';

  @override
  String get settingsNetworkProxy => 'Прокси';

  @override
  String get settingsPlaybackHardwareDecoder => 'Аппаратный декодер';

  @override
  String get settingsPlaybackBufferSize => 'Размер буфера';

  @override
  String get settingsPlaybackDeinterlace => 'Деинтерлейсинг';

  @override
  String get settingsPlaybackUpscaling => 'Апскейлинг';

  @override
  String get settingsPlaybackAudioOutput => 'Аудиовыход';

  @override
  String get settingsPlaybackLoudnessNorm => 'Нормализация громкости';

  @override
  String get settingsPlaybackVolumeBoost => 'Усиление громкости';

  @override
  String get settingsPlaybackAudioPassthrough => 'Аудио транзит';

  @override
  String get settingsPlaybackSegmentSkip => 'Пропуск сегментов';

  @override
  String get settingsPlaybackNextUp => 'Следующий эпизод';

  @override
  String get settingsPlaybackScreensaver => 'Экранная заставка';

  @override
  String get settingsPlaybackExternalPlayer => 'Внешний плеер';

  @override
  String get settingsSourceAdd => 'Добавить источник';

  @override
  String get settingsSourceEdit => 'Редактировать источник';

  @override
  String get settingsSourceDelete => 'Удалить источник';

  @override
  String get settingsSourceSync => 'Синхронизировать';

  @override
  String get settingsSourceSortOrder => 'Порядок сортировки';

  @override
  String get settingsDataClearCache => 'Очистить кэш';

  @override
  String get settingsDataClearHistory => 'Очистить историю просмотров';

  @override
  String get settingsDataExport => 'Экспорт данных';

  @override
  String get settingsDataImport => 'Импорт данных';

  @override
  String get settingsAdvancedDebug => 'Режим отладки';

  @override
  String get settingsAdvancedStreamProxy => 'Прокси потока';

  @override
  String get settingsAdvancedAutoUpdate => 'Автообновление';

  @override
  String get iptvMultiView => 'Multi-View';

  @override
  String get iptvTvGuide => 'ТВ-программа';

  @override
  String get iptvBackToGroups => 'Вернуться к группам';

  @override
  String get iptvSearchChannels => 'Поиск каналов';

  @override
  String get iptvListGridView => 'Вид списком';

  @override
  String get iptvGridView => 'Вид сеткой';

  @override
  String iptvChannelHidden(String name) {
    return '$name скрыт';
  }

  @override
  String get iptvSortDone => 'Готово';

  @override
  String get iptvSortResetToDefault => 'Сбросить до стандартного';

  @override
  String get iptvSortByPlaylistOrder => 'По порядку плейлиста';

  @override
  String get iptvSortByName => 'По названию';

  @override
  String get iptvSortByRecent => 'По недавним';

  @override
  String get iptvSortByPopularity => 'По популярности';

  @override
  String get epgNowPlaying => 'Сейчас';

  @override
  String get epgNoData => 'Данные EPG недоступны';

  @override
  String get epgSetReminder => 'Установить напоминание';

  @override
  String get epgCancelReminder => 'Отменить напоминание';

  @override
  String get epgRecord => 'Записать';

  @override
  String get epgCancelRecording => 'Отменить запись';

  @override
  String get vodMovies => 'Фильмы';

  @override
  String get vodSeries => 'Сериалы';

  @override
  String vodSeasonN(int number) {
    return 'Сезон $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Эпизод $number';
  }

  @override
  String get vodWatchNow => 'Смотреть сейчас';

  @override
  String get vodResume => 'Продолжить';

  @override
  String get vodContinueWatching => 'Продолжить просмотр';

  @override
  String get vodRecommended => 'Рекомендуемое';

  @override
  String get vodRecentlyAdded => 'Недавно добавленное';

  @override
  String get vodNoItems => 'Ничего не найдено';

  @override
  String get dvrSchedule => 'Расписание';

  @override
  String get dvrRecordings => 'Записи';

  @override
  String get dvrScheduleRecording => 'Запланировать запись';

  @override
  String get dvrEditRecording => 'Редактировать запись';

  @override
  String get dvrDeleteRecording => 'Удалить запись';

  @override
  String get dvrNoRecordings => 'Нет записей';

  @override
  String get searchTitle => 'Поиск';

  @override
  String get searchHint => 'Поиск каналов, фильмов, сериалов…';

  @override
  String get searchNoResults => 'Результаты не найдены';

  @override
  String get searchFilterAll => 'Все';

  @override
  String get searchFilterChannels => 'Каналы';

  @override
  String get searchFilterMovies => 'Фильмы';

  @override
  String get searchFilterSeries => 'Сериалы';

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
  String get homeWhatsOn => 'Сейчас в эфире';

  @override
  String get homeContinueWatching => 'Продолжить просмотр';

  @override
  String get homeRecentChannels => 'Недавние каналы';

  @override
  String get homeMyList => 'Мой список';

  @override
  String get homeQuickAccess => 'Быстрый доступ';

  @override
  String get favoritesTitle => 'Избранное';

  @override
  String get favoritesEmpty => 'Пока нет избранного';

  @override
  String get favoritesAddSome =>
      'Добавьте каналы, фильмы или сериалы в избранное';

  @override
  String get profilesTitle => 'Профили';

  @override
  String get profilesCreate => 'Создать профиль';

  @override
  String get profilesEdit => 'Редактировать профиль';

  @override
  String get profilesDelete => 'Удалить профиль';

  @override
  String get profilesManage => 'Управление профилями';

  @override
  String get profilesWhoIsWatching => 'Кто смотрит?';

  @override
  String get onboardingWelcome => 'Добро пожаловать в CrispyTivi';

  @override
  String get onboardingAddSource => 'Добавьте первый источник';

  @override
  String get onboardingChooseType => 'Выберите тип источника';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Подключение и загрузка каналов…';

  @override
  String get onboardingDone => 'Всё готово!';

  @override
  String get onboardingStartWatching => 'Начать просмотр';

  @override
  String get cloudSyncTitle => 'Облачная синхронизация';

  @override
  String get cloudSyncSignInGoogle => 'Войти через Google';

  @override
  String get cloudSyncSignOut => 'Выйти';

  @override
  String cloudSyncLastSync(String time) {
    return 'Последняя синхронизация: $time';
  }

  @override
  String get cloudSyncNever => 'Никогда';

  @override
  String get cloudSyncConflict => 'Конфликт синхронизации';

  @override
  String get cloudSyncKeepLocal => 'Оставить локальные данные';

  @override
  String get cloudSyncKeepRemote => 'Оставить данные из облака';

  @override
  String get castTitle => 'Трансляция';

  @override
  String get castSearching => 'Поиск устройств…';

  @override
  String get castNoDevices => 'Устройства не найдены';

  @override
  String get castDisconnect => 'Отключить';

  @override
  String get multiviewTitle => 'Multi-View';

  @override
  String get multiviewAddStream => 'Добавить поток';

  @override
  String get multiviewRemoveStream => 'Удалить поток';

  @override
  String get multiviewSaveLayout => 'Сохранить раскладку';

  @override
  String get multiviewLoadLayout => 'Загрузить раскладку';

  @override
  String get multiviewLayoutName => 'Название раскладки';

  @override
  String get multiviewDeleteLayout => 'Удалить раскладку';

  @override
  String get mediaServerUrl => 'URL сервера';

  @override
  String get mediaServerUsername => 'Имя пользователя';

  @override
  String get mediaServerPassword => 'Пароль';

  @override
  String get mediaServerSignIn => 'Войти';

  @override
  String get mediaServerConnecting => 'Подключение…';

  @override
  String get mediaServerConnectionFailed => 'Ошибка подключения';

  @override
  String onboardingChannelsLoaded(int count) {
    return 'Загружено каналов: $count!';
  }

  @override
  String get onboardingEnterApp => 'Войти в приложение';

  @override
  String get onboardingEnterAppLabel => 'Войти в приложение';

  @override
  String get onboardingCouldNotConnect => 'Не удалось подключиться';

  @override
  String get onboardingRetryLabel => 'Повторить подключение';

  @override
  String get onboardingEditSource => 'Редактировать параметры источника';

  @override
  String get playerAudioSectionLabel => 'АУДИО';

  @override
  String get playerSubtitlesSectionLabel => 'СУБТИТРЫ';

  @override
  String get playerSwitchProfileTitle => 'Сменить профиль';

  @override
  String get playerCopyStreamUrl => 'Копировать URL потока';

  @override
  String get cloudSyncSyncing => 'Синхронизация…';

  @override
  String get cloudSyncNow => 'Синхронизировать';

  @override
  String get cloudSyncForceUpload => 'Принудительно загрузить';

  @override
  String get cloudSyncForceDownload => 'Принудительно скачать';

  @override
  String get cloudSyncAutoSync => 'Автосинхронизация';

  @override
  String get cloudSyncThisDevice => 'Это устройство';

  @override
  String get cloudSyncCloud => 'Облако';

  @override
  String get cloudSyncNewer => 'НОВЕЕ';

  @override
  String get contextMenuAddFavorite => 'Добавить в избранное';

  @override
  String get contextMenuRemoveFavorite => 'Удалить из избранного';

  @override
  String get contextMenuSwitchStream => 'Сменить источник потока';

  @override
  String get contextMenuCopyUrl => 'Копировать URL потока';

  @override
  String get contextMenuOpenExternal => 'Открыть во внешнем плеере';

  @override
  String get contextMenuPlay => 'Воспроизвести';

  @override
  String get contextMenuAddFavoriteCategory => 'Добавить в избранные категории';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Удалить из избранных категорий';

  @override
  String get contextMenuFilterCategory => 'Фильтровать по этой категории';

  @override
  String get confirmDeleteCancel => 'Отмена';

  @override
  String get confirmDeleteAction => 'Удалить';
}
