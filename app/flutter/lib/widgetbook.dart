import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook/widgetbook.dart';

import 'core/theme/theme.dart';
import 'core/widgets/async_filled_button.dart';
import 'core/widgets/content_badge.dart';
import 'core/widgets/glass_surface.dart';
import 'core/widgets/live_badge.dart';
import 'core/widgets/meta_chip.dart';
import 'core/widgets/section_header.dart';

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
                  name: 'Color, spacing, radius',
                  builder: (_) => const _TokenGallery(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookCategory(
          name: 'Core widgets',
          children: [
            WidgetbookComponent(
              name: 'Buttons',
              useCases: [
                WidgetbookUseCase(
                  name: 'Async filled button',
                  builder:
                      (_) => const _CatalogSurface(
                        child: Wrap(
                          spacing: CrispySpacing.md,
                          runSpacing: CrispySpacing.md,
                          children: [
                            AsyncFilledButton(
                              isLoading: false,
                              label: 'Add Source',
                              onPressed: _noop,
                            ),
                            AsyncFilledButton(
                              isLoading: true,
                              label: 'Syncing',
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Badges',
              useCases: [
                WidgetbookUseCase(
                  name: 'Live and content status',
                  builder:
                      (_) => const _CatalogSurface(
                        child: Wrap(
                          spacing: CrispySpacing.md,
                          runSpacing: CrispySpacing.md,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LiveBadge(),
                            LiveBadge(label: 'REC'),
                            ContentStatusBadge(badge: ContentBadge.newEpisode),
                            ContentStatusBadge(badge: ContentBadge.newSeason),
                            ContentStatusBadge(badge: ContentBadge.recording),
                            ContentStatusBadge(
                              badge: ContentBadge.expiringSoon,
                            ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Chips',
              useCases: [
                WidgetbookUseCase(
                  name: 'Metadata chips',
                  builder:
                      (_) => const _CatalogSurface(
                        child: Wrap(
                          children: [
                            MetaChip(label: '2026'),
                            MetaChip(label: '4K'),
                            MetaChip(label: 'PG-13'),
                            MetaChip(label: 'Drama'),
                          ],
                        ),
                      ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Headers',
              useCases: [
                WidgetbookUseCase(
                  name: 'Section header',
                  builder:
                      (_) => const _CatalogSurface(
                        child: SectionHeader(
                          title: 'Sources',
                          icon: Icons.playlist_add,
                          colorTitle: true,
                        ),
                      ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Surfaces',
              useCases: [
                WidgetbookUseCase(
                  name: 'Glass surface',
                  builder:
                      (_) => const _CatalogSurface(
                        child: SizedBox(
                          width: 360,
                          child: GlassSurface(
                            child: Padding(
                              padding: EdgeInsets.all(CrispySpacing.md),
                              child: Text(
                                'Glass surfaces should stay sharp, dark, and '
                                'token-driven across TV and desktop layouts.',
                              ),
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CatalogSurface extends StatelessWidget {
  const _CatalogSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(32), child: child),
      ),
    );
  }
}

class _TokenGallery extends StatelessWidget {
  const _TokenGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.crispyColors;
    const swatches = [
      ('Immersive', CrispyColors.bgImmersive),
      ('Surface', CrispyColors.bgSurface),
      ('Raised', CrispyColors.bgSurfaceLight),
      ('Brand red', CrispyColors.brandRed),
      ('Success', CrispyColors.statusSuccess),
      ('Warning', CrispyColors.statusWarning),
      ('Error', CrispyColors.statusError),
      ('Live', Color(0xFFFF5252)),
    ];
    final dynamicSwatches = [
      ('Glass tint', colors.glassTint),
      ('Theme primary', theme.colorScheme.primary),
    ];

    return _CatalogSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CrispyTivi tokens', style: theme.textTheme.headlineSmall),
            const SizedBox(height: CrispySpacing.lg),
            Wrap(
              spacing: CrispySpacing.md,
              runSpacing: CrispySpacing.md,
              children: [
                for (final (label, color) in [...swatches, ...dynamicSwatches])
                  _ColorSwatch(label: label, color: color),
              ],
            ),
            const SizedBox(height: CrispySpacing.lg),
            const Wrap(
              spacing: CrispySpacing.md,
              runSpacing: CrispySpacing.md,
              children: [
                _TokenPill(label: 'xxs', value: '${CrispySpacing.xxs}px'),
                _TokenPill(label: 'xs', value: '${CrispySpacing.xs}px'),
                _TokenPill(label: 'sm', value: '${CrispySpacing.sm}px'),
                _TokenPill(label: 'md', value: '${CrispySpacing.md}px'),
                _TokenPill(label: 'lg', value: '${CrispySpacing.lg}px'),
                _TokenPill(label: 'xl', value: '${CrispySpacing.xl}px'),
                _TokenPill(label: 'radius', value: '${CrispyRadius.tv}px'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.zero,
            ),
          ),
          const SizedBox(height: CrispySpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(
            '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TokenPill extends StatelessWidget {
  const _TokenPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label  $value'));
  }
}

void _noop() {}
