import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook/widgetbook.dart';

import 'core/theme/theme.dart';
import 'widgetbook/core_widget_use_cases.dart';
import 'widgetbook/feature_widget_use_cases.dart';
import 'widgetbook/foundation_use_cases.dart';
import 'widgetbook/player_widget_use_cases.dart';

void main() {
  AppTheme.useGoogleFonts = false;
  runApp(const ProviderScope(child: CrispyWidgetbook()));
}

class CrispyWidgetbook extends StatelessWidget {
  const CrispyWidgetbook({super.key});

  static final _theme = AppTheme.fromSeedHex('#E50914').theme;

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      darkTheme: _theme,
      themeMode: ThemeMode.dark,
      directories: [
        WidgetbookCategory(
          name: 'Foundations',
          children: [
            WidgetbookComponent(
              name: 'Tokens',
              useCases: [
                WidgetbookUseCase(
                  name: 'Color tokens',
                  builder: colorTokensUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Spacing and radius',
                  builder: spacingRadiusUseCase,
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Core widgets',
          children: [
            WidgetbookComponent(
              name: 'AsyncFilledButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default and loading',
                  builder: asyncFilledButtonUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'CrispyLogo',
              useCases: [
                WidgetbookUseCase(
                  name: 'Brand sizes',
                  builder: crispyLogoUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'LiveBadge',
              useCases: [
                WidgetbookUseCase(
                  name: 'Live and recording',
                  builder: liveBadgeUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ContentStatusBadge',
              useCases: [
                WidgetbookUseCase(
                  name: 'Content status variants',
                  builder: contentStatusBadgeUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'MetaChip',
              useCases: [
                WidgetbookUseCase(
                  name: 'Metadata variants',
                  builder: metaChipUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'GenrePillRow',
              useCases: [
                WidgetbookUseCase(
                  name: 'Selected category',
                  builder: genrePillRowUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SectionHeader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Icon header',
                  builder: sectionHeaderUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'GlassSurface',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default surface',
                  builder: glassSurfaceUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'GlassmorphicSheet',
              useCases: [
                WidgetbookUseCase(
                  name: 'Bottom sheet shell',
                  builder: glassmorphicSheetUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'State widgets',
              useCases: [
                WidgetbookUseCase(
                  name: 'Empty state',
                  builder: emptyStateUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Loading state',
                  builder: loadingStateUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Error state',
                  builder: errorStateUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Error banner',
                  builder: errorBannerUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Error boundary',
                  builder: errorBoundaryUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SkeletonLoader',
              useCases: [
                WidgetbookUseCase(
                  name: 'Skeleton variants',
                  builder: skeletonLoaderUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'GeneratedPlaceholder',
              useCases: [
                WidgetbookUseCase(
                  name: 'Poster and landscape',
                  builder: generatedPlaceholderUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'WatchProgressBar',
              useCases: [
                WidgetbookUseCase(
                  name: 'Progress values',
                  builder: watchProgressBarUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'FavoriteStarOverlay',
              useCases: [
                WidgetbookUseCase(
                  name: 'Favorite states',
                  builder: favoriteStarOverlayUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SpoilerBlur',
              useCases: [
                WidgetbookUseCase(
                  name: 'Blurred and revealed',
                  builder: spoilerBlurUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'VignetteGradient',
              useCases: [
                WidgetbookUseCase(
                  name: 'Dark and adaptive',
                  builder: vignetteGradientUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'OrDividerRow',
              useCases: [
                WidgetbookUseCase(
                  name: 'Divider label',
                  builder: orDividerRowUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'NavArrow',
              useCases: [
                WidgetbookUseCase(
                  name: 'Carousel arrows',
                  builder: navArrowUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Sparkline',
              useCases: [
                WidgetbookUseCase(
                  name: 'Threshold line',
                  builder: sparklineUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'TvMasterDetailLayout',
              useCases: [
                WidgetbookUseCase(
                  name: 'Detail overlay',
                  builder: tvMasterDetailLayoutUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'TvColorButtonLegend',
              useCases: [
                WidgetbookUseCase(
                  name: 'Four-button legend',
                  builder: tvColorButtonLegendUseCase,
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Feature widgets',
          children: [
            WidgetbookComponent(
              name: 'ChannelListItem',
              useCases: [
                WidgetbookUseCase(
                  name: 'Program row states',
                  builder: channelListItemUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ChannelGridItem',
              useCases: [
                WidgetbookUseCase(
                  name: 'Grid tile states',
                  builder: channelGridItemUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SettingsBadge',
              useCases: [
                WidgetbookUseCase(
                  name: 'Badges',
                  builder: settingsBadgeUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'SettingsCard',
              useCases: [
                WidgetbookUseCase(
                  name: 'Settings group',
                  builder: settingsCardUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'QualityBadge',
              useCases: [
                WidgetbookUseCase(
                  name: 'Quality labels',
                  builder: qualityBadgeUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'CircularAction',
              useCases: [
                WidgetbookUseCase(
                  name: 'Secondary actions',
                  builder: circularActionUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'EpisodeTile',
              useCases: [
                WidgetbookUseCase(
                  name: 'Episode row states',
                  builder: episodeTileUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'ExpandableSynopsis',
              useCases: [
                WidgetbookUseCase(
                  name: 'Synopsis collapsed',
                  builder: expandableSynopsisUseCase,
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Player widgets',
          children: [
            WidgetbookComponent(
              name: 'OsdIconButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Icon button states',
                  builder: osdIconButtonUseCase,
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Subtitle controls',
              useCases: [
                WidgetbookUseCase(
                  name: 'Controls',
                  builder: subtitleControlsUseCase,
                ),
                WidgetbookUseCase(
                  name: 'Preview',
                  builder: subtitlePreviewUseCase,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
