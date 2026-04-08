// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'CrispyTivi';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSomethingWentWrong => 'Une erreur est survenue';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSubmit => 'Soumettre';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonAll => 'Tout';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get commonAuto => 'Auto';

  @override
  String get commonNone => 'Aucun';

  @override
  String commonError(String message) {
    return 'Erreur : $message';
  }

  @override
  String get commonOr => 'ou';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonPlay => 'Lire';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonGoToSettings => 'Aller aux paramètres';

  @override
  String get commonNew => 'NOUVEAU';

  @override
  String get commonLive => 'DIRECT';

  @override
  String get commonFavorites => 'Favoris';

  @override
  String get keyboardShortcuts => 'Raccourcis clavier';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navLiveTv => 'TV en direct';

  @override
  String get navGuide => 'Guide';

  @override
  String get navMovies => 'Films';

  @override
  String get navSeries => 'Séries';

  @override
  String get navDvr => 'DVR';

  @override
  String get navFavorites => 'Favoris';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get breadcrumbProfiles => 'Profils';

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
  String get breadcrumbDetail => 'Détail';

  @override
  String get breadcrumbNavigateToParent => 'Aller au parent';

  @override
  String get sideNavSwitchProfile => 'Changer de profil';

  @override
  String get sideNavManageProfiles => 'Gérer les profils';

  @override
  String sideNavSwitchProfileFor(String name) {
    return 'Changer de profil : $name';
  }

  @override
  String sideNavEnterPinFor(String name) {
    return 'Entrer le code PIN pour $name';
  }

  @override
  String get sideNavActive => 'actif';

  @override
  String get sideNavPinProtected => 'Protégé par code PIN';

  @override
  String get fabWhatsOn => 'À l\'affiche';

  @override
  String get fabRandomPick => 'Choix aléatoire';

  @override
  String get fabLastChannel => 'Dernière chaîne';

  @override
  String get fabSchedule => 'Programme';

  @override
  String get fabNewList => 'Nouvelle liste';

  @override
  String get offlineNoConnection => 'Pas de connexion';

  @override
  String get offlineConnectionRestored => 'Connexion rétablie';

  @override
  String get splashAppName => 'CrispyTivi';

  @override
  String get pageNotFound => 'Page introuvable';

  @override
  String get pinConfirmPin => 'Confirmer le code PIN';

  @override
  String get pinEnterAllDigits => 'Saisir les 4 chiffres';

  @override
  String get pinDoNotMatch => 'Les codes PIN ne correspondent pas';

  @override
  String get pinTooManyAttempts => 'Trop de tentatives incorrectes.';

  @override
  String pinTryAgainIn(String countdown) {
    return 'Réessayer dans $countdown';
  }

  @override
  String get pinEnterSameAgain => 'Ressaisir le même code PIN pour confirmer';

  @override
  String get pinUseBiometric => 'Utiliser l\'empreinte digitale ou le visage';

  @override
  String pinDigitN(int n) {
    return 'Chiffre PIN $n';
  }

  @override
  String get pinIncorrect => 'Code PIN incorrect';

  @override
  String get pinVerificationFailed => 'Échec de la vérification';

  @override
  String get pinBiometricFailed =>
      'Authentification biométrique échouée ou annulée';

  @override
  String get contextMenuRemoveFromFavorites => 'Retirer des favoris';

  @override
  String get contextMenuAddToFavorites => 'Ajouter aux favoris';

  @override
  String get contextMenuSwitchStreamSource => 'Changer la source du flux';

  @override
  String get contextMenuSmartGroup => 'Groupe intelligent';

  @override
  String get contextMenuMultiView => 'Multi-View';

  @override
  String get contextMenuAssignEpg => 'Attribuer un EPG';

  @override
  String get contextMenuHideChannel => 'Masquer la chaîne';

  @override
  String get contextMenuCopyStreamUrl => 'Copier l\'URL du flux';

  @override
  String get contextMenuPlayExternal => 'Lire dans un lecteur externe';

  @override
  String get contextMenuBlockChannel => 'Bloquer la chaîne';

  @override
  String get contextMenuViewDetails => 'Voir les détails';

  @override
  String get contextMenuRemoveFromFavoriteCategories =>
      'Retirer des catégories favorites';

  @override
  String get contextMenuAddToFavoriteCategories =>
      'Ajouter aux catégories favorites';

  @override
  String get contextMenuFilterByCategory => 'Filtrer par cette catégorie';

  @override
  String get contextMenuCloseContextMenu => 'Fermer le menu contextuel';

  @override
  String get sourceAllSources => 'Toutes les sources';

  @override
  String sourceFilterLabel(String label) {
    return 'Filtre source $label';
  }

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String categoryAll(String label) {
    return 'Tout $label';
  }

  @override
  String categorySelect(String label) {
    return 'Sélectionner $label';
  }

  @override
  String get categorySearchHint => 'Rechercher des catégories…';

  @override
  String get categorySearchLabel => 'Rechercher des catégories';

  @override
  String get categoryRemoveFromFavorites => 'Retirer des catégories favorites';

  @override
  String get categoryAddToFavorites => 'Ajouter aux catégories favorites';

  @override
  String get sidebarExpandSidebar => 'Développer la barre latérale';

  @override
  String get sidebarCollapseSidebar => 'Réduire la barre latérale';

  @override
  String get badgeNewEpisode => 'NOUVEL ÉP.';

  @override
  String get badgeNewSeason => 'NOUVELLE SAISON';

  @override
  String get badgeRecording => 'ENR.';

  @override
  String get badgeExpiring => 'EXPIRE';

  @override
  String get toggleFavorite => 'Basculer favori';

  @override
  String get playerSkipBack => 'Reculer de 10 secondes';

  @override
  String get playerSkipForward => 'Avancer de 10 secondes';

  @override
  String get playerChannels => 'Chaînes';

  @override
  String get playerRecordings => 'Enregistrements';

  @override
  String get playerCloseGuide => 'Fermer le guide (G)';

  @override
  String get playerTvGuide => 'Guide TV (G)';

  @override
  String get playerAudioSubtitles => 'Audio et sous-titres';

  @override
  String get playerNoTracksAvailable => 'Aucune piste disponible';

  @override
  String get playerExitFullscreen => 'Quitter le plein écran';

  @override
  String get playerFullscreen => 'Plein écran';

  @override
  String get playerUnlockScreen => 'Déverrouiller l\'écran';

  @override
  String get playerLockScreen => 'Verrouiller l\'écran';

  @override
  String get playerStreamQuality => 'Qualité du flux';

  @override
  String get playerRotationLock => 'Verrouillage de rotation';

  @override
  String get playerScreenBrightness => 'Luminosité de l\'écran';

  @override
  String get playerShaderPreset => 'Préréglage de shader';

  @override
  String get playerAutoSystem => 'Auto (système)';

  @override
  String get playerResetToAuto => 'Réinitialiser en auto';

  @override
  String get playerPortrait => 'Portrait';

  @override
  String get playerPortraitUpsideDown => 'Portrait (inversé)';

  @override
  String get playerLandscapeLeft => 'Paysage gauche';

  @override
  String get playerLandscapeRight => 'Paysage droit';

  @override
  String get playerDeinterlaceAuto => 'Auto';

  @override
  String get playerMoreOptions => 'Plus d\'options';

  @override
  String get playerRemoveFavorite => 'Retirer des favoris';

  @override
  String get playerAddFavorite => 'Ajouter aux favoris';

  @override
  String get playerAudioTrack => 'Piste audio';

  @override
  String playerAspectRatio(String label) {
    return 'Format d\'image ($label)';
  }

  @override
  String get playerRefreshStream => 'Actualiser le flux';

  @override
  String get playerStreamInfo => 'Infos sur le flux';

  @override
  String get playerPip => 'Incrustation vidéo';

  @override
  String get playerSleepTimer => 'Minuterie de veille';

  @override
  String get playerExternalPlayer => 'Lecteur externe';

  @override
  String get playerSearchChannels => 'Rechercher des chaînes';

  @override
  String get playerChannelList => 'Liste des chaînes';

  @override
  String get playerScreenshot => 'Capture d\'écran';

  @override
  String playerStreamQualityOption(String label) {
    return 'Qualité du flux ($label)';
  }

  @override
  String playerDeinterlace(String mode) {
    return 'Désentrelacement ($mode)';
  }

  @override
  String get playerSyncOffset => 'Décalage de synchronisation';

  @override
  String playerAudioPassthrough(String state) {
    return 'Passage audio ($state)';
  }

  @override
  String get playerAudioOutputDevice => 'Périphérique de sortie audio';

  @override
  String playerAlwaysOnTop(String state) {
    return 'Toujours au premier plan ($state)';
  }

  @override
  String playerShaders(String label) {
    return 'Shaders ($label)';
  }

  @override
  String get playerSubtitlesSectionAudio => 'AUDIO';

  @override
  String get playerSubtitlesSectionSubtitles => 'SOUS-TITRES';

  @override
  String get playerSubtitlesSecondHint => '(appui long = 2e)';

  @override
  String get playerSubtitlesCcStyle => 'Style CC';

  @override
  String get playerSyncOffsetAudio => 'Audio';

  @override
  String get playerSyncOffsetSubtitle => 'Sous-titre';

  @override
  String get playerSyncOffsetResetToZero => 'Réinitialiser à 0';

  @override
  String get playerNoAudioDevices => 'Aucun périphérique audio trouvé.';

  @override
  String get playerSpeedLive => 'Vitesse (direct)';

  @override
  String get playerSpeed => 'Vitesse';

  @override
  String get playerVolumeLabel => 'Volume';

  @override
  String playerVolumePercent(int percent) {
    return 'Volume $percent %';
  }

  @override
  String playerSwitchProfileTooltip(String name) {
    return 'Changer de profil ($name)';
  }

  @override
  String playerTimeRemaining(String duration) {
    return '$duration restant';
  }

  @override
  String get playerSubtitleFontWeight => 'GRAISSE DE POLICE';

  @override
  String get playerSubtitleBold => 'Gras';

  @override
  String get playerSubtitleNormal => 'Normal';

  @override
  String get playerSubtitleFontSize => 'TAILLE DE POLICE';

  @override
  String playerSubtitlePosition(int value) {
    return 'POSITION ($value %)';
  }

  @override
  String get playerSubtitleTextColor => 'COULEUR DU TEXTE';

  @override
  String get playerSubtitleOutlineColor => 'COULEUR DU CONTOUR';

  @override
  String playerSubtitleOutlineSize(String value) {
    return 'TAILLE DU CONTOUR ($value)';
  }

  @override
  String get playerSubtitleBackground => 'ARRIÈRE-PLAN';

  @override
  String playerSubtitleBgOpacity(int value) {
    return 'OPACITÉ DU FOND ($value %)';
  }

  @override
  String get playerSubtitleShadow => 'OMBRE';

  @override
  String get playerSubtitlePreview => 'APERÇU';

  @override
  String get playerSubtitleSampleText => 'Exemple de sous-titre';

  @override
  String get playerSubtitleResetDefaults => 'Restaurer les valeurs par défaut';

  @override
  String playerSleepTimerStoppingIn(String duration) {
    return 'Arrêt dans $duration';
  }

  @override
  String get playerSleepTimerCancelTimer => 'Annuler la minuterie';

  @override
  String playerSleepTimerMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String playerSleepTimerSetTo(int minutes) {
    return 'Régler la minuterie de veille sur $minutes minutes';
  }

  @override
  String get playerStreamStats => 'Statistiques du flux';

  @override
  String get playerStreamStatsBuffer => 'Tampon';

  @override
  String get playerStreamStatsFps => 'FPS';

  @override
  String get playerStreamStatsCopied => 'Copié !';

  @override
  String get playerStreamStatsCopy => 'Copier les statistiques';

  @override
  String get playerStreamStatsInterlaced => 'Entrelacé';

  @override
  String playerNextUpIn(int seconds) {
    return 'Suivant dans $seconds';
  }

  @override
  String get playerPlayNow => 'Lire maintenant';

  @override
  String get playerFinished => 'Terminé';

  @override
  String get playerWatchAgain => 'Regarder à nouveau';

  @override
  String get playerBrowseMore => 'Parcourir davantage';

  @override
  String get playerShortcutsTitle => 'Raccourcis clavier';

  @override
  String get playerShortcutsCloseEsc => 'Fermer (Échap)';

  @override
  String get playerShortcutsPlayback => 'Lecture';

  @override
  String get playerShortcutsPlayPause => 'Lire / Pause';

  @override
  String get playerShortcutsSeek => 'Avancer/reculer ±10 s';

  @override
  String get playerShortcutsSpeedStep => 'Vitesse −/+ pas';

  @override
  String get playerShortcutsSpeedFine => 'Vitesse −/+ 0,1x';

  @override
  String get playerShortcutsJumpPercent => 'Sauter à % (VOD)';

  @override
  String get playerShortcutsFrameStep => 'Image par image ±1';

  @override
  String get playerShortcutsAspectRatio => 'Changer le format d\'image';

  @override
  String get playerShortcutsCycleSubtitles => 'Changer les sous-titres';

  @override
  String get playerShortcutsVolume => 'Volume';

  @override
  String get playerShortcutsVolumeAdjust => 'Volume ±10 %';

  @override
  String get playerShortcutsMute => 'Muet / activer le son';

  @override
  String get playerShortcutsDisplay => 'Affichage';

  @override
  String get playerShortcutsFullscreenToggle => 'Basculer plein écran';

  @override
  String get playerShortcutsExitFullscreen => 'Quitter le plein écran / retour';

  @override
  String get playerShortcutsStreamInfo => 'Infos sur le flux';

  @override
  String get playerShortcutsLiveTv => 'TV en direct';

  @override
  String get playerShortcutsChannelUp => 'Chaîne suivante';

  @override
  String get playerShortcutsChannelDown => 'Chaîne précédente';

  @override
  String get playerShortcutsChannelList => 'Liste des chaînes';

  @override
  String get playerShortcutsToggleZap => 'Afficher/masquer le zap';

  @override
  String get playerShortcutsGeneral => 'Général';

  @override
  String get playerShortcutsSubtitlesCc => 'Sous-titres / CC';

  @override
  String get playerShortcutsScreenLock => 'Verrouillage d\'écran';

  @override
  String get playerShortcutsThisHelp => 'Cet écran d\'aide';

  @override
  String get playerShortcutsEscToClose => 'Appuyer sur Échap ou ? pour fermer';

  @override
  String get playerZapChannels => 'Chaînes';

  @override
  String get playerBookmark => 'Signet';

  @override
  String get playerEditBookmark => 'Modifier le signet';

  @override
  String get playerBookmarkLabelHint => 'Libellé du signet (facultatif)';

  @override
  String get playerBookmarkLabelInput => 'Libellé du signet';

  @override
  String playerBookmarkAdded(String label) {
    return 'Signet ajouté à $label';
  }

  @override
  String get playerExpandToFullscreen => 'Ouvrir en plein écran';

  @override
  String get playerUnmute => 'Activer le son';

  @override
  String get playerMute => 'Couper le son';

  @override
  String get playerStopPlayback => 'Arrêter la lecture';

  @override
  String get playerQueueUpNext => 'Suivant';

  @override
  String playerQueueSeasonEpisodes(int number) {
    return 'Épisodes de la saison $number';
  }

  @override
  String get playerQueueEpisodes => 'Épisodes';

  @override
  String get playerQueueEmpty => 'La file d\'attente est vide';

  @override
  String get playerQueueClose => 'Fermer la file d\'attente';

  @override
  String get playerQueueOpen => 'File d\'attente';

  @override
  String playerEpisodeNumber(String number) {
    return 'Épisode $number';
  }

  @override
  String get playerScreenLocked => 'Écran verrouillé';

  @override
  String get playerHoldToUnlock => 'Maintenir pour déverrouiller';

  @override
  String get playerScreenshotSaved => 'Capture d\'écran enregistrée';

  @override
  String get playerScreenshotFailed => 'Échec de la capture d\'écran';

  @override
  String get playerSkipSegment => 'Passer le segment';

  @override
  String playerSkipType(String type) {
    return 'Passer $type';
  }

  @override
  String get playerCouldNotOpenExternal =>
      'Impossible d\'ouvrir le lecteur externe';

  @override
  String get playerExitMultiView => 'Quitter le Multi-View';

  @override
  String get playerScreensaverBouncingLogo => 'Logo rebondissant';

  @override
  String get playerScreensaverClock => 'Horloge';

  @override
  String get playerScreensaverBlackScreen => 'Écran noir';

  @override
  String get streamProfileAuto => 'Auto';

  @override
  String get streamProfileAutoDesc =>
      'Ajuster automatiquement la qualité selon le réseau';

  @override
  String get streamProfileLow => 'Faible';

  @override
  String get streamProfileLowDesc => 'Qualité SD, max ~1 Mbit/s';

  @override
  String get streamProfileMedium => 'Moyen';

  @override
  String get streamProfileMediumDesc => 'Qualité HD, max ~3 Mbit/s';

  @override
  String get streamProfileHigh => 'Élevé';

  @override
  String get streamProfileHighDesc => 'Qualité Full HD, max ~8 Mbit/s';

  @override
  String get streamProfileMaximum => 'Maximum';

  @override
  String get streamProfileMaximumDesc =>
      'Meilleure qualité disponible, sans limite';

  @override
  String get segmentIntro => 'Intro';

  @override
  String get segmentOutro => 'Outro / Générique';

  @override
  String get segmentRecap => 'Récapitulatif';

  @override
  String get segmentCommercial => 'Publicité';

  @override
  String get segmentPreview => 'Aperçu';

  @override
  String get segmentSkipNone => 'Aucun';

  @override
  String get segmentSkipAsk => 'Demander avant de passer';

  @override
  String get segmentSkipOnce => 'Passer une fois';

  @override
  String get segmentSkipAlways => 'Toujours passer';

  @override
  String get nextUpOff => 'Désactivé';

  @override
  String get nextUpStatic => 'Statique (32 s avant la fin)';

  @override
  String get nextUpSmart => 'Intelligent (détection générique)';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSearchSettings => 'Rechercher dans les paramètres';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get settingsSources => 'Sources';

  @override
  String get settingsPlayback => 'Lecture';

  @override
  String get settingsData => 'Données';

  @override
  String get settingsAdvanced => 'Avancé';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Défaut du système';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutUpdates => 'Mises à jour';

  @override
  String get settingsAboutCheckForUpdates => 'Vérifier les mises à jour';

  @override
  String get settingsAboutUpToDate => 'Vous êtes à jour';

  @override
  String settingsAboutUpdateAvailable(String version) {
    return 'Mise à jour disponible : $version';
  }

  @override
  String get settingsAboutLicenses => 'Licences';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsAccentColor => 'Couleur d\'accentuation';

  @override
  String get settingsTextScale => 'Échelle du texte';

  @override
  String get settingsDensity => 'Densité';

  @override
  String get settingsBackup => 'Sauvegarde et restauration';

  @override
  String get settingsBackupCreate => 'Créer une sauvegarde';

  @override
  String get settingsBackupRestore => 'Restaurer une sauvegarde';

  @override
  String get settingsBackupAuto => 'Sauvegarde automatique';

  @override
  String get settingsBackupCloudSync => 'Synchronisation cloud';

  @override
  String get settingsParentalControls => 'Contrôle parental';

  @override
  String get settingsParentalSetPin => 'Définir un code PIN';

  @override
  String get settingsParentalChangePin => 'Modifier le code PIN';

  @override
  String get settingsParentalRemovePin => 'Supprimer le code PIN';

  @override
  String get settingsParentalBlockedCategories => 'Catégories bloquées';

  @override
  String get settingsNetwork => 'Réseau';

  @override
  String get settingsNetworkDiagnostics => 'Diagnostics réseau';

  @override
  String get settingsNetworkProxy => 'Proxy';

  @override
  String get settingsPlaybackHardwareDecoder => 'Décodeur matériel';

  @override
  String get settingsPlaybackBufferSize => 'Taille du tampon';

  @override
  String get settingsPlaybackDeinterlace => 'Désentrelacement';

  @override
  String get settingsPlaybackUpscaling => 'Suréchantillonnage';

  @override
  String get settingsPlaybackAudioOutput => 'Sortie audio';

  @override
  String get settingsPlaybackLoudnessNorm => 'Normalisation du volume';

  @override
  String get settingsPlaybackVolumeBoost => 'Amplification du volume';

  @override
  String get settingsPlaybackAudioPassthrough => 'Passage audio';

  @override
  String get settingsPlaybackSegmentSkip => 'Passer les segments';

  @override
  String get settingsPlaybackNextUp => 'Suivant';

  @override
  String get settingsPlaybackScreensaver => 'Économiseur d\'écran';

  @override
  String get settingsPlaybackExternalPlayer => 'Lecteur externe';

  @override
  String get settingsSourceAdd => 'Ajouter une source';

  @override
  String get settingsSourceEdit => 'Modifier la source';

  @override
  String get settingsSourceDelete => 'Supprimer la source';

  @override
  String get settingsSourceSync => 'Synchroniser maintenant';

  @override
  String get settingsSourceSortOrder => 'Ordre de tri';

  @override
  String get settingsDataClearCache => 'Vider le cache';

  @override
  String get settingsDataClearHistory => 'Effacer l\'historique';

  @override
  String get settingsDataExport => 'Exporter les données';

  @override
  String get settingsDataImport => 'Importer les données';

  @override
  String get settingsAdvancedDebug => 'Mode débogage';

  @override
  String get settingsAdvancedStreamProxy => 'Proxy de flux';

  @override
  String get settingsAdvancedAutoUpdate => 'Mise à jour automatique';

  @override
  String get iptvMultiView => 'Multi-View';

  @override
  String get iptvTvGuide => 'Guide TV';

  @override
  String get iptvBackToGroups => 'Retour aux groupes';

  @override
  String get iptvSearchChannels => 'Rechercher des chaînes';

  @override
  String get iptvListGridView => 'Vue liste';

  @override
  String get iptvGridView => 'Vue grille';

  @override
  String iptvChannelHidden(String name) {
    return '$name masqué';
  }

  @override
  String get iptvSortDone => 'Terminé';

  @override
  String get iptvSortResetToDefault => 'Réinitialiser par défaut';

  @override
  String get iptvSortByPlaylistOrder => 'Par ordre de playlist';

  @override
  String get iptvSortByName => 'Par nom';

  @override
  String get iptvSortByRecent => 'Par récence';

  @override
  String get iptvSortByPopularity => 'Par popularité';

  @override
  String get epgNowPlaying => 'En ce moment';

  @override
  String get epgNoData => 'Aucune donnée EPG disponible';

  @override
  String get epgSetReminder => 'Définir un rappel';

  @override
  String get epgCancelReminder => 'Annuler le rappel';

  @override
  String get epgRecord => 'Enregistrer';

  @override
  String get epgCancelRecording => 'Annuler l\'enregistrement';

  @override
  String get vodMovies => 'Films';

  @override
  String get vodSeries => 'Séries';

  @override
  String vodSeasonN(int number) {
    return 'Saison $number';
  }

  @override
  String vodEpisodeN(int number) {
    return 'Épisode $number';
  }

  @override
  String get vodWatchNow => 'Regarder maintenant';

  @override
  String get vodResume => 'Reprendre';

  @override
  String get vodContinueWatching => 'Continuer à regarder';

  @override
  String get vodRecommended => 'Recommandé';

  @override
  String get vodRecentlyAdded => 'Ajouté récemment';

  @override
  String get vodNoItems => 'Aucun élément trouvé';

  @override
  String get dvrSchedule => 'Programme';

  @override
  String get dvrRecordings => 'Enregistrements';

  @override
  String get dvrScheduleRecording => 'Planifier un enregistrement';

  @override
  String get dvrEditRecording => 'Modifier l\'enregistrement';

  @override
  String get dvrDeleteRecording => 'Supprimer l\'enregistrement';

  @override
  String get dvrNoRecordings => 'Aucun enregistrement';

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get searchHint => 'Rechercher des chaînes, films, séries…';

  @override
  String get searchNoResults => 'Aucun résultat trouvé';

  @override
  String get searchFilterAll => 'Tout';

  @override
  String get searchFilterChannels => 'Chaînes';

  @override
  String get searchFilterMovies => 'Films';

  @override
  String get searchFilterSeries => 'Séries';

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
  String get homeWhatsOn => 'À l\'affiche';

  @override
  String get homeContinueWatching => 'Continuer à regarder';

  @override
  String get homeRecentChannels => 'Chaînes récentes';

  @override
  String get homeMyList => 'Ma liste';

  @override
  String get homeQuickAccess => 'Accès rapide';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get favoritesEmpty => 'Aucun favori pour l\'instant';

  @override
  String get favoritesAddSome =>
      'Ajoutez des chaînes, films ou séries à vos favoris';

  @override
  String get profilesTitle => 'Profils';

  @override
  String get profilesCreate => 'Créer un profil';

  @override
  String get profilesEdit => 'Modifier le profil';

  @override
  String get profilesDelete => 'Supprimer le profil';

  @override
  String get profilesManage => 'Gérer les profils';

  @override
  String get profilesWhoIsWatching => 'Qui regarde ?';

  @override
  String get onboardingWelcome => 'Bienvenue sur CrispyTivi';

  @override
  String get onboardingAddSource => 'Ajouter votre première source';

  @override
  String get onboardingChooseType => 'Choisir le type de source';

  @override
  String get onboardingIptv => 'IPTV (M3U / Xtream)';

  @override
  String get onboardingJellyfin => 'Jellyfin';

  @override
  String get onboardingEmby => 'Emby';

  @override
  String get onboardingPlex => 'Plex';

  @override
  String get onboardingSyncing => 'Connexion et chargement des chaînes…';

  @override
  String get onboardingDone => 'Tout est prêt !';

  @override
  String get onboardingStartWatching => 'Commencer à regarder';

  @override
  String get cloudSyncTitle => 'Synchronisation cloud';

  @override
  String get cloudSyncSignInGoogle => 'Se connecter avec Google';

  @override
  String get cloudSyncSignOut => 'Se déconnecter';

  @override
  String cloudSyncLastSync(String time) {
    return 'Dernière sync : $time';
  }

  @override
  String get cloudSyncNever => 'Jamais';

  @override
  String get cloudSyncConflict => 'Conflit de synchronisation';

  @override
  String get cloudSyncKeepLocal => 'Conserver local';

  @override
  String get cloudSyncKeepRemote => 'Conserver distant';

  @override
  String get castTitle => 'Diffuser';

  @override
  String get castSearching => 'Recherche d\'appareils…';

  @override
  String get castNoDevices => 'Aucun appareil trouvé';

  @override
  String get castDisconnect => 'Déconnecter';

  @override
  String get multiviewTitle => 'Multi-View';

  @override
  String get multiviewAddStream => 'Ajouter un flux';

  @override
  String get multiviewRemoveStream => 'Supprimer le flux';

  @override
  String get multiviewSaveLayout => 'Enregistrer la disposition';

  @override
  String get multiviewLoadLayout => 'Charger la disposition';

  @override
  String get multiviewLayoutName => 'Nom de la disposition';

  @override
  String get multiviewDeleteLayout => 'Supprimer la disposition';

  @override
  String get mediaServerUrl => 'URL du serveur';

  @override
  String get mediaServerUsername => 'Nom d\'utilisateur';

  @override
  String get mediaServerPassword => 'Mot de passe';

  @override
  String get mediaServerSignIn => 'Se connecter';

  @override
  String get mediaServerConnecting => 'Connexion…';

  @override
  String get mediaServerConnectionFailed => 'Échec de la connexion';

  @override
  String onboardingChannelsLoaded(int count) {
    return '$count chaînes chargées !';
  }

  @override
  String get onboardingEnterApp => 'Accéder à l\'appli';

  @override
  String get onboardingEnterAppLabel => 'Entrer dans l\'application';

  @override
  String get onboardingCouldNotConnect => 'Connexion impossible';

  @override
  String get onboardingRetryLabel => 'Réessayer la connexion';

  @override
  String get onboardingEditSource => 'Modifier les détails de la source';

  @override
  String get playerAudioSectionLabel => 'AUDIO';

  @override
  String get playerSubtitlesSectionLabel => 'SOUS-TITRES';

  @override
  String get playerSwitchProfileTitle => 'Changer de profil';

  @override
  String get playerCopyStreamUrl => 'Copier l\'URL du flux';

  @override
  String get cloudSyncSyncing => 'Synchronisation…';

  @override
  String get cloudSyncNow => 'Synchroniser maintenant';

  @override
  String get cloudSyncForceUpload => 'Forcer l\'envoi';

  @override
  String get cloudSyncForceDownload => 'Forcer le téléchargement';

  @override
  String get cloudSyncAutoSync => 'Synchronisation automatique';

  @override
  String get cloudSyncThisDevice => 'Cet appareil';

  @override
  String get cloudSyncCloud => 'Cloud';

  @override
  String get cloudSyncNewer => 'PLUS RÉCENT';

  @override
  String get contextMenuAddFavorite => 'Ajouter aux favoris';

  @override
  String get contextMenuRemoveFavorite => 'Retirer des favoris';

  @override
  String get contextMenuSwitchStream => 'Changer la source du flux';

  @override
  String get contextMenuCopyUrl => 'Copier l\'URL du flux';

  @override
  String get contextMenuOpenExternal => 'Lire dans un lecteur externe';

  @override
  String get contextMenuPlay => 'Lire';

  @override
  String get contextMenuAddFavoriteCategory =>
      'Ajouter aux catégories favorites';

  @override
  String get contextMenuRemoveFavoriteCategory =>
      'Retirer des catégories favorites';

  @override
  String get contextMenuFilterCategory => 'Filtrer par cette catégorie';

  @override
  String get confirmDeleteCancel => 'Annuler';

  @override
  String get confirmDeleteAction => 'Supprimer';
}
