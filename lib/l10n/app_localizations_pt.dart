// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonRetry => 'Tentar Novamente';

  @override
  String get commonSomethingWentWrong => 'Algo deu errado';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonSubmit => 'Enviar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonAll => 'Tudo';

  @override
  String get commonOn => 'Ativado';

  @override
  String get commonOff => 'Desativado';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonNone => 'Nenhum';

  @override
  String commonError(String message) {
    return 'Erro: $message';
  }

  @override
  String get commonOr => 'ou';

  @override
  String get commonRefresh => 'Atualizar';

  @override
  String get commonDone => 'Concluído';

  @override
  String get commonPlay => 'Reproduzir';

  @override
  String get commonPause => 'Pausar';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonGoToSettings => 'Ir para Configurações';

  @override
  String get commonNew => 'NOVO';

  @override
  String get commonLive => 'AO VIVO';

  @override
  String get commonFavorites => 'Favoritos';

  @override
  String get keyboardShortcuts => 'Atalhos de teclado';

  @override
  String get navHome => 'Início';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLiveTv => 'TV ao Vivo';

  @override
  String get navGuide => 'Guia';

  @override
  String get navMovies => 'Filmes';

  @override
  String get navSeries => 'Séries';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favoritos';

  @override
  String get navSettings => 'Configurações';

  @override
  String get breadcrumbProfiles => 'Perfis';

  @override
  String get breadcrumbJellyfin => 'Jellyfin';

  @override
  String get breadcrumbEmby => 'Emby';

  @override
  String get breadcrumbPlex => 'Plex';

  @override
  String get breadcrumbCloud => 'Nuvem';

  @override
  String get breadcrumbMultiView => 'Multi-Visão';

  @override
  String get breadcrumbDetail => 'Detalhe';

  @override
  String get breadcrumbNavigateToParent => 'Navegar para o nível superior';

  @override
  String get sideNavSwitchProfile => 'Trocar Perfil';

  @override
  String get sideNavManageProfiles => 'Gerenciar perfis';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Trocar perfil: $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'Inserir PIN de $name';
  }

  @override
  String get sideNavActive => 'ativo';

  @override
  String get sideNavPinProtected => 'Protegido por PIN';

  @override
  String get fabWhatsOn => 'O que está passando?';

  @override
  String get fabRandomPick => 'Escolha Aleatória';

  @override
  String get fabLastChannel => 'Último Canal';

  @override
  String get fabSchedule => 'Programação';

  @override
  String get fabNewList => 'Nova Lista';

  @override
  String get offlineNoConnection => 'Sem conexão';

  @override
  String get offlineConnectionRestored => 'Conexão restaurada';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Página não encontrada';

  @override
  String get pinConfirmPin => 'Confirmar PIN';

  @override
  String get pinEnterAllDigits => 'Insira os 4 dígitos';

  @override
  String get pinDoNotMatch => 'Os PINs não coincidem';

  @override
  String get pinTooManyAttempts => 'Muitas tentativas incorretas.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Tente novamente em $countdown';
  }

  @override
  String get pinEnterSameAgain => 'Insira o mesmo PIN novamente para confirmar';

  @override
  String get pinUseBiometric =>
      'Usar impressão digital ou reconhecimento facial';

  @override
  String pinDigitN(int n) {
    return 'Dígito $n do PIN';
  }

  @override
  String get pinIncorrect => 'PIN incorreto';

  @override
  String get pinVerificationFailed => 'Verificação falhou';

  @override
  String get pinBiometricFailed =>
      'Autenticação biométrica falhou ou foi cancelada';

  @override
  String get contextMenuRemoveFromFavorites => 'Remover dos Favoritos';

  @override
  String get contextMenuAddToFavorites => 'Adicionar aos Favoritos';

  @override
  String get contextMenuSwitchStreamSource => 'Trocar fonte do stream';

  @override
  String get contextMenuSmartGroup => 'Grupo Inteligente';

  @override
  String get contextMenuMultiView => 'Multi-Visão';

  @override
  String get contextMenuAssignEpg => 'Atribuir EPG';

  @override
  String get contextMenuHideChannel => 'Ocultar canal';

  @override
  String get contextMenuCopyStreamUrl => 'Copiar URL do Stream';

  @override
  String get contextMenuPlayExternal => 'Reproduzir no Player Externo';

  @override
  String get contextMenuBlockChannel => 'Bloquear canal';

  @override
  String get contextMenuViewDetails => 'Ver detalhes';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Remover das Categorias Favoritas';

  @override
  String get contextMenuAddToFavoriteCategories =>
      'Adicionar às Categorias Favoritas';

  @override
  String get contextMenuFilterByCategory => 'Filtrar por esta categoria';

  @override
  String get contextMenuCloseContextMenu => 'Fechar menu de contexto';

  @override
  String get sourceAllSources => 'Todas as Fontes';

  @override
  String sourceFilterLabel(String label) {
    return 'Filtro de fonte $label';
  }

  @override
  String get categoryLabel => 'Categoria';

  @override
  String categoryAll(String label) {
    return 'Todo $label';
  }

  @override
  String categorySelect(String label) {
    return 'Selecionar $label';
  }

  @override
  String get categorySearchHint => 'Buscar categorias…';

  @override
  String get categorySearchLabel => 'Buscar categorias';

  @override
  String get categoryRemoveFromFavorites => 'Remover das categorias favoritas';

  @override
  String get categoryAddToFavorites => 'Adicionar às categorias favoritas';

  @override
  String get sidebarExpandSidebar => 'Expandir barra lateral';

  @override
  String get sidebarCollapseSidebar => 'Recolher barra lateral';

  @override
  String get badgeNewEpisode => 'EP NOVO';

  @override
  String get badgeNewSeason => 'NOVA TEMPORADA';

  @override
  String get badgeRecording => 'REC';

  @override
  String get badgeExpiring => 'EXPIRA';

  @override
  String get toggleFavorite => 'Alternar favorito';

  @override
  String get playerSkipBack => 'Voltar 10 segundos';

  @override
  String get playerSkipForward => 'Avançar 10 segundos';

  @override
  String get playerChannels => 'Canais';

  @override
  String get playerRecordings => 'Gravações';

  @override
  String get playerCloseGuide => 'Fechar Guia (G)';

  @override
  String get playerTvGuide => 'Guia de TV (G)';

  @override
  String get playerAudioSubtitles => 'Áudio e Legendas';

  @override
  String get playerNoTracksAvailable => 'Nenhuma faixa disponível';

  @override
  String get playerExitFullscreen => 'Sair da Tela Cheia';

  @override
  String get playerFullscreen => 'Tela Cheia';

  @override
  String get playerUnlockScreen => 'Desbloquear Tela';

  @override
  String get playerLockScreen => 'Bloquear Tela';

  @override
  String get playerStreamQuality => 'Qualidade do Stream';

  @override
  String get playerRotationLock => 'Bloqueio de Rotação';

  @override
  String get playerScreenBrightness => 'Brilho da Tela';

  @override
  String get playerShaderPreset => 'Preset de Shader';

  @override
  String get playerAutoSystem => 'Auto (Sistema)';

  @override
  String get playerResetToAuto => 'Restaurar para Auto';

  @override
  String get playerPortrait => 'Retrato';

  @override
  String get playerPortraitUpsideDown => 'Retrato (de cabeça para baixo)';

  @override
  String get playerLandscapeLeft => 'Paisagem à esquerda';

  @override
  String get playerLandscapeRight => 'Paisagem à direita';

  @override
  String get playerDeinterlaceAuto => 'Auto';

  @override
  String get playerMoreOptions => 'Mais opções';

  @override
  String get playerRemoveFavorite => 'Remover dos Favoritos';

  @override
  String get playerAddFavorite => 'Adicionar aos Favoritos';

  @override
  String get playerAudioTrack => 'Faixa de Áudio';

  @override
  String playerAspectRatio(String label) {
    return 'Proporção ($label)';
  }

  @override
  String get playerRefreshStream => 'Atualizar Stream';

  @override
  String get playerStreamInfo => 'Info do Stream';

  @override
  String get playerPip => 'Picture-in-Picture';

  @override
  String get playerSleepTimer => 'Temporizador de Sono';

  @override
  String get playerExternalPlayer => 'Player Externo';

  @override
  String get playerSearchChannels => 'Buscar Canais';

  @override
  String get playerChannelList => 'Lista de Canais';

  @override
  String get playerScreenshot => 'Captura de Tela';

  @override
  String playerStreamQualityOption(String label) {
    return 'Qualidade do Stream ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Desentrelaçamento ($mode)';
  }

  @override
  String get playerSyncOffset => 'Ajuste de Sincronização';

  @override
  String playerAudioPassthrough(String state) {
    return 'Passthrough de Áudio ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Dispositivo de Saída de Áudio';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Sempre no Topo ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Shaders ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'ÁUDIO';

  @override
  String get playerSubtitlesSectionSubtitles => 'LEGENDAS';

  @override
  String get playerSubtitlesSecondHint => '(pressão longa = 2°)';

  @override
  String get playerSubtitlesCcStyle => 'Estilo de Legenda';

  @override
  String get playerSyncOffsetAudio => 'Áudio';

  @override
  String get playerSyncOffsetSubtitle => 'Legenda';

  @override
  String get playerSyncOffsetResetToZero => 'Redefinir para 0';

  @override
  String get playerNoAudioDevices => 'Nenhum dispositivo de áudio encontrado.';

  @override
  String get playerSpeedLive => 'Velocidade (ao vivo)';

  @override
  String get playerSpeed => 'Velocidade';

  @override
  String get playerVolumeLabel => 'Volume';

  @override
  String playerVolumePercent(int percent) {
    return 'Volume $percent%';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Trocar perfil ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '$duration restante';
  }

  @override
  String get playerSubtitleFontWeight => 'PESO DA FONTE';

  @override
  String get playerSubtitleBold => 'Negrito';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'TAMANHO DA FONTE';

  @override
  String playerSubtitlePosition(int value) {
    return 'POSIÇÃO ($value%)';
  }

  @override
  String get playerSubtitleTextColor => 'COR DO TEXTO';

  @override
  String get playerSubtitleOutlineColor => 'COR DO CONTORNO';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'TAMANHO DO CONTORNO ($value)';
  }

  @override
  String get playerSubtitleBackground => 'FUNDO';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'OPACIDADE DO FUNDO ($value%)';
  }

  @override
  String get playerSubtitleShadow => 'SOMBRA';

  @override
  String get playerSubtitlePreview => 'PRÉVIA';

  @override
  String get playerSubtitleSampleText => 'Texto de legenda de exemplo';

  @override
  String get playerSubtitleResetDefaults => 'Restaurar padrões';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Parando em $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Cancelar Temporizador';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes minutos';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Definir temporizador para $minutes minutos';
  }

  @override
  String get playerStreamStats => 'Estatísticas do Stream';

  @override
  String get playerStreamStatsBuffer => 'Buffer';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Copiado!';

  @override
  String get playerStreamStatsCopy => 'Copiar estatísticas';

  @override
  String get playerStreamStatsInterlaced => 'Entrelaçado';

  @override
  String playerNextUpIn(int seconds) {
    return 'A seguir em $seconds';
  }

  @override
  String get playerPlayNow => 'Reproduzir Agora';

  @override
  String get playerFinished => 'Concluído';

  @override
  String get playerWatchAgain => 'Assistir Novamente';

  @override
  String get playerBrowseMore => 'Explorar Mais';

  @override
  String get playerShortcutsTitle => 'Atalhos de Teclado';

  @override
  String get playerShortcutsCloseEsc => 'Fechar (Esc)';

  @override
  String get playerShortcutsPlayback => 'Reprodução';

  @override
  String get playerShortcutsPlayPause => 'Reproduzir / Pausar';

  @override
  String get playerShortcutsSeek => 'Buscar ±10 s';

  @override
  String get playerShortcutsSpeedStep => 'Velocidade passo −/+';

  @override
  String get playerShortcutsSpeedFine => 'Velocidade −/+ 0.1x';

  @override
  String get playerShortcutsJumpPercent => 'Pular para % (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Passo de quadro ±1';

  @override
  String get playerShortcutsAspectRatio => 'Ciclar proporção';

  @override
  String get playerShortcutsCycleSubtitles => 'Ciclar legendas';

  @override
  String get playerShortcutsVolume => 'Volume';

  @override
  String get playerShortcutsVolumeAdjust => 'Volume ±10 %';

  @override
  String get playerShortcutsMute => 'Mutar / desmutar';

  @override
  String get playerShortcutsDisplay => 'Exibição';

  @override
  String get playerShortcutsFullscreenToggle => 'Alternar tela cheia';

  @override
  String get playerShortcutsExitFullscreen => 'Sair da tela cheia / voltar';

  @override
  String get playerShortcutsStreamInfo => 'Info do stream';

  @override
  String get playerShortcutsLiveTv => 'TV ao Vivo';

  @override
  String get playerShortcutsChannelUp => 'Canal anterior';

  @override
  String get playerShortcutsChannelDown => 'Canal seguinte';

  @override
  String get playerShortcutsChannelList => 'Lista de canais';

  @override
  String get playerShortcutsToggleZap => 'Alternar sobreposição de zapping';

  @override
  String get playerShortcutsGeneral => 'Geral';

  @override
  String get playerShortcutsSubtitlesCc => 'Legendas / CC';

  @override
  String get playerShortcutsScreenLock => 'Bloqueio de tela';

  @override
  String get playerShortcutsThisHelp => 'Esta tela de ajuda';

  @override
  String get playerShortcutsEscToClose => 'Pressione Esc ou ? para fechar';

  @override
  String get playerZapChannels => 'Canais';

  @override
  String get playerBookmark => 'Marcador';

  @override
  String get playerEditBookmark => 'Editar Marcador';

  @override
  String get playerBookmarkLabelHint => 'Rótulo do marcador (opcional)';

  @override
  String get playerBookmarkLabelInput => 'Rótulo do marcador';

  @override
  String playerBookmarkAdded(String label) {
    return 'Marcador adicionado em $label';
  }

  @override
  String get playerExpandToFullscreen => 'Expandir para tela cheia';

  @override
  String get playerUnmute => 'Desmutar';

  @override
  String get playerMute => 'Mutar';

  @override
  String get playerStopPlayback => 'Parar reprodução';

  @override
  String get playerQueueUpNext => 'A Seguir';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Episódios da Temporada $number';
  }

  @override
  String get playerQueueEpisodes => 'Episódios';

  @override
  String get playerQueueEmpty => 'A fila está vazia';

  @override
  String get playerQueueClose => 'Fechar Fila';

  @override
  String get playerQueueOpen => 'Fila';

  @override
  String playerEpisodeNumber(String number) {
    return 'Episódio $number';
  }

  @override
  String get playerScreenLocked => 'Tela bloqueada';

  @override
  String get playerHoldToUnlock => 'Segure para desbloquear';

  @override
  String get playerScreenshotSaved => 'Captura salva';

  @override
  String get playerScreenshotFailed => 'Falha na captura';

  @override
  String get playerSkipSegment => 'Pular segmento';

  @override
  String playerSkipType(String type) {
    return 'Pular $type';
  }

  @override
  String get playerCouldNotOpenExternal =>
      'Não foi possível abrir o player externo';

  @override
  String get playerExitMultiView => 'Sair do Multi-Visão';

  @override
  String get playerScreensaverBouncingLogo => 'Logo Saltitante';

  @override
  String get playerScreensaverClock => 'Relógio';

  @override
  String get playerScreensaverBlackScreen => 'Tela Preta';

  @override
  String get streamProfileAuto => 'Auto';

  @override
  String get streamProfileAutoDesc =>
      'Ajustar qualidade automaticamente conforme a rede';

  @override
  String get streamProfileLow => 'Baixa';

  @override
  String get streamProfileLowDesc => 'Qualidade SD, máx ~1 Mbps';

  @override
  String get streamProfileMedium => 'Média';

  @override
  String get streamProfileMediumDesc => 'Qualidade HD, máx ~3 Mbps';

  @override
  String get streamProfileHigh => 'Alta';

  @override
  String get streamProfileHighDesc => 'Qualidade Full HD, máx ~8 Mbps';

  @override
  String get streamProfileMaximum => 'Máxima';

  @override
  String get streamProfileMaximumDesc =>
      'Melhor qualidade disponível, sem limite';

  @override
  String get segmentIntro => 'Introdução';

  @override
  String get segmentOutro => 'Outro / Créditos';

  @override
  String get segmentRecap => 'Recapitulação';

  @override
  String get segmentCommercial => 'Comercial';

  @override
  String get segmentPreview => 'Prévia';

  @override
  String get segmentSkipNone => 'Nenhum';

  @override
  String get segmentSkipAsk => 'Perguntar antes de pular';

  @override
  String get segmentSkipOnce => 'Pular uma vez';

  @override
  String get segmentSkipAlways => 'Sempre pular';

  @override
  String get nextUpOff => 'Desativado';

  @override
  String get nextUpStatic => 'Estático (32s antes do fim)';

  @override
  String get nextUpSmart => 'Inteligente (detecta créditos)';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSearchSettings => 'Buscar nas configurações';

  @override
  String get settingsGeneral => 'Geral';

  @override
  String get settingsSources => 'Fontes';

  @override
  String get settingsPlayback => 'Reprodução';

  @override
  String get settingsData => 'Dados';

  @override
  String get settingsAdvanced => 'Avançado';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Padrão do Sistema';

  @override
  String get settingsAboutVersion => 'Versão';

  @override
  String get settingsAboutUpdates => 'Atualizações';

  @override
  String get settingsAboutCheckForUpdates => 'Verificar Atualizações';

  @override
  String get settingsAboutUpToDate => 'Você está atualizado';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Atualização disponível: $version';
  }

  @override
  String get settingsAboutLicenses => 'Licenças';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsAccentColor => 'Cor de Destaque';

  @override
  String get settingsTextScale => 'Escala de Texto';

  @override
  String get settingsDensity => 'Densidade';

  @override
  String get settingsBackup => 'Backup e Restauração';

  @override
  String get settingsBackupCreate => 'Criar Backup';

  @override
  String get settingsBackupRestore => 'Restaurar Backup';

  @override
  String get settingsBackupAuto => 'Backup Automático';

  @override
  String get settingsBackupCloudSync => 'Sincronização na Nuvem';

  @override
  String get settingsParentalControls => 'Controle dos Pais';

  @override
  String get settingsParentalSetPin => 'Definir PIN';

  @override
  String get settingsParentalChangePin => 'Alterar PIN';

  @override
  String get settingsParentalRemovePin => 'Remover PIN';

  @override
  String get settingsParentalBlockedCategories => 'Categorias Bloqueadas';

  @override
  String get settingsNetwork => 'Rede';

  @override
  String get settingsNetworkDiagnostics => 'Diagnóstico de Rede';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Decodificador de Hardware';

  @override
  String get settingsPlaybackBufferSize => 'Tamanho do Buffer';

  @override
  String get settingsPlaybackDeinterlace => 'Desentrelaçamento';

  @override
  String get settingsPlaybackUpscaling => 'Upscaling';

  @override
  String get settingsPlaybackAudioOutput => 'Saída de Áudio';

  @override
  String get settingsPlaybackLoudnessNorm => 'Normalização de Volume';

  @override
  String get settingsPlaybackVolumeBoost => 'Amplificação de Volume';

  @override
  String get settingsPlaybackAudioPassthrough => 'Passthrough de Áudio';

  @override
  String get settingsPlaybackSegmentSkip => 'Pular Segmento';

  @override
  String get settingsPlaybackNextUp => 'A Seguir';

  @override
  String get settingsPlaybackScreensaver => 'Protetor de Tela';

  @override
  String get settingsPlaybackExternalPlayer => 'Player Externo';

  @override
  String get settingsSourceAdd => 'Adicionar Fonte';

  @override
  String get settingsSourceEdit => 'Editar Fonte';

  @override
  String get settingsSourceDelete => 'Excluir Fonte';

  @override
  String get settingsSourceSync => 'Sincronizar Agora';

  @override
  String get settingsSourceSortOrder => 'Ordem de Classificação';

  @override
  String get settingsDataClearCache => 'Limpar Cache';

  @override
  String get settingsDataClearHistory => 'Limpar Histórico de Reprodução';

  @override
  String get settingsDataExport => 'Exportar Dados';

  @override
  String get settingsDataImport => 'Importar Dados';

  @override
  String get settingsAdvancedDebug => 'Modo de Depuração';

  @override
  String get settingsAdvancedStreamProxy => 'Proxy de Stream';

  @override
  String get settingsAdvancedAutoUpdate => 'Atualização Automática';

  @override
  String get iptvMultiView => 'Multi-Visão';

  @override
  String get iptvTvGuide => 'Guia de TV';

  @override
  String get iptvBackToGroups => 'Voltar para grupos';

  @override
  String get iptvSearchChannels => 'Buscar canais';

  @override
  String get iptvListGridView => 'Visualização em Lista';

  @override
  String get iptvGridView => 'Visualização em Grade';

  @override
  String iptvChannelHidden(String name) {
    return '$name oculto';
  }

  @override
  String get iptvSortDone => 'Concluído';

  @override
  String get iptvSortResetToDefault => 'Restaurar Padrão';

  @override
  String get iptvSortByPlaylistOrder => 'Por Ordem da Playlist';

  @override
  String get iptvSortByName => 'Por Nome';

  @override
  String get iptvSortByRecent => 'Por Recentes';

  @override
  String get iptvSortByPopularity => 'Por Popularidade';

  @override
  String get epgNowPlaying => 'Agora';

  @override
  String get epgNoData => 'Nenhum dado de EPG disponível';

  @override
  String get epgSetReminder => 'Definir Lembrete';

  @override
  String get epgCancelReminder => 'Cancelar Lembrete';

  @override
  String get epgRecord => 'Gravar';

  @override
  String get epgCancelRecording => 'Cancelar Gravação';

  @override
  String get vodMovies => 'Filmes';

  @override
  String get vodSeries => 'Séries';

  @override
  String vodSeasonN(int number) {
    return 'Temporada $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Episódio $number';
  }

  @override
  String get vodWatchNow => 'Assistir Agora';

  @override
  String get vodResume => 'Continuar';

  @override
  String get vodContinueWatching => 'Continuar Assistindo';

  @override
  String get vodRecommended => 'Recomendados';

  @override
  String get vodRecentlyAdded => 'Adicionados Recentemente';

  @override
  String get vodNoItems => 'Nenhum item encontrado';

  @override
  String get dvrSchedule => 'Programação';

  @override
  String get dvrRecordings => 'Gravações';

  @override
  String get dvrScheduleRecording => 'Agendar Gravação';

  @override
  String get dvrEditRecording => 'Editar Gravação';

  @override
  String get dvrDeleteRecording => 'Excluir Gravação';

  @override
  String get dvrNoRecordings => 'Sem gravações';

  @override
  String get searchTitle => 'Buscar';

  @override
  String get searchHint => 'Buscar canais, filmes, séries…';

  @override
  String get searchNoResults => 'Nenhum resultado encontrado';

  @override
  String get searchFilterAll => 'Tudo';

  @override
  String get searchFilterChannels => 'Canais';

  @override
  String get searchFilterMovies => 'Filmes';

  @override
  String get searchFilterSeries => 'Séries';

  @override
  String get homeWhatsOn => 'O que está passando agora?';

  @override
  String get homeContinueWatching => 'Continuar Assistindo';

  @override
  String get homeRecentChannels => 'Canais Recentes';

  @override
  String get homeMyList => 'Minha Lista';

  @override
  String get homeQuickAccess => 'Acesso Rápido';

  @override
  String get favoritesTitle => 'Favoritos';

  @override
  String get favoritesEmpty => 'Nenhum favorito ainda';

  @override
  String get favoritesAddSome =>
      'Adicione canais, filmes ou séries aos seus favoritos';

  @override
  String get profilesTitle => 'Perfis';

  @override
  String get profilesCreate => 'Criar Perfil';

  @override
  String get profilesEdit => 'Editar Perfil';

  @override
  String get profilesDelete => 'Excluir Perfil';

  @override
  String get profilesManage => 'Gerenciar Perfis';

  @override
  String get profilesWhoIsWatching => 'Quem está assistindo?';

  @override
  String get onboardingWelcome => 'Bem-vindo ao CrispyTivi';

  @override
  String get onboardingAddSource => 'Adicione sua Primeira Fonte';

  @override
  String get onboardingChooseType => 'Escolha o Tipo de Fonte';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Conectando e carregando canais…';

  @override
  String get onboardingDone => 'Tudo pronto!';

  @override
  String get onboardingStartWatching => 'Começar a Assistir';

  @override
  String get cloudSyncTitle => 'Sincronização na Nuvem';

  @override
  String get cloudSyncSignInGoogle => 'Entrar com o Google';

  @override
  String get cloudSyncSignOut => 'Sair';

  @override
  String cloudSyncLastSync(String time) {
    return 'Última sincronização: $time';
  }

  @override
  String get cloudSyncNever => 'Nunca';

  @override
  String get cloudSyncConflict => 'Conflito de Sincronização';

  @override
  String get cloudSyncKeepLocal => 'Manter Local';

  @override
  String get cloudSyncKeepRemote => 'Manter Remoto';

  @override
  String get castTitle => 'Transmitir';

  @override
  String get castSearching => 'Buscando dispositivos…';

  @override
  String get castNoDevices => 'Nenhum dispositivo encontrado';

  @override
  String get castDisconnect => 'Desconectar';

  @override
  String get multiviewTitle => 'Multi-Visão';

  @override
  String get multiviewAddStream => 'Adicionar Stream';

  @override
  String get multiviewRemoveStream => 'Remover Stream';

  @override
  String get multiviewSaveLayout => 'Salvar Layout';

  @override
  String get multiviewLoadLayout => 'Carregar Layout';

  @override
  String get multiviewLayoutName => 'Nome do layout';

  @override
  String get multiviewDeleteLayout => 'Excluir Layout';

  @override
  String get mediaServerUrl => 'URL do Servidor';

  @override
  String get mediaServerUsername => 'Usuário';

  @override
  String get mediaServerPassword => 'Senha';

  @override
  String get mediaServerSignIn => 'Entrar';

  @override
  String get mediaServerConnecting => 'Conectando…';

  @override
  String get mediaServerConnectionFailed => 'Falha na conexão';

  @override
  String onboardingChannelsLoaded(int count) {
    return '$count canais carregados!';
  }

  @override
  String get onboardingEnterApp => 'Entrar no App';

  @override
  String get onboardingEnterAppLabel => 'Entrar no aplicativo';

  @override
  String get onboardingCouldNotConnect => 'Não foi possível conectar';

  @override
  String get onboardingRetryLabel => 'Tentar conexão novamente';

  @override
  String get onboardingEditSource => 'Editar detalhes da fonte';

  @override
  String get playerAudioSectionLabel => 'ÁUDIO';

  @override
  String get playerSubtitlesSectionLabel => 'LEGENDAS';

  @override
  String get playerSwitchProfileTitle => 'Trocar Perfil';

  @override
  String get playerCopyStreamUrl => 'Copiar URL do Stream';

  @override
  String get cloudSyncSyncing => 'Sincronizando…';

  @override
  String get cloudSyncNow => 'Sincronizar Agora';

  @override
  String get cloudSyncForceUpload => 'Forçar Upload';

  @override
  String get cloudSyncForceDownload => 'Forçar Download';

  @override
  String get cloudSyncAutoSync => 'Sincronização automática';

  @override
  String get cloudSyncThisDevice => 'Este Dispositivo';

  @override
  String get cloudSyncCloud => 'Nuvem';

  @override
  String get cloudSyncNewer => 'MAIS RECENTE';

  @override
  String get contextMenuAddFavorite => 'Adicionar aos Favoritos';

  @override
  String get contextMenuRemoveFavorite => 'Remover dos Favoritos';

  @override
  String get contextMenuSwitchStream => 'Trocar fonte do stream';

  @override
  String get contextMenuCopyUrl => 'Copiar URL do Stream';

  @override
  String get contextMenuOpenExternal => 'Reproduzir no Player Externo';

  @override
  String get contextMenuPlay => 'Reproduzir';

  @override
  String get contextMenuAddFavoriteCategory =>
      'Adicionar às Categorias Favoritas';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Remover das Categorias Favoritas';

  @override
  String get contextMenuFilterCategory => 'Filtrar por esta categoria';

  @override
  String get confirmDeleteCancel => 'Cancelar';

  @override
  String get confirmDeleteAction => 'Excluir';
}
