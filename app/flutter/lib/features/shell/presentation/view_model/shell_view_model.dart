import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/presentation/view_state/source_provider_registry.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/data/asset_source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/media/media_presentation_state.dart';
import 'package:crispy_tivi/features/shell/presentation/search/search_presentation_adapter.dart';
import 'package:crispy_tivi/features/shell/presentation/search/search_presentation_state.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_navigation_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_live_tv_selection_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_media_selection_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_selection_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_command_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_runtime_presentation_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_player_runtime_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_personalization_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_source_setup_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_source_workflow_coordinator.dart';
import 'package:flutter/foundation.dart';

export 'package:crispy_tivi/features/shell/presentation/view_state/source_provider_registry.dart';

part 'shell_view_model_projection.dart';

class ShellViewModel extends ChangeNotifier {
  ShellViewModel({
    required ShellContractSupport contract,
    SourceRegistrySnapshot? sourceRegistry,
    LiveTvRuntimeSnapshot? liveTvRuntime,
    MediaRuntimeSnapshot? mediaRuntime,
    SearchRuntimeSnapshot? searchRuntime,
    DiagnosticsRuntimeSnapshot? diagnosticsRuntime,
    PersonalizationRuntimeSnapshot? personalizationRuntime,
    SourceRegistryRepository sourceRegistryRepository =
        const AssetSourceRegistryRepository(),
    ShellRuntimeBridge? shellRuntimeBridge,
    ShellSourceSetupCoordinator? sourceSetupCoordinator,
    ShellPersonalizationCoordinator? personalizationCoordinator,
    PersonalizationRuntimeRepository personalizationRepository =
        const NoopPersonalizationRuntimeRepository(),
  }) : _contract = contract,
       _personalizationCoordinator =
           personalizationCoordinator ??
           ShellPersonalizationCoordinator(
             personalizationRepository: personalizationRepository,
           ),
       _liveTvCoordinator = ShellLiveTvSelectionCoordinator(
         liveTvPanel: contract.liveTvPanels.first,
         liveTvGroupId:
             (liveTvRuntime ?? const LiveTvRuntimeSnapshot.empty())
                 .selectedGroupId,
       ),
       _mediaCoordinator = ShellMediaSelectionCoordinator(
         mediaPanel: contract.mediaPanels.first,
         mediaScope: contract.mediaScopes.first,
       ),
       _runtimeCoordinator = ShellRuntimePresentationCoordinator(
         liveTvRuntime: liveTvRuntime ?? const LiveTvRuntimeSnapshot.empty(),
         mediaRuntime: mediaRuntime ?? const MediaRuntimeSnapshot.empty(),
         searchRuntime: searchRuntime ?? const SearchRuntimeSnapshot.empty(),
         diagnosticsRuntime:
             diagnosticsRuntime ?? const DiagnosticsRuntimeSnapshot.empty(),
         personalizationRuntime:
             personalizationRuntime ??
             const PersonalizationRuntimeSnapshot.empty(),
       ) {
    _navigationCoordinator = ShellNavigationCoordinator(
      contract: contract,
      sourceRegistry: sourceRegistry ?? const SourceRegistrySnapshot.empty(),
      personalizationRuntime: _runtimeCoordinator.personalizationRuntime,
      personalizationCoordinator: _personalizationCoordinator,
      isDisposed: () => _disposed,
      setPersonalizationRuntime: _runtimeCoordinator.setPersonalizationRuntime,
      notifyChanged: notifyListeners,
    );
    _sourceWorkflowCoordinator = ShellSourceWorkflowCoordinator(
      sourceRegistry: sourceRegistry ?? const SourceRegistrySnapshot.empty(),
      sourceRegistryRepository: sourceRegistryRepository,
      sourceSetupCoordinator: sourceSetupCoordinator,
      shellRuntimeBridge:
          shellRuntimeBridge ?? (!kIsWeb ? createShellRuntimeBridge() : null),
      isDisposed: () => _disposed,
      applyRuntimeBundle: (bundle) {
        _sourceWorkflowCoordinator.applySourceRegistrySnapshot(
          bundle.sourceRegistry,
        );
        _runtimeCoordinator.applyRuntimeBundle(bundle);
        _navigationCoordinator.setPersonalizationRuntime(
          bundle.personalizationRuntime,
        );
      },
      notifyChanged: notifyListeners,
    );
    _playerCoordinator = ShellPlayerRuntimeCoordinator(
      personalizationCoordinator: _personalizationCoordinator,
      getPersonalizationRuntime: () => _runtimeCoordinator.personalizationRuntime,
      setPersonalizationRuntime: _runtimeCoordinator.setPersonalizationRuntime,
      notifyChanged: notifyListeners,
    );
    _commandCoordinator = ShellCommandCoordinator(
      navigationCoordinator: _navigationCoordinator,
      sourceWorkflowCoordinator: _sourceWorkflowCoordinator,
      playerCoordinator: _playerCoordinator,
    );
    _selectionCoordinator = ShellSelectionCoordinator(
      liveTvCoordinator: _liveTvCoordinator,
      mediaCoordinator: _mediaCoordinator,
      notifyChanged: notifyListeners,
    );
  }

