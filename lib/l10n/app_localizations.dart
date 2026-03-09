import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CrispyTivi'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get commonAuto;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String commonError(String message);

  /// No description provided for @commonOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get commonOr;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get commonGoToSettings;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get commonNew;

  /// No description provided for @commonLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get commonLive;

  /// No description provided for @commonFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get commonFavorites;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get navLiveTv;

  /// No description provided for @navGuide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get navGuide;

  /// No description provided for @navMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get navMovies;

  /// No description provided for @navSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get navSeries;

  /// No description provided for @navDvr.
  ///
  /// In en, this message translates to:
  /// **'DVR'**
  String get navDvr;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @breadcrumbProfiles.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get breadcrumbProfiles;

  /// No description provided for @breadcrumbJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin'**
  String get breadcrumbJellyfin;

  /// No description provided for @breadcrumbEmby.
  ///
  /// In en, this message translates to:
  /// **'Emby'**
  String get breadcrumbEmby;

  /// No description provided for @breadcrumbPlex.
  ///
  /// In en, this message translates to:
  /// **'Plex'**
  String get breadcrumbPlex;

  /// No description provided for @breadcrumbCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get breadcrumbCloud;

  /// No description provided for @breadcrumbMultiView.
  ///
  /// In en, this message translates to:
  /// **'Multi-View'**
  String get breadcrumbMultiView;

  /// No description provided for @breadcrumbDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get breadcrumbDetail;

  /// No description provided for @breadcrumbNavigateToParent.
  ///
  /// In en, this message translates to:
  /// **'Navigate to parent'**
  String get breadcrumbNavigateToParent;

  /// No description provided for @sideNavSwitchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch Profile'**
  String get sideNavSwitchProfile;

  /// No description provided for @sideNavManageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage profiles'**
  String get sideNavManageProfiles;

  /// No description provided for @sideNavSwitchProfileFor.
  ///
  /// In en, this message translates to:
  /// **'Switch profile: {name}'**
  String sideNavSwitchProfileFor(String name);

  /// No description provided for @sideNavEnterPinFor.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN for {name}'**
  String sideNavEnterPinFor(String name);

  /// No description provided for @sideNavActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get sideNavActive;

  /// No description provided for @sideNavPinProtected.
  ///
  /// In en, this message translates to:
  /// **'PIN protected'**
  String get sideNavPinProtected;

  /// No description provided for @fabWhatsOn.
  ///
  /// In en, this message translates to:
  /// **'What\'s On'**
  String get fabWhatsOn;

  /// No description provided for @fabRandomPick.
  ///
  /// In en, this message translates to:
  /// **'Random Pick'**
  String get fabRandomPick;

  /// No description provided for @fabLastChannel.
  ///
  /// In en, this message translates to:
  /// **'Last Channel'**
  String get fabLastChannel;

  /// No description provided for @fabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get fabSchedule;

  /// No description provided for @fabNewList.
  ///
  /// In en, this message translates to:
  /// **'New List'**
  String get fabNewList;

  /// No description provided for @offlineNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get offlineNoConnection;

  /// No description provided for @offlineConnectionRestored.
  ///
  /// In en, this message translates to:
  /// **'Connection restored'**
  String get offlineConnectionRestored;

  /// No description provided for @splashAppName.
  ///
  /// In en, this message translates to:
  /// **'CrispyTivi'**
  String get splashAppName;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @pinConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmPin;

  /// No description provided for @pinEnterAllDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter all 4 digits'**
  String get pinEnterAllDigits;

  /// No description provided for @pinDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinDoNotMatch;

  /// No description provided for @pinTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many incorrect attempts.'**
  String get pinTooManyAttempts;

  /// No description provided for @pinTryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Try again in {countdown}'**
  String pinTryAgainIn(String countdown);

  /// No description provided for @pinEnterSameAgain.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again to confirm'**
  String get pinEnterSameAgain;

  /// No description provided for @pinUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get pinUseBiometric;

  /// No description provided for @pinDigitN.
  ///
  /// In en, this message translates to:
  /// **'PIN digit {n}'**
  String pinDigitN(int n);

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinIncorrect;

  /// No description provided for @pinVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get pinVerificationFailed;

  /// No description provided for @pinBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed or canceled'**
  String get pinBiometricFailed;

  /// No description provided for @contextMenuRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get contextMenuRemoveFromFavorites;

  /// No description provided for @contextMenuAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get contextMenuAddToFavorites;

  /// No description provided for @contextMenuSwitchStreamSource.
  ///
  /// In en, this message translates to:
  /// **'Switch stream source'**
  String get contextMenuSwitchStreamSource;

  /// No description provided for @contextMenuSmartGroup.
  ///
  /// In en, this message translates to:
  /// **'Smart Group'**
  String get contextMenuSmartGroup;

  /// No description provided for @contextMenuMultiView.
  ///
  /// In en, this message translates to:
  /// **'Multi-View'**
  String get contextMenuMultiView;

  /// No description provided for @contextMenuAssignEpg.
  ///
  /// In en, this message translates to:
  /// **'Assign EPG'**
  String get contextMenuAssignEpg;

  /// No description provided for @contextMenuHideChannel.
  ///
  /// In en, this message translates to:
  /// **'Hide channel'**
  String get contextMenuHideChannel;

  /// No description provided for @contextMenuCopyStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy Stream URL'**
  String get contextMenuCopyStreamUrl;

  /// No description provided for @contextMenuPlayExternal.
  ///
  /// In en, this message translates to:
  /// **'Play in External Player'**
  String get contextMenuPlayExternal;

  /// No description provided for @contextMenuBlockChannel.
  ///
  /// In en, this message translates to:
  /// **'Block channel'**
  String get contextMenuBlockChannel;

  /// No description provided for @contextMenuViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get contextMenuViewDetails;

  /// No description provided for @contextMenuRemoveFromFavoriteCategories.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorite Categories'**
  String get contextMenuRemoveFromFavoriteCategories;

  /// No description provided for @contextMenuAddToFavoriteCategories.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorite Categories'**
  String get contextMenuAddToFavoriteCategories;

  /// No description provided for @contextMenuFilterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by this category'**
  String get contextMenuFilterByCategory;

  /// No description provided for @contextMenuCloseContextMenu.
  ///
  /// In en, this message translates to:
  /// **'Close context menu'**
  String get contextMenuCloseContextMenu;

  /// No description provided for @sourceAllSources.
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get sourceAllSources;

  /// No description provided for @sourceFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} source filter'**
  String sourceFilterLabel(String label);

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All {label}'**
  String categoryAll(String label);

  /// No description provided for @categorySelect.
  ///
  /// In en, this message translates to:
  /// **'Select {label}'**
  String categorySelect(String label);

  /// No description provided for @categorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search categories…'**
  String get categorySearchHint;

  /// No description provided for @categorySearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get categorySearchLabel;

  /// No description provided for @categoryRemoveFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorite categories'**
  String get categoryRemoveFromFavorites;

  /// No description provided for @categoryAddToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorite categories'**
  String get categoryAddToFavorites;

  /// No description provided for @sidebarExpandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarExpandSidebar;

  /// No description provided for @sidebarCollapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarCollapseSidebar;

  /// No description provided for @badgeNewEpisode.
  ///
  /// In en, this message translates to:
  /// **'NEW EP'**
  String get badgeNewEpisode;

  /// No description provided for @badgeNewSeason.
  ///
  /// In en, this message translates to:
  /// **'NEW SEASON'**
  String get badgeNewSeason;

  /// No description provided for @badgeRecording.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get badgeRecording;

  /// No description provided for @badgeExpiring.
  ///
  /// In en, this message translates to:
  /// **'EXPIRES'**
  String get badgeExpiring;

  /// No description provided for @toggleFavorite.
  ///
  /// In en, this message translates to:
  /// **'Toggle favorite'**
  String get toggleFavorite;

  /// No description provided for @playerSkipBack.
  ///
  /// In en, this message translates to:
  /// **'Skip back 10 seconds'**
  String get playerSkipBack;

  /// No description provided for @playerSkipForward.
  ///
  /// In en, this message translates to:
  /// **'Skip forward 10 seconds'**
  String get playerSkipForward;

  /// No description provided for @playerChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get playerChannels;

  /// No description provided for @playerRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get playerRecordings;

  /// No description provided for @playerCloseGuide.
  ///
  /// In en, this message translates to:
  /// **'Close Guide (G)'**
  String get playerCloseGuide;

  /// No description provided for @playerTvGuide.
  ///
  /// In en, this message translates to:
  /// **'TV Guide (G)'**
  String get playerTvGuide;

  /// No description provided for @playerAudioSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Audio & Subtitles'**
  String get playerAudioSubtitles;

  /// No description provided for @playerNoTracksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tracks available'**
  String get playerNoTracksAvailable;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get playerExitFullscreen;

  /// No description provided for @playerFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get playerFullscreen;

  /// No description provided for @playerUnlockScreen.
  ///
  /// In en, this message translates to:
  /// **'Unlock Screen'**
  String get playerUnlockScreen;

  /// No description provided for @playerLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock Screen'**
  String get playerLockScreen;

  /// No description provided for @playerStreamQuality.
  ///
  /// In en, this message translates to:
  /// **'Stream Quality'**
  String get playerStreamQuality;

  /// No description provided for @playerRotationLock.
  ///
  /// In en, this message translates to:
  /// **'Rotation Lock'**
  String get playerRotationLock;

  /// No description provided for @playerScreenBrightness.
  ///
  /// In en, this message translates to:
  /// **'Screen Brightness'**
  String get playerScreenBrightness;

  /// No description provided for @playerShaderPreset.
  ///
  /// In en, this message translates to:
  /// **'Shader Preset'**
  String get playerShaderPreset;

  /// No description provided for @playerAutoSystem.
  ///
  /// In en, this message translates to:
  /// **'Auto (System)'**
  String get playerAutoSystem;

  /// No description provided for @playerResetToAuto.
  ///
  /// In en, this message translates to:
  /// **'Reset to Auto'**
  String get playerResetToAuto;

  /// No description provided for @playerPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get playerPortrait;

  /// No description provided for @playerPortraitUpsideDown.
  ///
  /// In en, this message translates to:
  /// **'Portrait (upside down)'**
  String get playerPortraitUpsideDown;

  /// No description provided for @playerLandscapeLeft.
  ///
  /// In en, this message translates to:
  /// **'Landscape left'**
  String get playerLandscapeLeft;

  /// No description provided for @playerLandscapeRight.
  ///
  /// In en, this message translates to:
  /// **'Landscape right'**
  String get playerLandscapeRight;

  /// No description provided for @playerDeinterlaceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get playerDeinterlaceAuto;

  /// No description provided for @playerMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get playerMoreOptions;

  /// No description provided for @playerRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove Favorite'**
  String get playerRemoveFavorite;

  /// No description provided for @playerAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add Favorite'**
  String get playerAddFavorite;

  /// No description provided for @playerAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio Track'**
  String get playerAudioTrack;

  /// No description provided for @playerAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio ({label})'**
  String playerAspectRatio(String label);

  /// No description provided for @playerRefreshStream.
  ///
  /// In en, this message translates to:
  /// **'Refresh Stream'**
  String get playerRefreshStream;

  /// No description provided for @playerStreamInfo.
  ///
  /// In en, this message translates to:
  /// **'Stream Info'**
  String get playerStreamInfo;

  /// No description provided for @playerPip.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-Picture'**
  String get playerPip;

  /// No description provided for @playerSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get playerSleepTimer;

  /// No description provided for @playerExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'External Player'**
  String get playerExternalPlayer;

  /// No description provided for @playerSearchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search Channels'**
  String get playerSearchChannels;

  /// No description provided for @playerChannelList.
  ///
  /// In en, this message translates to:
  /// **'Channel List'**
  String get playerChannelList;

  /// No description provided for @playerScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get playerScreenshot;

  /// No description provided for @playerStreamQualityOption.
  ///
  /// In en, this message translates to:
  /// **'Stream Quality ({label})'**
  String playerStreamQualityOption(String label);

  /// No description provided for @playerDeinterlace.
  ///
  /// In en, this message translates to:
  /// **'Deinterlace ({mode})'**
  String playerDeinterlace(String mode);

  /// No description provided for @playerSyncOffset.
  ///
  /// In en, this message translates to:
  /// **'Sync Offset'**
  String get playerSyncOffset;

  /// No description provided for @playerAudioPassthrough.
  ///
  /// In en, this message translates to:
  /// **'Audio Passthrough ({state})'**
  String playerAudioPassthrough(String state);

  /// No description provided for @playerAudioOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio Output Device'**
  String get playerAudioOutputDevice;

  /// No description provided for @playerAlwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on Top ({state})'**
  String playerAlwaysOnTop(String state);

  /// No description provided for @playerShaders.
  ///
  /// In en, this message translates to:
  /// **'Shaders ({label})'**
  String playerShaders(String label);

  /// No description provided for @playerSubtitlesSectionAudio.
  ///
  /// In en, this message translates to:
  /// **'AUDIO'**
  String get playerSubtitlesSectionAudio;

  /// No description provided for @playerSubtitlesSectionSubtitles.
  ///
  /// In en, this message translates to:
  /// **'SUBTITLES'**
  String get playerSubtitlesSectionSubtitles;

  /// No description provided for @playerSubtitlesSecondHint.
  ///
  /// In en, this message translates to:
  /// **'(long-press = 2nd)'**
  String get playerSubtitlesSecondHint;

  /// No description provided for @playerSubtitlesCcStyle.
  ///
  /// In en, this message translates to:
  /// **'CC Style'**
  String get playerSubtitlesCcStyle;

  /// No description provided for @playerSyncOffsetAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerSyncOffsetAudio;

  /// No description provided for @playerSyncOffsetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get playerSyncOffsetSubtitle;

  /// No description provided for @playerSyncOffsetResetToZero.
  ///
  /// In en, this message translates to:
  /// **'Reset to 0'**
  String get playerSyncOffsetResetToZero;

  /// No description provided for @playerNoAudioDevices.
  ///
  /// In en, this message translates to:
  /// **'No audio devices found.'**
  String get playerNoAudioDevices;

  /// No description provided for @playerSpeedLive.
  ///
  /// In en, this message translates to:
  /// **'Speed (live)'**
  String get playerSpeedLive;

  /// No description provided for @playerSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playerSpeed;

  /// No description provided for @playerVolumeLabel.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolumeLabel;

  /// No description provided for @playerVolumePercent.
  ///
  /// In en, this message translates to:
  /// **'Volume {percent}%'**
  String playerVolumePercent(int percent);

  /// No description provided for @playerSwitchProfileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch profile ({name})'**
  String playerSwitchProfileTooltip(String name);

  /// No description provided for @playerTimeRemaining.
  ///
  /// In en, this message translates to:
  /// **'{duration} left'**
  String playerTimeRemaining(String duration);

  /// No description provided for @playerSubtitleFontWeight.
  ///
  /// In en, this message translates to:
  /// **'FONT WEIGHT'**
  String get playerSubtitleFontWeight;

  /// No description provided for @playerSubtitleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get playerSubtitleBold;

  /// No description provided for @playerSubtitleNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerSubtitleNormal;

  /// No description provided for @playerSubtitleFontSize.
  ///
  /// In en, this message translates to:
  /// **'FONT SIZE'**
  String get playerSubtitleFontSize;

  /// No description provided for @playerSubtitlePosition.
  ///
  /// In en, this message translates to:
  /// **'POSITION ({value}%)'**
  String playerSubtitlePosition(int value);

  /// No description provided for @playerSubtitleTextColor.
  ///
  /// In en, this message translates to:
  /// **'TEXT COLOR'**
  String get playerSubtitleTextColor;

  /// No description provided for @playerSubtitleOutlineColor.
  ///
  /// In en, this message translates to:
  /// **'OUTLINE COLOR'**
  String get playerSubtitleOutlineColor;

  /// No description provided for @playerSubtitleOutlineSize.
  ///
  /// In en, this message translates to:
  /// **'OUTLINE SIZE ({value})'**
  String playerSubtitleOutlineSize(String value);

  /// No description provided for @playerSubtitleBackground.
  ///
  /// In en, this message translates to:
  /// **'BACKGROUND'**
  String get playerSubtitleBackground;

  /// No description provided for @playerSubtitleBgOpacity.
  ///
  /// In en, this message translates to:
  /// **'BG OPACITY ({value}%)'**
  String playerSubtitleBgOpacity(int value);

  /// No description provided for @playerSubtitleShadow.
  ///
  /// In en, this message translates to:
  /// **'SHADOW'**
  String get playerSubtitleShadow;

  /// No description provided for @playerSubtitlePreview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get playerSubtitlePreview;

  /// No description provided for @playerSubtitleSampleText.
  ///
  /// In en, this message translates to:
  /// **'Sample subtitle text'**
  String get playerSubtitleSampleText;

  /// No description provided for @playerSubtitleResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get playerSubtitleResetDefaults;

  /// No description provided for @playerSleepTimerStoppingIn.
  ///
  /// In en, this message translates to:
  /// **'Stopping in {duration}'**
  String playerSleepTimerStoppingIn(String duration);

  /// No description provided for @playerSleepTimerCancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Timer'**
  String get playerSleepTimerCancelTimer;

  /// No description provided for @playerSleepTimerMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String playerSleepTimerMinutes(int minutes);

  /// No description provided for @playerSleepTimerSetTo.
  ///
  /// In en, this message translates to:
  /// **'Set sleep timer to {minutes} minutes'**
  String playerSleepTimerSetTo(int minutes);

  /// No description provided for @playerStreamStats.
  ///
  /// In en, this message translates to:
  /// **'Stream Stats'**
  String get playerStreamStats;

  /// No description provided for @playerStreamStatsBuffer.
  ///
  /// In en, this message translates to:
  /// **'Buffer'**
  String get playerStreamStatsBuffer;

  /// No description provided for @playerStreamStatsFps.
  ///
  /// In en, this message translates to:
  /// **'FPS'**
  String get playerStreamStatsFps;

  /// No description provided for @playerStreamStatsCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get playerStreamStatsCopied;

  /// No description provided for @playerStreamStatsCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy stats'**
  String get playerStreamStatsCopy;

  /// No description provided for @playerStreamStatsInterlaced.
  ///
  /// In en, this message translates to:
  /// **'Interlaced'**
  String get playerStreamStatsInterlaced;

  /// No description provided for @playerNextUpIn.
  ///
  /// In en, this message translates to:
  /// **'Up Next in {seconds}'**
  String playerNextUpIn(int seconds);

  /// No description provided for @playerPlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playerPlayNow;

  /// No description provided for @playerFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get playerFinished;

  /// No description provided for @playerWatchAgain.
  ///
  /// In en, this message translates to:
  /// **'Watch Again'**
  String get playerWatchAgain;

  /// No description provided for @playerBrowseMore.
  ///
  /// In en, this message translates to:
  /// **'Browse More'**
  String get playerBrowseMore;

  /// No description provided for @playerShortcutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get playerShortcutsTitle;

  /// No description provided for @playerShortcutsCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get playerShortcutsCloseEsc;

  /// No description provided for @playerShortcutsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playerShortcutsPlayback;

  /// No description provided for @playerShortcutsPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get playerShortcutsPlayPause;

  /// No description provided for @playerShortcutsSeek.
  ///
  /// In en, this message translates to:
  /// **'Seek ±10 s'**
  String get playerShortcutsSeek;

  /// No description provided for @playerShortcutsSpeedStep.
  ///
  /// In en, this message translates to:
  /// **'Speed −/+ step'**
  String get playerShortcutsSpeedStep;

  /// No description provided for @playerShortcutsSpeedFine.
  ///
  /// In en, this message translates to:
  /// **'Speed −/+ 0.1x'**
  String get playerShortcutsSpeedFine;

  /// No description provided for @playerShortcutsJumpPercent.
  ///
  /// In en, this message translates to:
  /// **'Jump to % (VOD)'**
  String get playerShortcutsJumpPercent;

  /// No description provided for @playerShortcutsFrameStep.
  ///
  /// In en, this message translates to:
  /// **'Frame step ±1'**
  String get playerShortcutsFrameStep;

  /// No description provided for @playerShortcutsAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Cycle aspect ratio'**
  String get playerShortcutsAspectRatio;

  /// No description provided for @playerShortcutsCycleSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Cycle subtitles'**
  String get playerShortcutsCycleSubtitles;

  /// No description provided for @playerShortcutsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerShortcutsVolume;

  /// No description provided for @playerShortcutsVolumeAdjust.
  ///
  /// In en, this message translates to:
  /// **'Volume ±10 %'**
  String get playerShortcutsVolumeAdjust;

  /// No description provided for @playerShortcutsMute.
  ///
  /// In en, this message translates to:
  /// **'Mute / unmute'**
  String get playerShortcutsMute;

  /// No description provided for @playerShortcutsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get playerShortcutsDisplay;

  /// No description provided for @playerShortcutsFullscreenToggle.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen toggle'**
  String get playerShortcutsFullscreenToggle;

  /// No description provided for @playerShortcutsExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen / back'**
  String get playerShortcutsExitFullscreen;

  /// No description provided for @playerShortcutsStreamInfo.
  ///
  /// In en, this message translates to:
  /// **'Stream info'**
  String get playerShortcutsStreamInfo;

  /// No description provided for @playerShortcutsLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get playerShortcutsLiveTv;

  /// No description provided for @playerShortcutsChannelUp.
  ///
  /// In en, this message translates to:
  /// **'Channel up'**
  String get playerShortcutsChannelUp;

  /// No description provided for @playerShortcutsChannelDown.
  ///
  /// In en, this message translates to:
  /// **'Channel down'**
  String get playerShortcutsChannelDown;

  /// No description provided for @playerShortcutsChannelList.
  ///
  /// In en, this message translates to:
  /// **'Channel list'**
  String get playerShortcutsChannelList;

  /// No description provided for @playerShortcutsToggleZap.
  ///
  /// In en, this message translates to:
  /// **'Toggle zap overlay'**
  String get playerShortcutsToggleZap;

  /// No description provided for @playerShortcutsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get playerShortcutsGeneral;

  /// No description provided for @playerShortcutsSubtitlesCc.
  ///
  /// In en, this message translates to:
  /// **'Subtitles / CC'**
  String get playerShortcutsSubtitlesCc;

  /// No description provided for @playerShortcutsScreenLock.
  ///
  /// In en, this message translates to:
  /// **'Screen lock'**
  String get playerShortcutsScreenLock;

  /// No description provided for @playerShortcutsThisHelp.
  ///
  /// In en, this message translates to:
  /// **'This help screen'**
  String get playerShortcutsThisHelp;

  /// No description provided for @playerShortcutsEscToClose.
  ///
  /// In en, this message translates to:
  /// **'Press Esc or ? to close'**
  String get playerShortcutsEscToClose;

  /// No description provided for @playerZapChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get playerZapChannels;

  /// No description provided for @playerBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get playerBookmark;

  /// No description provided for @playerEditBookmark.
  ///
  /// In en, this message translates to:
  /// **'Edit Bookmark'**
  String get playerEditBookmark;

  /// No description provided for @playerBookmarkLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Bookmark label (optional)'**
  String get playerBookmarkLabelHint;

  /// No description provided for @playerBookmarkLabelInput.
  ///
  /// In en, this message translates to:
  /// **'Bookmark label'**
  String get playerBookmarkLabelInput;

  /// No description provided for @playerBookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added at {label}'**
  String playerBookmarkAdded(String label);

  /// No description provided for @playerExpandToFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Expand to fullscreen'**
  String get playerExpandToFullscreen;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerStopPlayback.
  ///
  /// In en, this message translates to:
  /// **'Stop playback'**
  String get playerStopPlayback;

  /// No description provided for @playerQueueUpNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get playerQueueUpNext;

  /// No description provided for @playerQueueSeasonEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Season {number} Episodes'**
  String playerQueueSeasonEpisodes(int number);

  /// No description provided for @playerQueueEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get playerQueueEpisodes;

  /// No description provided for @playerQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get playerQueueEmpty;

  /// No description provided for @playerQueueClose.
  ///
  /// In en, this message translates to:
  /// **'Close Queue'**
  String get playerQueueClose;

  /// No description provided for @playerQueueOpen.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueueOpen;

  /// No description provided for @playerEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String playerEpisodeNumber(String number);

  /// No description provided for @playerScreenLocked.
  ///
  /// In en, this message translates to:
  /// **'Screen locked'**
  String get playerScreenLocked;

  /// No description provided for @playerHoldToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Hold to unlock'**
  String get playerHoldToUnlock;

  /// No description provided for @playerScreenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Screenshot saved'**
  String get playerScreenshotSaved;

  /// No description provided for @playerScreenshotFailed.
  ///
  /// In en, this message translates to:
  /// **'Screenshot failed'**
  String get playerScreenshotFailed;

  /// No description provided for @playerSkipSegment.
  ///
  /// In en, this message translates to:
  /// **'Skip segment'**
  String get playerSkipSegment;

  /// No description provided for @playerSkipType.
  ///
  /// In en, this message translates to:
  /// **'Skip {type}'**
  String playerSkipType(String type);

  /// No description provided for @playerCouldNotOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Could not open external player'**
  String get playerCouldNotOpenExternal;

  /// No description provided for @playerExitMultiView.
  ///
  /// In en, this message translates to:
  /// **'Exit Multi-View'**
  String get playerExitMultiView;

  /// No description provided for @playerScreensaverBouncingLogo.
  ///
  /// In en, this message translates to:
  /// **'Bouncing Logo'**
  String get playerScreensaverBouncingLogo;

  /// No description provided for @playerScreensaverClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get playerScreensaverClock;

  /// No description provided for @playerScreensaverBlackScreen.
  ///
  /// In en, this message translates to:
  /// **'Black Screen'**
  String get playerScreensaverBlackScreen;

  /// No description provided for @streamProfileAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get streamProfileAuto;

  /// No description provided for @streamProfileAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically adjust quality based on network'**
  String get streamProfileAutoDesc;

  /// No description provided for @streamProfileLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get streamProfileLow;

  /// No description provided for @streamProfileLowDesc.
  ///
  /// In en, this message translates to:
  /// **'SD quality, ~1 Mbps max'**
  String get streamProfileLowDesc;

  /// No description provided for @streamProfileMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get streamProfileMedium;

  /// No description provided for @streamProfileMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'HD quality, ~3 Mbps max'**
  String get streamProfileMediumDesc;

  /// No description provided for @streamProfileHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get streamProfileHigh;

  /// No description provided for @streamProfileHighDesc.
  ///
  /// In en, this message translates to:
  /// **'Full HD quality, ~8 Mbps max'**
  String get streamProfileHighDesc;

  /// No description provided for @streamProfileMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get streamProfileMaximum;

  /// No description provided for @streamProfileMaximumDesc.
  ///
  /// In en, this message translates to:
  /// **'Best available quality, no limit'**
  String get streamProfileMaximumDesc;

  /// No description provided for @segmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get segmentIntro;

  /// No description provided for @segmentOutro.
  ///
  /// In en, this message translates to:
  /// **'Outro / Credits'**
  String get segmentOutro;

  /// No description provided for @segmentRecap.
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get segmentRecap;

  /// No description provided for @segmentCommercial.
  ///
  /// In en, this message translates to:
  /// **'Commercial'**
  String get segmentCommercial;

  /// No description provided for @segmentPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get segmentPreview;

  /// No description provided for @segmentSkipNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get segmentSkipNone;

  /// No description provided for @segmentSkipAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask to Skip'**
  String get segmentSkipAsk;

  /// No description provided for @segmentSkipOnce.
  ///
  /// In en, this message translates to:
  /// **'Skip Once'**
  String get segmentSkipOnce;

  /// No description provided for @segmentSkipAlways.
  ///
  /// In en, this message translates to:
  /// **'Always Skip'**
  String get segmentSkipAlways;

  /// No description provided for @nextUpOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get nextUpOff;

  /// No description provided for @nextUpStatic.
  ///
  /// In en, this message translates to:
  /// **'Static (32s before end)'**
  String get nextUpStatic;

  /// No description provided for @nextUpSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart (credits-aware)'**
  String get nextUpSmart;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSearchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchSettings;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get settingsSources;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get settingsAdvanced;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get settingsAboutUpdates;

  /// No description provided for @settingsAboutCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get settingsAboutCheckForUpdates;

  /// No description provided for @settingsAboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get settingsAboutUpToDate;

  /// No description provided for @settingsAboutUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String settingsAboutUpdateAvailable(String version);

  /// No description provided for @settingsAboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get settingsAboutLicenses;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get settingsAccentColor;

  /// No description provided for @settingsTextScale.
  ///
  /// In en, this message translates to:
  /// **'Text Scale'**
  String get settingsTextScale;

  /// No description provided for @settingsDensity.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get settingsDensity;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackup;

  /// No description provided for @settingsBackupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get settingsBackupCreate;

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get settingsBackupAuto;

  /// No description provided for @settingsBackupCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get settingsBackupCloudSync;

  /// No description provided for @settingsParentalControls.
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get settingsParentalControls;

  /// No description provided for @settingsParentalSetPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get settingsParentalSetPin;

  /// No description provided for @settingsParentalChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsParentalChangePin;

  /// No description provided for @settingsParentalRemovePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get settingsParentalRemovePin;

  /// No description provided for @settingsParentalBlockedCategories.
  ///
  /// In en, this message translates to:
  /// **'Blocked Categories'**
  String get settingsParentalBlockedCategories;

  /// No description provided for @settingsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetwork;

  /// No description provided for @settingsNetworkDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Network Diagnostics'**
  String get settingsNetworkDiagnostics;

  /// No description provided for @settingsNetworkProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get settingsNetworkProxy;

  /// No description provided for @settingsPlaybackHardwareDecoder.
  ///
  /// In en, this message translates to:
  /// **'Hardware Decoder'**
  String get settingsPlaybackHardwareDecoder;

  /// No description provided for @settingsPlaybackBufferSize.
  ///
  /// In en, this message translates to:
  /// **'Buffer Size'**
  String get settingsPlaybackBufferSize;

  /// No description provided for @settingsPlaybackDeinterlace.
  ///
  /// In en, this message translates to:
  /// **'Deinterlace'**
  String get settingsPlaybackDeinterlace;

  /// No description provided for @settingsPlaybackUpscaling.
  ///
  /// In en, this message translates to:
  /// **'Upscaling'**
  String get settingsPlaybackUpscaling;

  /// No description provided for @settingsPlaybackAudioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio Output'**
  String get settingsPlaybackAudioOutput;

  /// No description provided for @settingsPlaybackLoudnessNorm.
  ///
  /// In en, this message translates to:
  /// **'Loudness Normalization'**
  String get settingsPlaybackLoudnessNorm;

  /// No description provided for @settingsPlaybackVolumeBoost.
  ///
  /// In en, this message translates to:
  /// **'Volume Boost'**
  String get settingsPlaybackVolumeBoost;

  /// No description provided for @settingsPlaybackAudioPassthrough.
  ///
  /// In en, this message translates to:
  /// **'Audio Passthrough'**
  String get settingsPlaybackAudioPassthrough;

  /// No description provided for @settingsPlaybackSegmentSkip.
  ///
  /// In en, this message translates to:
  /// **'Segment Skip'**
  String get settingsPlaybackSegmentSkip;

  /// No description provided for @settingsPlaybackNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next Up'**
  String get settingsPlaybackNextUp;

  /// No description provided for @settingsPlaybackScreensaver.
  ///
  /// In en, this message translates to:
  /// **'Screensaver'**
  String get settingsPlaybackScreensaver;

  /// No description provided for @settingsPlaybackExternalPlayer.
  ///
  /// In en, this message translates to:
  /// **'External Player'**
  String get settingsPlaybackExternalPlayer;

  /// No description provided for @settingsSourceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Source'**
  String get settingsSourceAdd;

  /// No description provided for @settingsSourceEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Source'**
  String get settingsSourceEdit;

  /// No description provided for @settingsSourceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Source'**
  String get settingsSourceDelete;

  /// No description provided for @settingsSourceSync.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsSourceSync;

  /// No description provided for @settingsSourceSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort Order'**
  String get settingsSourceSortOrder;

  /// No description provided for @settingsDataClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get settingsDataClearCache;

  /// No description provided for @settingsDataClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Watch History'**
  String get settingsDataClearHistory;

  /// No description provided for @settingsDataExport.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get settingsDataExport;

  /// No description provided for @settingsDataImport.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get settingsDataImport;

  /// No description provided for @settingsAdvancedDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug Mode'**
  String get settingsAdvancedDebug;

  /// No description provided for @settingsAdvancedStreamProxy.
  ///
  /// In en, this message translates to:
  /// **'Stream Proxy'**
  String get settingsAdvancedStreamProxy;

  /// No description provided for @settingsAdvancedAutoUpdate.
  ///
  /// In en, this message translates to:
  /// **'Auto Update'**
  String get settingsAdvancedAutoUpdate;

  /// No description provided for @iptvMultiView.
  ///
  /// In en, this message translates to:
  /// **'Multi-View'**
  String get iptvMultiView;

  /// No description provided for @iptvTvGuide.
  ///
  /// In en, this message translates to:
  /// **'TV Guide'**
  String get iptvTvGuide;

  /// No description provided for @iptvBackToGroups.
  ///
  /// In en, this message translates to:
  /// **'Back to groups'**
  String get iptvBackToGroups;

  /// No description provided for @iptvSearchChannels.
  ///
  /// In en, this message translates to:
  /// **'Search channels'**
  String get iptvSearchChannels;

  /// No description provided for @iptvListGridView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get iptvListGridView;

  /// No description provided for @iptvGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid View'**
  String get iptvGridView;

  /// No description provided for @iptvChannelHidden.
  ///
  /// In en, this message translates to:
  /// **'{name} hidden'**
  String iptvChannelHidden(String name);

  /// No description provided for @iptvSortDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get iptvSortDone;

  /// No description provided for @iptvSortResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get iptvSortResetToDefault;

  /// No description provided for @iptvSortByPlaylistOrder.
  ///
  /// In en, this message translates to:
  /// **'By Playlist Order'**
  String get iptvSortByPlaylistOrder;

  /// No description provided for @iptvSortByName.
  ///
  /// In en, this message translates to:
  /// **'By Name'**
  String get iptvSortByName;

  /// No description provided for @iptvSortByRecent.
  ///
  /// In en, this message translates to:
  /// **'By Recent'**
  String get iptvSortByRecent;

  /// No description provided for @iptvSortByPopularity.
  ///
  /// In en, this message translates to:
  /// **'By Popularity'**
  String get iptvSortByPopularity;

  /// No description provided for @epgNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get epgNowPlaying;

  /// No description provided for @epgNoData.
  ///
  /// In en, this message translates to:
  /// **'No EPG data available'**
  String get epgNoData;

  /// No description provided for @epgSetReminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get epgSetReminder;

  /// No description provided for @epgCancelReminder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reminder'**
  String get epgCancelReminder;

  /// No description provided for @epgRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get epgRecord;

  /// No description provided for @epgCancelRecording.
  ///
  /// In en, this message translates to:
  /// **'Cancel Recording'**
  String get epgCancelRecording;

  /// No description provided for @vodMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get vodMovies;

  /// No description provided for @vodSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get vodSeries;

  /// No description provided for @vodSeasonN.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String vodSeasonN(int number);

  /// No description provided for @vodEpisodeN.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String vodEpisodeN(int number);

  /// No description provided for @vodWatchNow.
  ///
  /// In en, this message translates to:
  /// **'Watch Now'**
  String get vodWatchNow;

  /// No description provided for @vodResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get vodResume;

  /// No description provided for @vodContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get vodContinueWatching;

  /// No description provided for @vodRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get vodRecommended;

  /// No description provided for @vodRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get vodRecentlyAdded;

  /// No description provided for @vodNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get vodNoItems;

  /// No description provided for @dvrSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get dvrSchedule;

  /// No description provided for @dvrRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get dvrRecordings;

  /// No description provided for @dvrScheduleRecording.
  ///
  /// In en, this message translates to:
  /// **'Schedule Recording'**
  String get dvrScheduleRecording;

  /// No description provided for @dvrEditRecording.
  ///
  /// In en, this message translates to:
  /// **'Edit Recording'**
  String get dvrEditRecording;

  /// No description provided for @dvrDeleteRecording.
  ///
  /// In en, this message translates to:
  /// **'Delete Recording'**
  String get dvrDeleteRecording;

  /// No description provided for @dvrNoRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings'**
  String get dvrNoRecordings;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search channels, movies, series…'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFilterAll;

  /// No description provided for @searchFilterChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get searchFilterChannels;

  /// No description provided for @searchFilterMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get searchFilterMovies;

  /// No description provided for @searchFilterSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get searchFilterSeries;

  /// No description provided for @homeWhatsOn.
  ///
  /// In en, this message translates to:
  /// **'What\'s On Now'**
  String get homeWhatsOn;

  /// No description provided for @homeContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get homeContinueWatching;

  /// No description provided for @homeRecentChannels.
  ///
  /// In en, this message translates to:
  /// **'Recent Channels'**
  String get homeRecentChannels;

  /// No description provided for @homeMyList.
  ///
  /// In en, this message translates to:
  /// **'My List'**
  String get homeMyList;

  /// No description provided for @homeQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get homeQuickAccess;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmpty;

  /// No description provided for @favoritesAddSome.
  ///
  /// In en, this message translates to:
  /// **'Add channels, movies, or series to your favorites'**
  String get favoritesAddSome;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get profilesTitle;

  /// No description provided for @profilesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get profilesCreate;

  /// No description provided for @profilesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profilesEdit;

  /// No description provided for @profilesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get profilesDelete;

  /// No description provided for @profilesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get profilesManage;

  /// No description provided for @profilesWhoIsWatching.
  ///
  /// In en, this message translates to:
  /// **'Who\'s Watching?'**
  String get profilesWhoIsWatching;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to CrispyTivi'**
  String get onboardingWelcome;

  /// No description provided for @onboardingAddSource.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Source'**
  String get onboardingAddSource;

  /// No description provided for @onboardingChooseType.
  ///
  /// In en, this message translates to:
  /// **'Choose Source Type'**
  String get onboardingChooseType;

  /// No description provided for @onboardingIptv.
  ///
  /// In en, this message translates to:
  /// **'IPTV (M3U / Xtream)'**
  String get onboardingIptv;

  /// No description provided for @onboardingJellyfin.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin'**
  String get onboardingJellyfin;

  /// No description provided for @onboardingEmby.
  ///
  /// In en, this message translates to:
  /// **'Emby'**
  String get onboardingEmby;

  /// No description provided for @onboardingPlex.
  ///
  /// In en, this message translates to:
  /// **'Plex'**
  String get onboardingPlex;

  /// No description provided for @onboardingSyncing.
  ///
  /// In en, this message translates to:
  /// **'Connecting and loading channels…'**
  String get onboardingSyncing;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'All Set!'**
  String get onboardingDone;

  /// No description provided for @onboardingStartWatching.
  ///
  /// In en, this message translates to:
  /// **'Start Watching'**
  String get onboardingStartWatching;

  /// No description provided for @cloudSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSyncTitle;

  /// No description provided for @cloudSyncSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get cloudSyncSignInGoogle;

  /// No description provided for @cloudSyncSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get cloudSyncSignOut;

  /// No description provided for @cloudSyncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String cloudSyncLastSync(String time);

  /// No description provided for @cloudSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get cloudSyncNever;

  /// No description provided for @cloudSyncConflict.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict'**
  String get cloudSyncConflict;

  /// No description provided for @cloudSyncKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get cloudSyncKeepLocal;

  /// No description provided for @cloudSyncKeepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep Remote'**
  String get cloudSyncKeepRemote;

  /// No description provided for @castTitle.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get castTitle;

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get castSearching;

  /// No description provided for @castNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found'**
  String get castNoDevices;

  /// No description provided for @castDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get castDisconnect;

  /// No description provided for @multiviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-View'**
  String get multiviewTitle;

  /// No description provided for @multiviewAddStream.
  ///
  /// In en, this message translates to:
  /// **'Add Stream'**
  String get multiviewAddStream;

  /// No description provided for @multiviewRemoveStream.
  ///
  /// In en, this message translates to:
  /// **'Remove Stream'**
  String get multiviewRemoveStream;

  /// No description provided for @multiviewSaveLayout.
  ///
  /// In en, this message translates to:
  /// **'Save Layout'**
  String get multiviewSaveLayout;

  /// No description provided for @multiviewLoadLayout.
  ///
  /// In en, this message translates to:
  /// **'Load Layout'**
  String get multiviewLoadLayout;

  /// No description provided for @multiviewLayoutName.
  ///
  /// In en, this message translates to:
  /// **'Layout name'**
  String get multiviewLayoutName;

  /// No description provided for @multiviewDeleteLayout.
  ///
  /// In en, this message translates to:
  /// **'Delete Layout'**
  String get multiviewDeleteLayout;

  /// No description provided for @mediaServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get mediaServerUrl;

  /// No description provided for @mediaServerUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get mediaServerUsername;

  /// No description provided for @mediaServerPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get mediaServerPassword;

  /// No description provided for @mediaServerSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get mediaServerSignIn;

  /// No description provided for @mediaServerConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get mediaServerConnecting;

  /// No description provided for @mediaServerConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get mediaServerConnectionFailed;

  /// No description provided for @onboardingChannelsLoaded.
  ///
  /// In en, this message translates to:
  /// **'{count} channels loaded!'**
  String onboardingChannelsLoaded(int count);

  /// No description provided for @onboardingEnterApp.
  ///
  /// In en, this message translates to:
  /// **'Enter App'**
  String get onboardingEnterApp;

  /// No description provided for @onboardingEnterAppLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter the app'**
  String get onboardingEnterAppLabel;

  /// No description provided for @onboardingCouldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect'**
  String get onboardingCouldNotConnect;

  /// No description provided for @onboardingRetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry connection'**
  String get onboardingRetryLabel;

  /// No description provided for @onboardingEditSource.
  ///
  /// In en, this message translates to:
  /// **'Edit source details'**
  String get onboardingEditSource;

  /// No description provided for @playerAudioSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'AUDIO'**
  String get playerAudioSectionLabel;

  /// No description provided for @playerSubtitlesSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'SUBTITLES'**
  String get playerSubtitlesSectionLabel;

  /// No description provided for @playerSwitchProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Profile'**
  String get playerSwitchProfileTitle;

  /// No description provided for @playerCopyStreamUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy Stream URL'**
  String get playerCopyStreamUrl;

  /// No description provided for @cloudSyncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get cloudSyncSyncing;

  /// No description provided for @cloudSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get cloudSyncNow;

  /// No description provided for @cloudSyncForceUpload.
  ///
  /// In en, this message translates to:
  /// **'Force Upload'**
  String get cloudSyncForceUpload;

  /// No description provided for @cloudSyncForceDownload.
  ///
  /// In en, this message translates to:
  /// **'Force Download'**
  String get cloudSyncForceDownload;

  /// No description provided for @cloudSyncAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync'**
  String get cloudSyncAutoSync;

  /// No description provided for @cloudSyncThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This Device'**
  String get cloudSyncThisDevice;

  /// No description provided for @cloudSyncCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudSyncCloud;

  /// No description provided for @cloudSyncNewer.
  ///
  /// In en, this message translates to:
  /// **'NEWER'**
  String get cloudSyncNewer;

  /// No description provided for @contextMenuAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get contextMenuAddFavorite;

  /// No description provided for @contextMenuRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get contextMenuRemoveFavorite;

  /// No description provided for @contextMenuSwitchStream.
  ///
  /// In en, this message translates to:
  /// **'Switch stream source'**
  String get contextMenuSwitchStream;

  /// No description provided for @contextMenuCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy Stream URL'**
  String get contextMenuCopyUrl;

  /// No description provided for @contextMenuOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Play in External Player'**
  String get contextMenuOpenExternal;

  /// No description provided for @contextMenuPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get contextMenuPlay;

  /// No description provided for @contextMenuAddFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorite Categories'**
  String get contextMenuAddFavoriteCategory;

  /// No description provided for @contextMenuRemoveFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorite Categories'**
  String get contextMenuRemoveFavoriteCategory;

  /// No description provided for @contextMenuFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by this category'**
  String get contextMenuFilterCategory;

  /// No description provided for @confirmDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get confirmDeleteCancel;

  /// No description provided for @confirmDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get confirmDeleteAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'pt',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
