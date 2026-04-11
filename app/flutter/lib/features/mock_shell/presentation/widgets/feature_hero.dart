import 'package:crispy_tivi/core/theme/crispy_overhaul_tokens.dart';
import 'package:crispy_tivi/features/mock_shell/domain/mock_shell_models.dart';
import 'package:flutter/material.dart';

class FeatureHero extends StatelessWidget {
  const FeatureHero({required this.feature, super.key});

  final HeroFeature feature;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CrispyOverhaulTokens.surfacePanel,
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusSheet),
        border: Border.all(color: CrispyOverhaulTokens.borderSubtle),
      ),
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
                  decoration: BoxDecoration(
                    color: CrispyOverhaulTokens.surfaceHighlight,
                    borderRadius: BorderRadius.circular(
                      CrispyOverhaulTokens.radiusSheet,
                    ),
                    border: Border.all(
                      color: CrispyOverhaulTokens.borderStrong,
                    ),
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (feature.backgroundAsset != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              CrispyOverhaulTokens.radiusSheet,
                            ),
                            child: Image.asset(
                              feature.backgroundAsset!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              CrispyOverhaulTokens.radiusSheet,
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                Color(0xD90E0E10),
                                Color(0x9918191D),
                                Color(0x4018191D),
                              ],
                            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            emphasis
                ? CrispyOverhaulTokens.surfaceRaised
                : CrispyOverhaulTokens.surfacePanel,
        border: Border.all(
          color:
              emphasis
                  ? CrispyOverhaulTokens.accentFocus
                  : CrispyOverhaulTokens.borderStrong,
        ),
        borderRadius: BorderRadius.circular(CrispyOverhaulTokens.radiusControl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispyOverhaulTokens.medium,
          vertical: CrispyOverhaulTokens.small,
        ),
        child: Text(label),
      ),
    );
  }
}