  final ShellContractSupport _contract;
  final ShellPersonalizationCoordinator _personalizationCoordinator;
  late final ShellNavigationCoordinator _navigationCoordinator;
  late final ShellSourceWorkflowCoordinator _sourceWorkflowCoordinator;
  final ShellLiveTvSelectionCoordinator _liveTvCoordinator;
  final ShellMediaSelectionCoordinator _mediaCoordinator;
  late final ShellSelectionCoordinator _selectionCoordinator;
  final ShellRuntimePresentationCoordinator _runtimeCoordinator;
  late final ShellPlayerRuntimeCoordinator _playerCoordinator;
  late final ShellCommandCoordinator _commandCoordinator;
  bool _disposed = false;

  static String sourcesLeafLabel(int index) =>
      ShellNavigationCoordinator.sourcesLeafLabel(index);

  ShellRoute get route => _navigationCoordinator.route;
  ShellContractSupport get contract => _contract;
  LiveTvRuntimeSnapshot get liveTvRuntime => _runtimeCoordinator.liveTvRuntime;
  MediaRuntimeSnapshot get mediaRuntime => _runtimeCoordinator.mediaRuntime;
  SearchRuntimeSnapshot get searchRuntime => _runtimeCoordinator.searchRuntime;
  DiagnosticsRuntimeSnapshot get diagnosticsRuntime =>
      _runtimeCoordinator.diagnosticsRuntime;
  PersonalizationRuntimeSnapshot get personalizationRuntime =>
      _runtimeCoordinator.personalizationRuntime;
  LiveTvPanel get liveTvPanel => _liveTvCoordinator.liveTvPanel;
  bool get liveTvChannelsActive => _liveTvCoordinator.liveTvChannelsActive;
  bool get liveTvGuideActive => _liveTvCoordinator.liveTvGuideActive;
  String get liveTvGroupId => _liveTvCoordinator.liveTvGroupId;
  int get liveTvFocusedChannelIndex =>
      _liveTvCoordinator.liveTvFocusedChannelIndex;
  int get liveTvPlayingChannelIndex =>
      _liveTvCoordinator.liveTvPlayingChannelIndex;
  MediaPanel get mediaPanel => _mediaCoordinator.mediaPanel;
  MediaScope get mediaScope => _mediaCoordinator.mediaScope;
  int get seriesSeasonIndex => _mediaCoordinator.seriesSeasonIndex;
  int get seriesEpisodeIndex => _mediaCoordinator.seriesEpisodeIndex;
  int? get seriesLaunchedEpisodeIndex =>
      _mediaCoordinator.seriesLaunchedEpisodeIndex;
  SettingsPanel get settingsPanel => _navigationCoordinator.settingsPanel;
  SourceProviderRegistry get sourceRegistry =>
      SourceProviderRegistry.fromSnapshot(
        _sourceWorkflowCoordinator.sourceRegistrySnapshot,
      );
  MediaPresentationState get mediaPresentation {
    if (_runtimeCoordinator.mediaRuntime.movieCollections.isEmpty &&
        _runtimeCoordinator.mediaRuntime.seriesCollections.isEmpty &&
        _runtimeCoordinator.mediaRuntime.seriesDetail.seasons.isEmpty) {
      return const MediaPresentationState.empty();
    }
    return MediaPresentationAdapter.build(
      runtime: _runtimeCoordinator.mediaRuntime,
      personalization: _runtimeCoordinator.personalizationRuntime,
      availableScopes: _contract.mediaScopes,
      panel: _mediaCoordinator.mediaPanel,
      scope: _mediaCoordinator.mediaScope,
      seriesSeasonIndex: _mediaCoordinator.seriesSeasonIndex,
      seriesEpisodeIndex: _mediaCoordinator.seriesEpisodeIndex,
      launchedSeriesEpisodeIndex:
          _mediaCoordinator.seriesLaunchedEpisodeIndex,
    );
  }

