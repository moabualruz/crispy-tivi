import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../config/subtitle_style.dart';
import '../core/theme/theme.dart';
import '../features/player/presentation/widgets/player_osd/osd_shared.dart';
import '../features/player/presentation/widgets/player_osd/subtitle_style_widgets.dart';
import 'catalog_surface.dart';

@widgetbook.UseCase(
  name: 'Icon button states',
  type: OsdIconButton,
  path: '[Player widgets]/OsdIconButton',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Player Widgets',
)
Widget osdIconButtonUseCase(BuildContext context) {
  return CatalogSurface(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: osdPanelColor,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OsdIconButton(
              icon: Icons.replay_10,
              tooltip: 'Back 10 seconds',
              onPressed: () {},
            ),
            OsdIconButton(
              icon: Icons.play_arrow,
              tooltip: 'Play',
              iconColor: Theme.of(context).colorScheme.primary,
              onPressed: () {},
            ),
            OsdIconButton(
              icon: Icons.forward_10,
              tooltip: 'Forward 10 seconds',
              onPressed: () {},
            ),
            const OsdIconButton(icon: Icons.subtitles, tooltip: 'Subtitles'),
          ],
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Subtitle controls',
  type: SubtitleFontSizeRow,
  path: '[Player widgets]/Subtitle controls',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Player Widgets',
)
Widget subtitleControlsUseCase(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return CatalogSurface(
    child: SizedBox(
      width: 620,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: osdPanelColor,
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CrispySpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SubtitleStyleSheetHeader(
                title: 'Subtitle Style',
                onClose: () {},
                textTheme: textTheme,
              ),
              const SizedBox(height: CrispySpacing.sm),
              SubtitleSectionLabel(label: 'Font size', textTheme: textTheme),
              const SizedBox(height: CrispySpacing.xs),
              SubtitleFontSizeRow(
                selected: SubtitleFontSize.medium,
                onChanged: (_) {},
              ),
              const SizedBox(height: CrispySpacing.md),
              SubtitleSectionLabel(label: 'Text color', textTheme: textTheme),
              const SizedBox(height: CrispySpacing.xs),
              SubtitleColorCircleRow(
                selected: SubtitleTextColor.white,
                onChanged: (_) {},
                colorScheme: colorScheme,
              ),
              const SizedBox(height: CrispySpacing.md),
              SubtitleSectionLabel(label: 'Background', textTheme: textTheme),
              const SizedBox(height: CrispySpacing.xs),
              SubtitleChipRow<SubtitleBackground>(
                values: SubtitleBackground.values,
                selected: SubtitleBackground.semiTransparent,
                labelOf: (value) => value.label,
                onChanged: (_) {},
                colorScheme: colorScheme,
              ),
              const SizedBox(height: CrispySpacing.md),
              SubtitleOsdSlider(
                value: 0.6,
                min: 0,
                max: 1,
                divisions: 10,
                onChanged: (_) {},
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Subtitle preview',
  type: SubtitlePreviewBox,
  path: '[Player widgets]/SubtitlePreviewBox',
  designLink: 'Penpot: CrispyTivi Design System / FEATURE - Player Widgets',
)
Widget subtitlePreviewUseCase(BuildContext context) {
  return const CatalogSurface(
    child: SizedBox(
      width: 560,
      child: SubtitlePreviewBox(
        style: SubtitleStyle(
          fontSize: SubtitleFontSize.large,
          textColor: SubtitleTextColor.yellow,
          background: SubtitleBackground.semiTransparent,
          outlineColor: SubtitleOutlineColor.black,
          outlineSize: 2.0,
          backgroundOpacity: 0.72,
          hasShadow: true,
        ),
      ),
    ),
  );
}
