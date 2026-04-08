// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonSomethingWentWrong => 'Algo salió mal';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSubmit => 'Enviar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonAll => 'Todo';

  @override
  String get commonOn => 'Activado';

  @override
  String get commonOff => 'Desactivado';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonNone => 'Ninguno';

  @override
  String commonError(String message) {
    return 'Error: $message';
  }

  @override
  String get commonOr => 'o';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonPlay => 'Reproducir';

  @override
  String get commonPause => 'Pausar';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonGoToSettings => 'Ir a Configuración';

  @override
  String get commonNew => 'NUEVO';

  @override
  String get commonLive => 'EN VIVO';

  @override
  String get commonFavorites => 'Favoritos';

  @override
  String get keyboardShortcuts => 'Atajos de teclado';

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLiveTv => 'TV en Vivo';

  @override
  String get navGuide => 'Guía';

  @override
  String get navMovies => 'Películas';

  @override
  String get navSeries => 'Series';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navSettings => 'Configuración';

  @override
  String get breadcrumbProfiles => 'Perfiles';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'Nube';

  @override
  String get breadcrumbMultiView => 'Multi-Vista';

  @override
  String get breadcrumbDetail => 'Detalle';

  @override
  String get breadcrumbNavigateToParent => 'Ir al nivel superior';

  @override
  String get sideNavSwitchProfile => 'Cambiar Perfil';

  @override
  String get sideNavManageProfiles => 'Administrar perfiles';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Cambiar perfil: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'Ingresar PIN de $name';
  }

  @override
  String get sideNavActive => 'activo';

  @override
  String get sideNavPinProtected => 'Protegido con PIN';

  @override
  String get fabWhatsOn => '¿Qué hay ahora?';

  @override
  String get fabRandomPick => 'Elección Aleatoria';

  @override
  String get fabLastChannel => 'Último Canal';

  @override
  String get fabSchedule => 'Programación';

  @override
  String get fabNewList => 'Nueva Lista';

  @override
  String get offlineNoConnection => 'Sin conexión';

  @override
  String get offlineConnectionRestored => 'Conexión restaurada';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Página no encontrada';

  @override
  String get pinConfirmPin => 'Confirmar PIN';

  @override
  String get pinEnterAllDigits => 'Ingresa los 4 dígitos';

  @override
  String get pinDoNotMatch => 'Los PINs no coinciden';

  @override
  String get pinTooManyAttempts => 'Demasiados intentos incorrectos.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Intenta de nuevo en $countdown';
  }

  @override
  String get pinEnterSameAgain =>
      'Ingresa el mismo PIN otra vez para confirmar';

  @override
  String get pinUseBiometric => 'Usar huella digital o reconocimiento facial';

  @override
  String pinDigitN(int n) {
    return 'Dígito $n del PIN';
  }

  @override
  String get pinIncorrect => 'PIN incorrecto';

  @override
  String get pinVerificationFailed => 'Verificación fallida';

  @override
  String get pinBiometricFailed =>
      'Autenticación biométrica fallida o cancelada';

  @override
  String get contextMenuRemoveFromFavorites => 'Quitar de Favoritos';

  @override
  String get contextMenuAddToFavorites => 'Agregar a Favoritos';

  @override
  String get contextMenuSwitchStreamSource => 'Cambiar fuente de stream';

  @override
  String get contextMenuSmartGroup => 'Grupo Inteligente';

  @override
  String get contextMenuMultiView => 'Multi-Vista';

  @override
  String get contextMenuAssignEpg => 'Asignar EPG';

  @override
  String get contextMenuHideChannel => 'Ocultar canal';

  @override
  String get contextMenuCopyStreamUrl => 'Copiar URL del Stream';

  @override
  String get contextMenuPlayExternal => 'Reproducir en Reproductor Externo';

  @override
  String get contextMenuBlockChannel => 'Bloquear canal';

  @override
  String get contextMenuViewDetails => 'Ver detalles';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Quitar de Categorías Favoritas';

  @override
  String get contextMenuAddToFavoriteCategories =>
      'Agregar a Categorías Favoritas';

  @override
  String get contextMenuFilterByCategory => 'Filtrar por esta categoría';

  @override
  String get contextMenuCloseContextMenu => 'Cerrar menú contextual';

  @override
  String get sourceAllSources => 'Todas las Fuentes';

  @override
  String sourceFilterLabel(String label) {
    return 'Filtro de fuente $label';
  }

  @override
  String get categoryLabel => 'Categoría';

  @override
  String categoryAll(String label) {
    return 'Todo $label';
  }

  @override
  String categorySelect(String label) {
    return 'Seleccionar $label';
  }

  @override
  String get categorySearchHint => 'Buscar categorías…';

  @override
  String get categorySearchLabel => 'Buscar categorías';

  @override
  String get categoryRemoveFromFavorites => 'Quitar de categorías favoritas';

  @override
  String get categoryAddToFavorites => 'Agregar a categorías favoritas';

  @override
  String get sidebarExpandSidebar => 'Expandir barra lateral';

  @override
  String get sidebarCollapseSidebar => 'Contraer barra lateral';

  @override
  String get badgeNewEpisode => 'EP NUEVO';

  @override
  String get badgeNewSeason => 'NUEVA TEMPORADA';

  @override
  String get badgeRecording => 'REC';

  @override
  String get badgeExpiring => 'VENCE';

  @override
  String get toggleFavorite => 'Alternar favorito';

  @override
  String get playerSkipBack => 'Retroceder 10 segundos';

  @override
  String get playerSkipForward => 'Avanzar 10 segundos';

  @override
  String get playerChannels => 'Canales';

  @override
  String get playerRecordings => 'Grabaciones';

  @override
  String get playerCloseGuide => 'Cerrar Guía (G)';

  @override
  String get playerTvGuide => 'Guía de TV (G)';

  @override
  String get playerAudioSubtitles => 'Audio y Subtítulos';

  @override
  String get playerNoTracksAvailable => 'No hay pistas disponibles';

  @override
  String get playerExitFullscreen => 'Salir de Pantalla Completa';

  @override
  String get playerFullscreen => 'Pantalla Completa';

  @override
  String get playerUnlockScreen => 'Desbloquear Pantalla';

  @override
  String get playerLockScreen => 'Bloquear Pantalla';

  @override
  String get playerStreamQuality => 'Calidad del Stream';

  @override
  String get playerRotationLock => 'Bloqueo de Rotación';

  @override
  String get playerScreenBrightness => 'Brillo de Pantalla';

  @override
  String get playerShaderPreset => 'Preset de Shader';

  @override
  String get playerAutoSystem => 'Auto (Sistema)';

  @override
  String get playerResetToAuto => 'Restablecer a Auto';

  @override
  String get playerPortrait => 'Vertical';

  @override
  String get playerPortraitUpsideDown => 'Vertical (invertido)';

  @override
  String get playerLandscapeLeft => 'Horizontal izquierda';

  @override
  String get playerLandscapeRight => 'Horizontal derecha';

  @override
  String get playerDeinterlaceAuto => 'Auto';

  @override
  String get playerMoreOptions => 'Más opciones';

  @override
  String get playerRemoveFavorite => 'Quitar de Favoritos';

  @override
  String get playerAddFavorite => 'Agregar a Favoritos';

  @override
  String get playerAudioTrack => 'Pista de Audio';

  @override
  String playerAspectRatio(String label) {
    return 'Relación de Aspecto ($label)';
  }

  @override
  String get playerRefreshStream => 'Actualizar Stream';

  @override
  String get playerStreamInfo => 'Info del Stream';

  @override
  String get playerPip => 'Imagen en Imagen';

  @override
  String get playerSleepTimer => 'Temporizador de Apagado';

  @override
  String get playerExternalPlayer => 'Reproductor Externo';

  @override
  String get playerSearchChannels => 'Buscar Canales';

  @override
  String get playerChannelList => 'Lista de Canales';

  @override
  String get playerScreenshot => 'Captura de Pantalla';

  @override
  String playerStreamQualityOption(String label) {
    return 'Calidad del Stream ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Desentrelazado ($mode)';
  }

  @override
  String get playerSyncOffset => 'Ajuste de Sincronización';

  @override
  String playerAudioPassthrough(String state) {
    return 'Paso de Audio ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Dispositivo de Salida de Audio';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Siempre al Frente ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Shaders ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'AUDIO';

  @override
  String get playerSubtitlesSectionSubtitles => 'SUBTÍTULOS';

  @override
  String get playerSubtitlesSecondHint => '(pulsación larga = 2°)';

  @override
  String get playerSubtitlesCcStyle => 'Estilo de Subtítulos';

  @override
  String get playerSyncOffsetAudio => 'Audio';

  @override
  String get playerSyncOffsetSubtitle => 'Subtítulo';

  @override
  String get playerSyncOffsetResetToZero => 'Restablecer a 0';

  @override
  String get playerNoAudioDevices => 'No se encontraron dispositivos de audio.';

  @override
  String get playerSpeedLive => 'Velocidad (en vivo)';

  @override
  String get playerSpeed => 'Velocidad';

  @override
  String get playerVolumeLabel => 'Volumen';

  @override
  String playerVolumePercent(int percent) {
    return 'Volumen $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Cambiar perfil ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '$duration restante';
  }

  @override
  String get playerSubtitleFontWeight => 'GROSOR DE FUENTE';

  @override
  String get playerSubtitleBold => 'Negrita';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'TAMAÑO DE FUENTE';

  @override
  String playerSubtitlePosition(int value) {
    return 'POSICIÓN ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'COLOR DE TEXTO';

  @override
  String get playerSubtitleOutlineColor => 'COLOR DE CONTORNO';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'TAMAÑO DE CONTORNO ($value)';
  }

  @override
  String get playerSubtitleBackground => 'FONDO';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'OPACIDAD DEL FONDO ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'SOMBRA';

  @override
  String get playerSubtitlePreview => 'VISTA PREVIA';

  @override
  String get playerSubtitleSampleText => 'Texto de subtítulo de muestra';

  @override
  String get playerSubtitleResetDefaults =>
      'Restablecer valores predeterminados';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Se detiene en $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Cancelar Temporizador';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes minutos';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Establecer temporizador en $minutes minutos';
  }

  @override
  String get playerStreamStats => 'Estadísticas del Stream';

  @override
  String get playerStreamStatsBuffer => 'Búfer';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => '¡Copiado!';

  @override
  String get playerStreamStatsCopy => 'Copiar estadísticas';

  @override
  String get playerStreamStatsInterlaced => 'Entrelazado';

  @override
  String playerNextUpIn(int seconds) {
    return 'Próximo en $seconds';
  }

  @override
  String get playerPlayNow => 'Reproducir Ahora';

  @override
  String get playerFinished => 'Finalizado';

  @override
  String get playerWatchAgain => 'Ver de Nuevo';

  @override
  String get playerBrowseMore => 'Explorar Más';

  @override
  String get playerShortcutsTitle => 'Atajos de Teclado';

  @override
  String get playerShortcutsCloseEsc => 'Cerrar (Esc)';

  @override
  String get playerShortcutsPlayback => 'Reproducción';

  @override
  String get playerShortcutsPlayPause => 'Reproducir / Pausar';

  @override
  String get playerShortcutsSeek => 'Buscar ±10 s';

  @override
  String get playerShortcutsSpeedStep => 'Velocidad paso −/+';

  @override
  String get playerShortcutsSpeedFine => 'Velocidad −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => 'Saltar a % (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Paso de fotograma ±1';

  @override
  String get playerShortcutsAspectRatio => 'Ciclar relación de aspecto';

  @override
  String get playerShortcutsCycleSubtitles => 'Ciclar subtítulos';

  @override
  String get playerShortcutsVolume => 'Volumen';

  @override
  String get playerShortcutsVolumeAdjust => 'Volumen ±10 %';

  @override
  String get playerShortcutsMute => 'Silenciar / Activar sonido';

  @override
  String get playerShortcutsDisplay => 'Pantalla';

  @override
  String get playerShortcutsFullscreenToggle =>
      'Activar/desactivar pantalla completa';

  @override
  String get playerShortcutsExitFullscreen =>
      'Salir de pantalla completa / atrás';

  @override
  String get playerShortcutsStreamInfo => 'Info del stream';

  @override
  String get playerShortcutsLiveTv => 'TV en Vivo';

  @override
  String get playerShortcutsChannelUp => 'Canal anterior';

  @override
  String get playerShortcutsChannelDown => 'Canal siguiente';

  @override
  String get playerShortcutsChannelList => 'Lista de canales';

  @override
  String get playerShortcutsToggleZap => 'Activar superposición de zapping';

  @override
  String get playerShortcutsGeneral => 'General';

  @override
  String get playerShortcutsSubtitlesCc => 'Subtítulos / CC';

  @override
  String get playerShortcutsScreenLock => 'Bloqueo de pantalla';

  @override
  String get playerShortcutsThisHelp => 'Esta pantalla de ayuda';

  @override
  String get playerShortcutsEscToClose => 'Presiona Esc o ? para cerrar';

  @override
  String get playerZapChannels => 'Canales';

  @override
  String get playerBookmark => 'Marcador';

  @override
  String get playerEditBookmark => 'Editar Marcador';

  @override
  String get playerBookmarkLabelHint => 'Etiqueta del marcador (opcional)';

  @override
  String get playerBookmarkLabelInput => 'Etiqueta del marcador';

  @override
  String playerBookmarkAdded(String label) {
    return 'Marcador agregado en $label';
  }

  @override
  String get playerExpandToFullscreen => 'Expandir a pantalla completa';

  @override
  String get playerUnmute => 'Activar sonido';

  @override
  String get playerMute => 'Silenciar';

  @override
  String get playerStopPlayback => 'Detener reproducción';

  @override
  String get playerQueueUpNext => 'A Continuación';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Episodios de la Temporada $number';
  }

  @override
  String get playerQueueEpisodes => 'Episodios';

  @override
  String get playerQueueEmpty => 'La cola está vacía';

  @override
  String get playerQueueClose => 'Cerrar Cola';

  @override
  String get playerQueueOpen => 'Cola';

  @override
  String playerEpisodeNumber(String number) {
    return 'Episodio $number';
  }

  @override
  String get playerScreenLocked => 'Pantalla bloqueada';

  @override
  String get playerHoldToUnlock => 'Mantén presionado para desbloquear';

  @override
  String get playerScreenshotSaved => 'Captura guardada';

  @override
  String get playerScreenshotFailed => 'Captura fallida';

  @override
  String get playerSkipSegment => 'Omitir segmento';

  @override
  String playerSkipType(String type) {
    return 'Omitir $type';
  }

  @override
  String get playerCouldNotOpenExternal =>
      'No se pudo abrir el reproductor externo';

  @override
  String get playerExitMultiView => 'Salir de Multi-Vista';

  @override
  String get playerScreensaverBouncingLogo => 'Logo Rebotante';

  @override
  String get playerScreensaverClock => 'Reloj';

  @override
  String get playerScreensaverBlackScreen => 'Pantalla Negra';

  @override
  String get streamProfileAuto => 'Auto';

  @override
  String get streamProfileAutoDesc =>
      'Ajustar calidad automáticamente según la red';

  @override
  String get streamProfileLow => 'Baja';

  @override
  String get streamProfileLowDesc => 'Calidad SD, máx ~1 Mbps';

  @override
  String get streamProfileMedium => 'Media';

  @override
  String get streamProfileMediumDesc => 'Calidad HD, máx ~3 Mbps';

  @override
  String get streamProfileHigh => 'Alta';

  @override
  String get streamProfileHighDesc => 'Calidad Full HD, máx ~8 Mbps';

  @override
  String get streamProfileMaximum => 'Máxima';

  @override
  String get streamProfileMaximumDesc => 'Mejor calidad disponible, sin límite';

  @override
  String get segmentIntro => 'Intro';

  @override
  String get segmentOutro => 'Outro / Créditos';

  @override
  String get segmentRecap => 'Resumen';

  @override
  String get segmentCommercial => 'Publicidad';

  @override
  String get segmentPreview => 'Avance';

  @override
  String get segmentSkipNone => 'Ninguno';

  @override
  String get segmentSkipAsk => 'Preguntar antes de omitir';

  @override
  String get segmentSkipOnce => 'Omitir una vez';

  @override
  String get segmentSkipAlways => 'Omitir siempre';

  @override
  String get nextUpOff => 'Desactivado';

  @override
  String get nextUpStatic => 'Estático (32s antes del final)';

  @override
  String get nextUpSmart => 'Inteligente (detecta créditos)';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsSearchSettings => 'Buscar en configuración';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsSources => 'Fuentes';

  @override
  String get settingsPlayback => 'Reproducción';

  @override
  String get settingsData => 'Datos';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Predeterminado del Sistema';

  @override
  String get settingsAboutVersion => 'Versión';

  @override
  String get settingsAboutUpdates => 'Actualizaciones';

  @override
  String get settingsAboutCheckForUpdates => 'Buscar Actualizaciones';

  @override
  String get settingsAboutUpToDate => 'Estás al día';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Actualización disponible: $version';
  }

  @override
  String get settingsAboutLicenses => 'Licencias';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsAccentColor => 'Color de Acento';

  @override
  String get settingsTextScale => 'Escala de Texto';

  @override
  String get settingsDensity => 'Densidad';

  @override
  String get settingsBackup => 'Copia de Seguridad y Restauración';

  @override
  String get settingsBackupCreate => 'Crear Copia de Seguridad';

  @override
  String get settingsBackupRestore => 'Restaurar Copia de Seguridad';

  @override
  String get settingsBackupAuto => 'Copia Automática';

  @override
  String get settingsBackupCloudSync => 'Sincronización en la Nube';

  @override
  String get settingsParentalControls => 'Control Parental';

  @override
  String get settingsParentalSetPin => 'Establecer PIN';

  @override
  String get settingsParentalChangePin => 'Cambiar PIN';

  @override
  String get settingsParentalRemovePin => 'Eliminar PIN';

  @override
  String get settingsParentalBlockedCategories => 'Categorías Bloqueadas';

  @override
  String get settingsNetwork => 'Red';

  @override
  String get settingsNetworkDiagnostics => 'Diagnóstico de Red';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Decodificador de Hardware';

  @override
  String get settingsPlaybackBufferSize => 'Tamaño de Búfer';

  @override
  String get settingsPlaybackDeinterlace => 'Desentrelazado';

  @override
  String get settingsPlaybackUpscaling => 'Escalado';

  @override
  String get settingsPlaybackAudioOutput => 'Salida de Audio';

  @override
  String get settingsPlaybackLoudnessNorm => 'Normalización de Volumen';

  @override
  String get settingsPlaybackVolumeBoost => 'Amplificación de Volumen';

  @override
  String get settingsPlaybackAudioPassthrough => 'Paso de Audio';

  @override
  String get settingsPlaybackSegmentSkip => 'Omisión de Segmento';

  @override
  String get settingsPlaybackNextUp => 'A Continuación';

  @override
  String get settingsPlaybackScreensaver => 'Salvapantallas';

  @override
  String get settingsPlaybackExternalPlayer => 'Reproductor Externo';

  @override
  String get settingsSourceAdd => 'Agregar Fuente';

  @override
  String get settingsSourceEdit => 'Editar Fuente';

  @override
  String get settingsSourceDelete => 'Eliminar Fuente';

  @override
  String get settingsSourceSync => 'Sincronizar Ahora';

  @override
  String get settingsSourceSortOrder => 'Orden de Clasificación';

  @override
  String get settingsDataClearCache => 'Limpiar Caché';

  @override
  String get settingsDataClearHistory => 'Limpiar Historial de Reproducción';

  @override
  String get settingsDataExport => 'Exportar Datos';

  @override
  String get settingsDataImport => 'Importar Datos';

  @override
  String get settingsAdvancedDebug => 'Modo de Depuración';

  @override
  String get settingsAdvancedStreamProxy => 'Proxy de Stream';

  @override
  String get settingsAdvancedAutoUpdate => 'Actualización Automática';

  @override
  String get iptvMultiView => 'Multi-Vista';

  @override
  String get iptvTvGuide => 'Guía de TV';

  @override
  String get iptvBackToGroups => 'Volver a grupos';

  @override
  String get iptvSearchChannels => 'Buscar canales';

  @override
  String get iptvListGridView => 'Vista de Lista';

  @override
  String get iptvGridView => 'Vista de Cuadrícula';

  @override
  String iptvChannelHidden(String name) {
    return '$name oculto';
  }

  @override
  String get iptvSortDone => 'Listo';

  @override
  String get iptvSortResetToDefault => 'Restablecer al Predeterminado';

  @override
  String get iptvSortByPlaylistOrder => 'Por Orden de Playlist';

  @override
  String get iptvSortByName => 'Por Nombre';

  @override
  String get iptvSortByRecent => 'Por Recientes';

  @override
  String get iptvSortByPopularity => 'Por Popularidad';

  @override
  String get epgNowPlaying => 'Ahora';

  @override
  String get epgNoData => 'No hay datos de EPG disponibles';

  @override
  String get epgSetReminder => 'Establecer Recordatorio';

  @override
  String get epgCancelReminder => 'Cancelar Recordatorio';

  @override
  String get epgRecord => 'Grabar';

  @override
  String get epgCancelRecording => 'Cancelar Grabación';

  @override
  String get vodMovies => 'Películas';

  @override
  String get vodSeries => 'Series';

  @override
  String vodSeasonN(int number) {
    return 'Temporada $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Episodio $number';
  }

  @override
  String get vodWatchNow => 'Ver Ahora';

  @override
  String get vodResume => 'Continuar';

  @override
  String get vodContinueWatching => 'Continuar Viendo';

  @override
  String get vodRecommended => 'Recomendados';

  @override
  String get vodRecentlyAdded => 'Añadidos Recientemente';

  @override
  String get vodNoItems => 'No se encontraron elementos';

  @override
  String get dvrSchedule => 'Programación';

  @override
  String get dvrRecordings => 'Grabaciones';

  @override
  String get dvrScheduleRecording => 'Programar Grabación';

  @override
  String get dvrEditRecording => 'Editar Grabación';

  @override
  String get dvrDeleteRecording => 'Eliminar Grabación';

  @override
  String get dvrNoRecordings => 'Sin grabaciones';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get searchHint => 'Buscar canales, películas, series…';

  @override
  String get searchNoResults => 'No se encontraron resultados';

  @override
  String get searchFilterAll => 'Todo';

  @override
  String get searchFilterChannels => 'Canales';

  @override
  String get searchFilterMovies => 'Películas';

  @override
  String get searchFilterSeries => 'Series';

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
  String get homeWhatsOn => '¿Qué hay ahora?';

  @override
  String get homeContinueWatching => 'Continuar Viendo';

  @override
  String get homeRecentChannels => 'Canales Recientes';

  @override
  String get homeMyList => 'Mi Lista';

  @override
  String get homeQuickAccess => 'Acceso Rápido';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmpty => 'Aún no hay favoritos';

  @override
  String get favoritesAddSome =>
      'Agrega canales, películas o series a tus favoritos';

  @override
  String get profilesTitle => 'Perfiles';

  @override
  String get profilesCreate => 'Crear Perfil';

  @override
  String get profilesEdit => 'Editar Perfil';

  @override
  String get profilesDelete => 'Eliminar Perfil';

  @override
  String get profilesManage => 'Administrar Perfiles';

  @override
  String get profilesWhoIsWatching => '¿Quién está viendo?';

  @override
  String get onboardingWelcome => 'Bienvenido a CrispyTivi';

  @override
  String get onboardingAddSource => 'Agrega tu Primera Fuente';

  @override
  String get onboardingChooseType => 'Elige el Tipo de Fuente';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Conectando y cargando canales…';

  @override
  String get onboardingDone => '¡Todo listo!';

  @override
  String get onboardingStartWatching => 'Comenzar a Ver';

  @override
  String get cloudSyncTitle => 'Sincronización en la Nube';

  @override
  String get cloudSyncSignInGoogle => 'Iniciar sesión con Google';

  @override
  String get cloudSyncSignOut => 'Cerrar Sesión';

  @override
  String cloudSyncLastSync(String time) {
    return 'Última sincronización: $time';
  }

  @override
  String get cloudSyncNever => 'Nunca';

  @override
  String get cloudSyncConflict => 'Conflicto de Sincronización';

  @override
  String get cloudSyncKeepLocal => 'Conservar Local';

  @override
  String get cloudSyncKeepRemote => 'Conservar Remoto';

  @override
  String get castTitle => 'Transmitir';

  @override
  String get castSearching => 'Buscando dispositivos…';

  @override
  String get castNoDevices => 'No se encontraron dispositivos';

  @override
  String get castDisconnect => 'Desconectar';

  @override
  String get multiviewTitle => 'Multi-Vista';

  @override
  String get multiviewAddStream => 'Agregar Stream';

  @override
  String get multiviewRemoveStream => 'Quitar Stream';

  @override
  String get multiviewSaveLayout => 'Guardar Disposición';

  @override
  String get multiviewLoadLayout => 'Cargar Disposición';

  @override
  String get multiviewLayoutName => 'Nombre de la disposición';

  @override
  String get multiviewDeleteLayout => 'Eliminar Disposición';

  @override
  String get mediaServerUrl => 'URL del Servidor';

  @override
  String get mediaServerUsername => 'Usuario';

  @override
  String get mediaServerPassword => 'Contraseña';

  @override
  String get mediaServerSignIn => 'Iniciar Sesión';

  @override
  String get mediaServerConnecting => 'Conectando…';

  @override
  String get mediaServerConnectionFailed => 'Conexión fallida';

  @override
  String onboardingChannelsLoaded(int count) {
    return '¡$count canales cargados!';
  }

  @override
  String get onboardingEnterApp => 'Entrar a la App';

  @override
  String get onboardingEnterAppLabel => 'Entrar a la aplicación';

  @override
  String get onboardingCouldNotConnect => 'No se pudo conectar';

  @override
  String get onboardingRetryLabel => 'Reintentar conexión';

  @override
  String get onboardingEditSource => 'Editar detalles de la fuente';

  @override
  String get playerAudioSectionLabel => 'AUDIO';

  @override
  String get playerSubtitlesSectionLabel => 'SUBTÍTULOS';

  @override
  String get playerSwitchProfileTitle => 'Cambiar Perfil';

  @override
  String get playerCopyStreamUrl => 'Copiar URL del Stream';

  @override
  String get cloudSyncSyncing => 'Sincronizando…';

  @override
  String get cloudSyncNow => 'Sincronizar Ahora';

  @override
  String get cloudSyncForceUpload => 'Forzar Subida';

  @override
  String get cloudSyncForceDownload => 'Forzar Descarga';

  @override
  String get cloudSyncAutoSync => 'Sincronización automática';

  @override
  String get cloudSyncThisDevice => 'Este Dispositivo';

  @override
  String get cloudSyncCloud => 'Nube';

  @override
  String get cloudSyncNewer => 'MÁS RECIENTE';

  @override
  String get contextMenuAddFavorite => 'Agregar a Favoritos';

  @override
  String get contextMenuRemoveFavorite => 'Quitar de Favoritos';

  @override
  String get contextMenuSwitchStream => 'Cambiar fuente de stream';

  @override
  String get contextMenuCopyUrl => 'Copiar URL del Stream';

  @override
  String get contextMenuOpenExternal => 'Reproducir en Reproductor Externo';

  @override
  String get contextMenuPlay => 'Reproducir';

  @override
  String get contextMenuAddFavoriteCategory => 'Agregar a Categorías Favoritas';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Quitar de Categorías Favoritas';

  @override
  String get contextMenuFilterCategory => 'Filtrar por esta categoría';

  @override
  String get confirmDeleteCancel => 'Cancelar';

  @override
  String get confirmDeleteAction => 'Eliminar';
}