  SearchPresentationState get searchPresentation {
    if (_runtimeCoordinator.searchRuntime.groups.isEmpty) {
      return const SearchPresentationState.empty();
    }
    return SearchPresentationAdapter.build(runtime: _runtimeCoordinator.searchRuntime);
  }

  SourceProviderKind get selectedProviderType => sourceProviderKindFromRuntime(
    _sourceWorkflowCoordinator.sourceRegistrySnapshot.selectedProviderKind,
  );
  int get selectedSourceIndex => _sourceWorkflowCoordinator.selectedSourceIndex;
  bool get sourceWizardActive => _sourceWorkflowCoordinator.sourceWizardActive;
  SourceWizardStep get sourceWizardStep => _sourceWorkflowCoordinator.sourceWizardStep;
  Map<String, String> get sourceWizardFieldValues =>
      _sourceWorkflowCoordinator.sourceWizardFieldValues;
  String get settingsSearchQuery => _navigationCoordinator.settingsSearchQuery;
  String? get highlightedSettingsLeaf =>
      _navigationCoordinator.highlightedSettingsLeaf;
  PlayerSession? get playerSession => _playerCoordinator.playerSession;
  PlayerPlaybackController get playerPlaybackController =>
      _playerCoordinator.playerPlaybackController;
  PlayerChromeState get playerChromeState => _playerCoordinator.playerChromeState;
  PlayerChooserKind? get activePlayerChooser =>
      _playerCoordinator.activePlayerChooser;
  List<ShelfItem> get homeContinueWatchingItems {
    return buildContinueWatchingItems(_runtimeCoordinator.personalizationRuntime);
  }

  HeroFeature? get homeHeroFeature {
    return heroFeatureFromRuntime(_runtimeCoordinator.mediaRuntime);
  }

  List<ShelfItem> get homeLiveNowItems {
    return buildLiveNowItems(_runtimeCoordinator.liveTvRuntime);
  }

  List<SettingsItem> get generalSettingsItems {
    return buildGeneralSettingsItems(
      personalizationRuntime: _runtimeCoordinator.personalizationRuntime,
      sourceRegistry: sourceRegistry,
    );
  }

  List<SettingsItem> get playbackSettingsItems {
    return buildPlaybackSettingsItems(_runtimeCoordinator.personalizationRuntime);
  }

  List<SettingsItem> get appearanceSettingsItems {
    return buildAppearanceSettingsItems();
  }

  List<SettingsItem> get systemSettingsItems {
    return buildSystemSettingsItems(_runtimeCoordinator.diagnosticsRuntime);
  }

