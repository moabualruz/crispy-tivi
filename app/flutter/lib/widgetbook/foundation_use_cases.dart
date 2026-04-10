import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../core/theme/theme.dart';
import 'catalog_surface.dart';

@widgetbook.UseCase(
  name: 'Color tokens',
  type: CrispyColorTokenGallery,
  path: '[Foundations]/Tokens',
  designLink: 'Penpot: CrispyTivi Design System / FOUNDATION - Tokens',
)
Widget colorTokensUseCase(BuildContext context) {
  return const CrispyColorTokenGallery();
}

@widgetbook.UseCase(
  name: 'Spacing and radius',
  type: CrispySpacingRadiusGallery,
  path: '[Foundations]/Tokens',
  designLink: 'Penpot: CrispyTivi Design System / FOUNDATION - Tokens',
)
Widget spacingRadiusUseCase(BuildContext context) {
  return const CrispySpacingRadiusGallery();
}

class CrispyColorTokenGallery extends StatelessWidget {
  const CrispyColorTokenGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.crispyColors;
    final swatches = [
      const _ColorSpec('Immersive', CrispyColors.bgImmersive),
      const _ColorSpec('Surface', CrispyColors.bgSurface),
      const _ColorSpec('Raised', CrispyColors.bgSurfaceLight),
      const _ColorSpec('Brand red', CrispyColors.brandRed),
      const _ColorSpec('Success', CrispyColors.statusSuccess),
      const _ColorSpec('Warning', CrispyColors.statusWarning),
      const _ColorSpec('Error', CrispyColors.statusError),
      const _ColorSpec('Live', Color(0xFFFF5252)),
      _ColorSpec('Glass tint', colors.glassTint),
      _ColorSpec('Theme primary', theme.colorScheme.primary),
    ];

    return CatalogSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Wrap(
          spacing: CrispySpacing.md,
          runSpacing: CrispySpacing.md,
          children: [
            for (final swatch in swatches)
              _ColorSwatch(label: swatch.label, color: swatch.color),
          ],
        ),
      ),
    );
  }
}

class CrispySpacingRadiusGallery extends StatelessWidget {
  const CrispySpacingRadiusGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogSurface(
      child: Wrap(
        spacing: CrispySpacing.md,
        runSpacing: CrispySpacing.md,
        children: [
          _TokenPill(label: 'spacing.xxs', value: '${CrispySpacing.xxs}px'),
          _TokenPill(label: 'spacing.xs', value: '${CrispySpacing.xs}px'),
          _TokenPill(label: 'spacing.sm', value: '${CrispySpacing.sm}px'),
          _TokenPill(label: 'spacing.md', value: '${CrispySpacing.md}px'),
          _TokenPill(label: 'spacing.lg', value: '${CrispySpacing.lg}px'),
          _TokenPill(label: 'spacing.xl', value: '${CrispySpacing.xl}px'),
          _TokenPill(label: 'spacing.xxl', value: '${CrispySpacing.xxl}px'),
          _TokenPill(label: 'radius.none', value: '${CrispyRadius.none}px'),
          _TokenPill(label: 'radius.tvSm', value: '${CrispyRadius.tvSm}px'),
          _TokenPill(label: 'radius.tv', value: '${CrispyRadius.tv}px'),
          _TokenPill(
            label: 'radius.progressBar',
            value: '${CrispyRadius.progressBar}px',
          ),
        ],
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

class _ColorSpec {
  const _ColorSpec(this.label, this.color);

  final String label;
  final Color color;
}
