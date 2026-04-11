import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_navigation.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/routes/home_view.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/routes/live_tv_view.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/routes/media_view.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/routes/search_view.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/routes/settings_view.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/view_model/mock_shell_view_model.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/local_sidebar.dart';
import 'package:crispy_tivi/features/mock_shell/presentation/widgets/shell_top_bar.dart';
import 'package:flutter/material.dart';

class MockShellPage extends StatefulWidget {
  const MockShellPage({super.key});

  @override
  State<MockShellPage> createState() => _MockShellPageState();
}

class _MockShellPageState extends State<MockShellPage> {
  static const _StageBucketConfig _stageConfig = _StageBucketConfig(
    viewportWidth: 1600,
    viewportHeight: 900,
    scale: 1,
    outerPadding: 20,
    topBarGap: 18,
    sidebarGap: 12,
    sidebarWidth: 288,
  );
  final MockShellViewModel _viewModel = MockShellViewModel();

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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF1B1D22),
                  CrispyOverhaulTokens.surfaceVoid,
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.topCenter,
                          radius: 1.1,
                          colors: <Color>[Color(0x1FFFFFFF), Color(0x00000000)],
                        ),
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
                        gradient: RadialGradient(
                          colors: <Color>[Color(0x168DA4C7), Color(0x008DA4C7)],
                        ),
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
                        gradient: RadialGradient(
                          colors: <Color>[Color(0x12DCE2EA), Color(0x00DCE2EA)],
                        ),
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
              LiveTvPanel.values
                  .map((LiveTvPanel panel) => panel.label)
                  .toList(),
          itemKeyPrefix: 'live-tv-sidebar',
          selectedIndex: _viewModel.liveTvPanel.index,
          onSelectIndex:
              (int index) =>
                  _viewModel.selectLiveTvPanel(LiveTvPanel.values[index]),
        );
      case ShellRoute.media:
        return LocalSidebar(
          title: 'Media',
          items:
              MediaPanel.values.map((MediaPanel panel) => panel.label).toList(),
          itemKeyPrefix: 'media-sidebar',
          selectedIndex: _viewModel.mediaPanel.index,
          onSelectIndex:
              (int index) =>
                  _viewModel.selectMediaPanel(MediaPanel.values[index]),
        );
      case ShellRoute.settings:
        return LocalSidebar(
          title: 'Settings',
          items:
              SettingsPanel.values
                  .map((SettingsPanel panel) => panel.label)
                  .toList(),
          itemKeyPrefix: 'settings-sidebar',
          selectedIndex: _viewModel.settingsPanel.index,
          onSelectIndex:
              (int index) =>
                  _viewModel.selectSettingsPanel(SettingsPanel.values[index]),
        );
    }
  }

  Widget _buildContent() {
    switch (_viewModel.route) {
      case ShellRoute.home:
        return const HomeView();
      case ShellRoute.liveTv:
        return LiveTvView(
          panel: _viewModel.liveTvPanel,
          group: _viewModel.liveTvGroup,
          onSelectGroup: _viewModel.selectLiveTvGroup,
        );
      case ShellRoute.media:
        return MediaView(
          panel: _viewModel.mediaPanel,
          scope: _viewModel.mediaScope,
          onSelectScope: _viewModel.selectMediaScope,
        );
      case ShellRoute.search:
        return const SearchView();
      case ShellRoute.settings:
        return SettingsView(panel: _viewModel.settingsPanel);
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
      decoration: BoxDecoration(
        color: CrispyOverhaulTokens.surfaceVoid,
        border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.compact),
        child: child,
      ),
    );
  }
}