  void selectRoute(ShellRoute route) {
    _commandCoordinator.selectRoute(route);
  }

  void selectLiveTvPanel(LiveTvPanel panel) {
    _selectionCoordinator.selectLiveTvPanel(panel);
  }

  void selectLiveTvGroup(String groupId) {
    _selectionCoordinator.selectLiveTvGroup(groupId);
  }

  void selectLiveTvChannelIndex(int index) {
    _selectionCoordinator.selectLiveTvChannelIndex(index);
  }

  void activateLiveTvFocusedChannel() {
    _selectionCoordinator.activateLiveTvFocusedChannel();
  }

  void selectMediaPanel(MediaPanel panel) {
    _selectionCoordinator.selectMediaPanel(panel);
  }

  void selectMediaScope(MediaScope scope) {
    _selectionCoordinator.selectMediaScope(scope);
  }

  void selectSeriesSeasonIndex(int index) {
    _selectionCoordinator.selectSeriesSeasonIndex(index);
  }

  void selectSeriesEpisodeIndex(int index) {
    _selectionCoordinator.selectSeriesEpisodeIndex(index);
  }

  void launchSeriesEpisode() {
    _selectionCoordinator.launchSeriesEpisode();
  }

  void launchPlayer(PlayerSession session) {
    _commandCoordinator.launchPlayer(session);
  }

  void openPlayerInfo() {
    _commandCoordinator.openPlayerInfo();
  }

  void openPlayerChooser(PlayerChooserKind kind) {
    _commandCoordinator.openPlayerChooser(kind);
  }

  void closePlayerChooser() {
    _commandCoordinator.closePlayerChooser();
  }

  void unwindPlayer() {
    _commandCoordinator.unwindPlayer();
  }

  void selectPlayerQueueIndex(int index) {
    _commandCoordinator.selectPlayerQueueIndex(index);
  }

  void selectPlayerChooserOption(PlayerChooserKind kind, int optionIndex) {
    _commandCoordinator.selectPlayerChooserOption(kind, optionIndex);
  }

  void toggleMediaWatchlist(String contentKey) {
    _commandCoordinator.toggleMediaWatchlist(contentKey);
  }

  void selectSettingsPanel(SettingsPanel panel) {
    _commandCoordinator.selectSettingsPanel(panel);
  }

  void selectSourceIndex(int index) {
    _commandCoordinator.selectSourceIndex(index);
  }

  void startAddSourceWizard() {
    _commandCoordinator.startAddSourceWizard();
  }

  void startEditSourceWizard() {
    _commandCoordinator.startEditSourceWizard();
  }

  void startReconnectWizard() {
    _commandCoordinator.startReconnectWizard();
  }

  void startImportWizard() {
    _commandCoordinator.startImportWizard();
  }

  void updateSourceWizardField(String fieldLabel, String value) {
    _commandCoordinator.updateSourceWizardField(fieldLabel, value);
  }

  void selectSourceProviderType(SourceProviderKind kind) {
    _commandCoordinator.selectSourceProviderType(kind);
  }

  void selectSourceWizardStep(SourceWizardStep step) {
    _commandCoordinator.selectSourceWizardStep(step);
  }

  Future<void> advanceSourceWizard() async {
    await _commandCoordinator.advanceSourceWizard();
  }

  void retreatSourceWizard() {
    _commandCoordinator.retreatSourceWizard();
  }

  void updateSettingsSearchQuery(String value) {
    _commandCoordinator.updateSettingsSearchQuery(value);
  }

  void clearSettingsSearch() {
    _commandCoordinator.clearSettingsSearch();
  }

  void openSettingsLeaf({
    required SettingsPanel panel,
    required String leafLabel,
    int? sourceIndex,
  }) {
    _commandCoordinator.openSettingsLeaf(
      panel: panel,
      leafLabel: leafLabel,
      sourceIndex: sourceIndex,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _commandCoordinator.dispose();
    super.dispose();
  }

}
