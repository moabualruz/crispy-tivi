import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/core/theme/crispy_shell_roles.dart';
import 'package:crispy_tivi/features/shell/domain/shell_models.dart';
import 'package:crispy_tivi/features/shell/presentation/widgets/shell_artwork.dart';
import 'package:flutter/material.dart';

class FeatureHero extends StatelessWidget {
  const FeatureHero({required this.feature, super.key});

  final HeroFeature feature;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: CrispyShellRoles.heroSurfaceDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(CrispyOverhaulTokens.section),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    feature.kicker,
                    style: textTheme.bodyMedium?.copyWith(
                      color: CrispyOverhaulTokens.accentFocus,
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  Text(feature.title, style: textTheme.headlineLarge),
                  const SizedBox(height: CrispyOverhaulTokens.medium),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      feature.summary,
                      style: textTheme.bodyLarge?.copyWith(
                        color: CrispyOverhaulTokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: CrispyOverhaulTokens.large),
                  Wrap(
                    spacing: CrispyOverhaulTokens.small,
                    runSpacing: CrispyOverhaulTokens.small,
                    children: <Widget>[
                      _ActionPlate(
                        label: feature.primaryAction,
                        emphasis: true,
                      ),
                      _ActionPlate(
                        label: feature.secondaryAction,
                        emphasis: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: CrispyOverhaulTokens.section),
            Expanded(
              flex: 5,
              child: AspectRatio(
                aspectRatio: 1.8,
                child: DecoratedBox(
                  decoration: CrispyShellRoles.heroArtworkFrameDecoration(),
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ShellArtwork(
                          source: feature.artwork,
                          borderRadius: BorderRadius.circular(
                            CrispyOverhaulTokens.radiusSheet,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ArtworkTitleSafeOverlay(
                          decoration:
                              CrispyShellRoles.heroArtworkScrimDecoration(),
                        ),
                      ),
                      Positioned(
                        left: CrispyOverhaulTokens.medium,
                        top: CrispyOverhaulTokens.medium,
                        child: ArtworkMetadataChip(
                          child: Text(
                            feature.kicker,
                            style: textTheme.bodyMedium?.copyWith(
                              color: CrispyOverhaulTokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: CrispyOverhaulTokens.medium,
                        bottom: CrispyOverhaulTokens.medium,
                        right: CrispyOverhaulTokens.medium,
                        child: Text(
                          feature.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(
                            color: CrispyOverhaulTokens.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPlate extends StatelessWidget {
  const _ActionPlate({required this.label, required this.emphasis});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {},
      style: CrispyShellRoles.actionButtonStyle(emphasis: emphasis),
      child: Text(label),
    );
  }
}
