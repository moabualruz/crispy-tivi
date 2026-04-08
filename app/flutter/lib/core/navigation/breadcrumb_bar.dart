import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';

// ── FE-AS-13: Breadcrumb bar ──────────────────────────────────────────────────

/// Route depth threshold above which breadcrumbs are shown.
///
/// A depth of 1 means we are at a top-level route (e.g. `/settings`),
/// depth of 2+ means we are nested (e.g. `/settings/profiles`).
const int _kBreadcrumbMinDepth = 2;

/// Maximum number of breadcrumb segments to show.
///
/// When a path is very deep, only the last [_kMaxCrumbs] segments are
/// shown (the first segment is always the root).
const int _kMaxCrumbs = 4;

/// Returns localized display names for known route segments.
///
/// FE-AS-13: Converts raw path segments to human-readable labels.
Map<String, String> _segmentLabels(AppLocalizations l10n) => {
  'home': l10n.navHome,
  'tv': l10n.navLiveTv,
  'epg': l10n.navGuide,
  'vods': l10n.navMovies,
  'series': l10n.navSeries,
  'dvr': l10n.navDvr,
  'favorites': l10n.navFavorites,
  'search': l10n.navSearch,
  'settings': l10n.navSettings,
  'profiles': l10n.breadcrumbProfiles,
  'jellyfin': l10n.breadcrumbJellyfin,
  'emby': l10n.breadcrumbEmby,
  'plex': l10n.breadcrumbPlex,
  'cloud-browser': l10n.breadcrumbCloud,
  'multiview': l10n.breadcrumbMultiView,
  'detail': l10n.breadcrumbDetail,
};

/// A single breadcrumb segment.
@immutable
class _Crumb {
  const _Crumb({required this.label, required this.path});

  /// Human-readable label derived from the path segment.
  final String label;

  /// Full path this crumb navigates to when tapped.
  final String path;
}

/// Derives a list of [_Crumb] from a GoRouter location path.
///
/// E.g. `/settings/profiles` →
///   [_Crumb('Settings', '/settings'), _Crumb('Profiles', '/settings/profiles')]
List<_Crumb> _parseCrumbs(String location, Map<String, String> labels) {
  // Strip query string + fragment.
  final clean = location.split('?').first.split('#').first;
  final segments = clean
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  if (segments.isEmpty) return [];

  final crumbs = <_Crumb>[];
  final buffer = StringBuffer();
  for (final seg in segments) {
    buffer.write('/$seg');
    final path = buffer.toString();
    // Skip numeric / UUID-like segments — they are IDs, not labels.
    final isId = RegExp(
      r'^[0-9a-f\-]{4,}$',
      caseSensitive: false,
    ).hasMatch(seg);
    if (isId) continue;
    final label = labels[seg] ?? _capitalize(seg);
    crumbs.add(_Crumb(label: label, path: path));
  }

  // Trim to [_kMaxCrumbs] by keeping the first and last segments.
  if (crumbs.length > _kMaxCrumbs) {
    return [
      crumbs.first,
      const _Crumb(label: '…', path: ''),
      ...crumbs.sublist(crumbs.length - (_kMaxCrumbs - 2)),
    ];
  }
  return crumbs;
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Breadcrumb navigation bar shown in nested route contexts.
///
/// FE-AS-13: Appears when the current GoRouter path has depth ≥ 2
/// (i.e. the user is inside a sub-section such as "Settings > Profiles"
/// or "Jellyfin > Movies").
///
/// Each crumb is tappable and navigates back to its path via [context.go].
/// The current (last) crumb is non-tappable and displayed at full opacity.
///
/// Usage: embed in [AppShell]'s content column above the child widget.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final crumbs = _parseCrumbs(location, _segmentLabels(context.l10n));

    // Only render when depth >= threshold.
    if (crumbs.length < _kBreadcrumbMinDepth) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: CrispyAnimation.fast,
      curve: CrispyAnimation.enterCurve,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.md,
            vertical: CrispySpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: CrispySpacing.xs),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _buildCrumbWidgets(
                      context,
                      crumbs,
                      colorScheme,
                      textTheme,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCrumbWidgets(
    BuildContext context,
    List<_Crumb> crumbs,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < crumbs.length; i++) {
      final crumb = crumbs[i];
      final isLast = i == crumbs.length - 1;
      final isEllipsis = crumb.path.isEmpty;

      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.xs),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        );
      }

      if (isLast || isEllipsis) {
        // Current / ellipsis crumb — not tappable.
        widgets.add(
          Text(
            crumb.label,
            style: textTheme.labelSmall?.copyWith(
              color:
                  isLast
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      } else {
        // Parent crumb — tappable, navigates back.
        widgets.add(
          Semantics(
            button: true,
            label: context.l10n.breadcrumbNavigateToParent,
            child: InkWell(
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
              onTap: () => context.go(crumb.path),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.xs,
                  vertical: CrispySpacing.xxs,
                ),
                child: Text(
                  crumb.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}
