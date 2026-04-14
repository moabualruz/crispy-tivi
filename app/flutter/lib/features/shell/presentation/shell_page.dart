import 'package:crispy_tivi/features/shell/domain/shell_content.dart';
import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/data/personalization_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/source_registry_repository.dart';
import 'package:crispy_tivi/features/shell/domain/shell_contract.dart';
import 'package:crispy_tivi/features/shell/domain/live_tv_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/media_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/domain/search_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/source_registry_snapshot.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/home_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/live_tv_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/media_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/player_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/search_view.dart';
import 'package:crispy_tivi/features/shell/presentation/routes/settings_view.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_view_model.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/local_sidebar.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_top_bar.dart';
import 'package:flutter/material.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({
    required this.contract,
    required this.content,
    required this.sourceRegistryRepository,
    required this.personalizationRepository,
    this.sourceRegistry = const SourceRegistrySnapshot.empty(),
    this.liveTvRuntime = const LiveTvRuntimeSnapshot.empty(),
    this.mediaRuntime = const MediaRuntimeSnapshot.empty(),
    this.searchRuntime = const SearchRuntimeSnapshot.empty(),
    this.personalizationRuntime = const PersonalizationRuntimeSnapshot.empty(),
    this.diagnosticsRuntime = const DiagnosticsRuntimeSnapshot.empty(),
    super.key,
  });

  final ShellContractSupport contract;
  final ShellContentSnapshot content;
  final SourceRegistrySnapshot sourceRegistry;
  final LiveTvRuntimeSnapshot liveTvRuntime;
  final MediaRuntimeSnapshot mediaRuntime;
  final SearchRuntimeSnapshot searchRuntime;
  final PersonalizationRuntimeSnapshot personalizationRuntime;
  final DiagnosticsRuntimeSnapshot diagnosticsRuntime;
  final SourceRegistryRepository sourceRegistryRepository;
  final PersonalizationRuntimeRepository personalizationRepository;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  static const _StageBucketConfig _stageConfig = _StageBucketConfig(
    viewportWidth: CrispyShellRoles.shellViewportWidth,
    viewportHeight: CrispyShellRoles.shellViewportHeight,
    scale: 1,
    outerPadding: CrispyShellRoles.shellOuterPadding,
    topBarGap: CrispyShellRoles.shellTopBarGap,
    sidebarGap: CrispyShellRoles.shellSidebarGap,
    sidebarWidth: CrispyShellRoles.shellSidebarWidth,
  );
  late final ShellViewModel _viewModel = ShellViewModel(
    contract: widget.contract,
    sourceRegistry: widget.sourceRegistry,
    liveTvRuntime: widget.liveTvRuntime,
    mediaRuntime: widget.mediaRuntime,
    searchRuntime: widget.searchRuntime,
    diagnosticsRuntime: widget.diagnosticsRuntime,
    sourceRegistryRepository: widget.sourceRegistryRepository,
    personalizationRuntime: widget.personalizationRuntime,
    personalizationRepository: widget.personalizationRepository,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: CrispyShellRoles.backdropGradient,
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: CrispyShellRoles.ambientHighlight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -80,
                  left: -120,
                  child: IgnorePointer(
                    child: Container(
                      width: 420,
                      height: 420,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CrispyShellRoles.ambientPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -100,
                  bottom: -120,
                  child: IgnorePointer(
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: CrispyShellRoles.ambientSecondary,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final _StageBucketConfig config = _resolveStageConfig(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );

                      return Center(
                        child: ClipRect(
                          child: SizedBox(
                            width: config.viewportWidth * config.scale,
                            height: config.viewportHeight * config.scale,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: config.viewportWidth,
                                height: config.viewportHeight,
                                child: Padding(
                                  padding: EdgeInsets.all(config.outerPadding),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      ShellTopBar(
                                        navigationRoutes:
                                            _viewModel.contract.topLevelRoutes,
                                        activeRoute: _viewModel.route,
                                        onSelectRoute: _viewModel.selectRoute,
                                        onOpenSettings:
                                            () => _viewModel.selectRoute(
                                              ShellRoute.settings,
                                            ),
                                      ),
                                      SizedBox(height: config.topBarGap),
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            if (_hasSidebar(
                                              _viewModel.route,
                                            )) ...<Widget>[
                                              SizedBox(
                                                width: config.sidebarWidth,
                                                child: _buildSidebar(),
                                              ),
                                              SizedBox(
                                                width: config.sidebarGap,
                                              ),
                                            ],
                                            Expanded(
                                              child: _ShellStage(
                                                child: _buildContent(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_viewModel.playerSession case final PlayerSession session)
                  Positioned.fill(
                    child: PlayerView(
                      session: session,
                      playbackController: _viewModel.playerPlaybackController,
                      chromeState: _viewModel.playerChromeState,
                      activeChooser: _viewModel.activePlayerChooser,
                      onBack: _viewModel.unwindPlayer,
                      onOpenInfo: _viewModel.openPlayerInfo,
                      onOpenChooser: _viewModel.openPlayerChooser,
                      onSelectChooserOption:
                          _viewModel.selectPlayerChooserOption,
                      onSelectQueueIndex: _viewModel.selectPlayerQueueIndex,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  _StageBucketConfig _resolveStageConfig(double maxWidth, double maxHeight) {
    final double widthScale = maxWidth / _stageConfig.viewportWidth;
    final double heightScale = maxHeight / _stageConfig.viewportHeight;
    final double rawScale = widthScale < heightScale ? widthScale : heightScale;
    final double scale = (!rawScale.isFinite || rawScale <= 0) ? 1 : rawScale;
    return _StageBucketConfig(
      viewportWidth: _stageConfig.viewportWidth,
      viewportHeight: _stageConfig.viewportHeight,
      scale: scale,
      outerPadding: _stageConfig.outerPadding,
      topBarGap: _stageConfig.topBarGap,
      sidebarGap: _stageConfig.sidebarGap,
      sidebarWidth: _stageConfig.sidebarWidth,
    );
  }

  bool _hasSidebar(ShellRoute route) {
    return route == ShellRoute.liveTv ||
        route == ShellRoute.media ||
        route == ShellRoute.settings;
  }

  Widget _buildSidebar() {
    switch (_viewModel.route) {
      case ShellRoute.home:
      case ShellRoute.search:
        return const SizedBox.shrink();
      case ShellRoute.liveTv:
        return LocalSidebar(
          title: 'Live TV',
          items:
              _viewModel.contract.liveTvPanels
                  .map((LiveTvPanel panel) => panel.label)
                  .toList(),
          itemKeyPrefix: 'live-tv-sidebar',
          selectedIndex: _viewModel.liveTvPanel.index,
          onSelectIndex:
              (int index) => _viewModel.selectLiveTvPanel(
                _viewModel.contract.liveTvPanels[index],
              ),
        );
      case ShellRoute.media:
        return LocalSidebar(
          title: 'Media',
          items:
              _viewModel.contract.mediaPanels
                  .map((MediaPanel panel) => panel.label)
                  .toList(),
          itemKeyPrefix: 'media-sidebar',
          selectedIndex: _viewModel.mediaPanel.index,
          onSelectIndex:
              (int index) => _viewModel.selectMediaPanel(
                _viewModel.contract.mediaPanels[index],
              ),
        );
      case ShellRoute.settings:
        return LocalSidebar(
          title: 'Settings',
          items:
              _viewModel.contract.settingsPanels
                  .map((SettingsPanel panel) => panel.label)
                  .toList(),
          itemKeyPrefix: 'settings-sidebar',
          selectedIndex: _viewModel.settingsPanel.index,
          onSelectIndex:
              (int index) => _viewModel.selectSettingsPanel(
                _viewModel.contract.settingsPanels[index],
              ),
        );
    }
  }

  Widget _buildContent() {
    switch (_viewModel.route) {
      case ShellRoute.home:
        return HomeView(
          quickAccessOrder: _viewModel.contract.homeQuickAccess,
          hero: _viewModel.homeHeroFeature,
          liveNow: _viewModel.homeLiveNowItems,
          continueWatching: _viewModel.homeContinueWatchingItems,
          hasConfiguredProviders:
              _viewModel.sourceRegistry.configuredProviders.isNotEmpty,
        );
      case ShellRoute.liveTv:
        return LiveTvView(
          runtime: _viewModel.liveTvRuntime,
          panel: _viewModel.liveTvPanel,
          groupId: _viewModel.liveTvGroupId,
          focusedChannelIndex: _viewModel.liveTvFocusedChannelIndex,
          playingChannelIndex: _viewModel.liveTvPlayingChannelIndex,
          onSelectGroup: _viewModel.selectLiveTvGroup,
          onSelectChannel: _viewModel.selectLiveTvChannelIndex,
          onActivateChannel: _viewModel.activateLiveTvFocusedChannel,
          onLaunchPlayer: _viewModel.launchPlayer,
        );
      case ShellRoute.media:
        return MediaView(
          state: _viewModel.mediaPresentation,
          runtime: _viewModel.mediaRuntime,
          onSelectScope: _viewModel.selectMediaScope,
          onSelectSeriesSeasonIndex: _viewModel.selectSeriesSeasonIndex,
          onSelectSeriesEpisodeIndex: _viewModel.selectSeriesEpisodeIndex,
          onLaunchSeriesEpisode: _viewModel.launchSeriesEpisode,
          onLaunchPlayer: _viewModel.launchPlayer,
          onToggleWatchlist: _viewModel.toggleMediaWatchlist,
          watchlistContentKeys:
              _viewModel.personalizationRuntime.favoriteMediaKeys,
        );
      case ShellRoute.search:
        return SearchView(state: _viewModel.searchPresentation);
      case ShellRoute.settings:
        return SettingsView(
          panel: _viewModel.settingsPanel,
          generalSettings: _viewModel.generalSettingsItems,
          playbackSettings: _viewModel.playbackSettingsItems,
          appearanceSettings: _viewModel.appearanceSettingsItems,
          systemSettings: _viewModel.systemSettingsItems,
          diagnosticsRuntime: widget.diagnosticsRuntime,
          sourceRegistry: _viewModel.sourceRegistry,
          selectedSourceIndex: _viewModel.selectedSourceIndex,
          selectedProviderType: _viewModel.selectedProviderType,
          sourceWizardActive: _viewModel.sourceWizardActive,
          sourceWizardStep: _viewModel.sourceWizardStep,
          sourceWizardFieldValues: _viewModel.sourceWizardFieldValues,
          searchQuery: _viewModel.settingsSearchQuery,
          highlightedLeaf: _viewModel.highlightedSettingsLeaf,
          onUpdateSearchQuery: _viewModel.updateSettingsSearchQuery,
          onClearSearch: _viewModel.clearSettingsSearch,
          onOpenSettingsLeaf: _viewModel.openSettingsLeaf,
          onSelectSource: _viewModel.selectSourceIndex,
          onSelectProviderType: _viewModel.selectSourceProviderType,
          onStartAddSource: _viewModel.startAddSourceWizard,
          onStartEditSource: _viewModel.startEditSourceWizard,
          onStartReconnect: _viewModel.startReconnectWizard,
          onStartImportSource: _viewModel.startImportWizard,
          onSelectWizardStep: _viewModel.selectSourceWizardStep,
          onUpdateWizardField: _viewModel.updateSourceWizardField,
          onAdvanceWizard: _viewModel.advanceSourceWizard,
          onRetreatWizard: _viewModel.retreatSourceWizard,
        );
    }
  }
}

class _StageBucketConfig {
  const _StageBucketConfig({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.scale,
    required this.outerPadding,
    required this.topBarGap,
    required this.sidebarGap,
    required this.sidebarWidth,
  });

  final double viewportWidth;
  final double viewportHeight;
  final double scale;
  final double outerPadding;
  final double topBarGap;
  final double sidebarGap;
  final double sidebarWidth;
}

class _ShellStage extends StatelessWidget {
  const _ShellStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: CrispyShellRoles.shellStageDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.compact),
        child: child,
      ),
    );
  }
}
