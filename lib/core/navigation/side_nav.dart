import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/profiles/data/profile_service.dart';
import '../../features/profiles/domain/entities/user_profile.dart';
import '../../features/profiles/presentation/profile_constants.dart';
import '../theme/crispy_animation.dart';
import '../theme/crispy_radius.dart';
import '../theme/crispy_spacing.dart';
import '../widgets/focus_wrapper.dart';
import '../widgets/pin_input_dialog.dart';
import 'app_routes.dart';
import 'nav_badge_provider.dart';
import 'nav_destinations.dart';

// ── SideNav dimension constants ──────────────────────────────────────────────

/// Width of the rail when extended (hover / keyboard focus).
const double _kRailWidth = 250.0;

/// Width of the rail when collapsed (icon-only).
const double _kRailCollapsedWidth = 72.0;

/// Height of a single navigation item row.
const double _kNavItemHeight = 56.0;

/// TiviMate-style icon-only side navigation bar.
///
/// Width: [_kRailCollapsedWidth] px collapsed,
/// [_kRailWidth] px extended (hover/focus).
///
/// On TV (large breakpoint), pass [alwaysShowLabels] = true so
/// labels are permanently visible without requiring hover/focus.
class SideNav extends ConsumerWidget {
  const SideNav({
    required this.extended,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  final bool extended;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavItem> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final badges = ref.watch(navBadgeProvider);

    final railWidth = extended ? _kRailWidth : _kRailCollapsedWidth;

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      child: AnimatedContainer(
        duration: CrispyAnimation.fast,
        curve: CrispyAnimation.enterCurve,
        width: railWidth,
        padding: const EdgeInsets.symmetric(vertical: CrispySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── App logo / branding ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: CrispySpacing.md,
                horizontal: CrispySpacing.sm,
              ),
              child: Row(
                mainAxisAlignment:
                    extended
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stream_rounded,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                  if (extended) ...[
                    const SizedBox(width: CrispySpacing.sm),
                    Text(
                      'CrispyTivi',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CrispySpacing.md),

            // ── Destinations ─────────────────────────────────────────
            Expanded(
              child: Consumer(
                builder: (context, freshnessRef, _) {
                  // FE-AS-09: watch freshness state to re-render when
                  // a section is visited and its "NEW" badge clears.
                  final freshness = freshnessRef.watch(navFreshnessProvider);
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final dest = destinations[index];
                      final badge = switch (dest.route) {
                        AppRoutes.dvr => badges.dvr,
                        AppRoutes.favorites => badges.favorites,
                        _ => null,
                      };
                      // FE-AS-09: show "NEW" pill when route is in the
                      // freshness set and has never been visited.
                      final isNew =
                          kFreshnessBadgeRoutes.contains(dest.route) &&
                          freshness.lastVisited[dest.route] == null;
                      return _buildItem(
                        context,
                        theme,
                        colorScheme,
                        index,
                        extended,
                        badge: badge,
                        isNew: isNew,
                      );
                    },
                  );
                },
              ),
            ),

            // ── Profile indicator (FE-AS-02) ──────────────────────────
            _ProfileIndicatorRow(extended: extended),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    int index,
    bool extended, {
    NavBadge? badge,
    // FE-AS-09: whether to show the "NEW" freshness pill.
    bool isNew = false,
  }) {
    final dest = destinations[index];
    final isSelected = selectedIndex == index;

    final iconWidget = Icon(
      isSelected ? dest.selectedIcon : dest.icon,
      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      size: 24,
    );

    // Wrap icon in a Badge when badge data warrants it.
    final badgedIcon = _wrapWithBadge(iconWidget, badge, colorScheme);

    return FocusWrapper(
      key: ValueKey('nav_item_${dest.label.toLowerCase()}'),
      onSelect: () => onDestinationSelected(index),
      borderRadius: CrispyRadius.sm,
      scaleFactor: 1.05,
      padding: EdgeInsets.zero,
      semanticLabel: dest.label,
      child: Tooltip(
        message: extended ? '' : dest.label,
        waitDuration: CrispyAnimation.normal,
        child: Container(
          width: double.infinity,
          height: _kNavItemHeight,
          decoration:
              isSelected
                  ? BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
                  )
                  : null,
          padding: EdgeInsets.symmetric(
            horizontal: extended ? CrispySpacing.md : 0,
          ),
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              badgedIcon,
              if (extended) ...[
                const SizedBox(width: CrispySpacing.sm),
                Expanded(
                  child: Text(
                    dest.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // FE-AS-09: "NEW" freshness pill badge.
                if (isNew && !isSelected) _NewPill(colorScheme: colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Wraps [child] in a Material 3 [Badge] when [badge] is visible.
  ///
  /// - Count badge: shows numeric label (DVR active/scheduled count).
  /// - Dot badge: 6 dp unlabelled dot (Favorites new-item indicator).
  /// - No badge: returns [child] unchanged.
  Widget _wrapWithBadge(
    Widget child,
    NavBadge? badge,
    ColorScheme colorScheme,
  ) {
    if (badge == null || !badge.isVisible) return child;

    if (badge.count > 0) {
      return Badge(
        label: Text('${badge.count}'),
        backgroundColor: colorScheme.error,
        textColor: colorScheme.onError,
        child: child,
      );
    }

    // Dot badge (showDot == true, count == 0).
    return Badge(
      smallSize: 6,
      backgroundColor: colorScheme.error,
      child: child,
    );
  }
}

// ── Profile indicator row (FE-AS-02 / FE-AS-04) ───────────────────────────────

/// Compact profile row shown at the bottom of the side navigation rail.
///
/// Displays the active profile's avatar and name (when labels are visible).
/// Tapping opens [ProfileSwitcherSheet].
class _ProfileIndicatorRow extends ConsumerWidget {
  const _ProfileIndicatorRow({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileServiceProvider);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, stack) => const SizedBox.shrink(),
      data: (state) {
        final profile = state.activeProfile;
        if (profile == null) return const SizedBox.shrink();
        final avatarIcon =
            kProfileAvatarIcons[profile.avatarIndex %
                kProfileAvatarIcons.length];
        final avatarColor =
            kProfileAvatarColors[profile.avatarIndex %
                kProfileAvatarColors.length];
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        final hasMultipleProfiles = state.profiles.length > 1;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CrispySpacing.xs,
            vertical: CrispySpacing.xs,
          ),
          child: FocusWrapper(
            key: const ValueKey('nav_profile_switcher_btn'),
            onSelect:
                () =>
                    hasMultipleProfiles
                        ? ProfileSwitcherSheet.show(context)
                        : context.push(
                          AppRoutes.profiles,
                          extra: const {'explicit': true},
                        ),
            borderRadius: CrispyRadius.sm,
            semanticLabel:
                hasMultipleProfiles
                    ? 'Switch profile: ${profile.name}'
                    : 'Manage profiles',
            child: Tooltip(
              message:
                  extended
                      ? ''
                      : hasMultipleProfiles
                      ? 'Switch profile'
                      : 'Manage profiles',
              waitDuration: CrispyAnimation.normal,
              child: Container(
                height: _kNavItemHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? CrispySpacing.md : 0,
                ),
                child: Row(
                  mainAxisAlignment:
                      extended
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                  children: [
                    // Avatar circle
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: profileAvatarGradient(avatarColor),
                        borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      ),
                      child: Icon(
                        avatarIcon,
                        size: 18,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    if (extended) ...[
                      const SizedBox(width: CrispySpacing.sm),
                      Expanded(
                        child: Text(
                          profile.name,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.unfold_more,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Profile switcher sheet (FE-AS-04) ─────────────────────────────────────────

/// Modal bottom sheet that lists all profiles and allows switching.
///
/// Handles PIN-protected profiles via [PinInputDialog]. Accessible
/// from the side nav (all breakpoints) and from the compact AppBar
/// avatar (mobile / compact breakpoint).
class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  /// Shows the profile switcher as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ProfileSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: CrispyRadius.top(CrispyRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: CrispySpacing.sm),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                ),
              ),
              // ── Title ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.md,
                  vertical: CrispySpacing.md,
                ),
                child: Row(
                  children: [
                    Text(
                      "Switch Profile",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      color: colorScheme.onSurfaceVariant,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // ── Profile list ─────────────────────────────────────────
              Flexible(
                child: profileAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (err, _) => Center(
                        child: Text(
                          'Error: $err',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                  data:
                      (state) => ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          vertical: CrispySpacing.sm,
                        ),
                        itemCount: state.profiles.length,
                        itemBuilder: (context, index) {
                          final profile = state.profiles[index];
                          final isActive = profile.id == state.activeProfileId;
                          return _ProfileSwitcherTile(
                            profile: profile,
                            isActive: isActive,
                            onTap: () => _onProfileTap(context, ref, profile),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onProfileTap(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    if (profile.hasPIN) {
      // FE-PM-03: pass profileId so wrong-attempt lockout is per-profile.
      final verified = await PinInputDialog.show(
        context,
        title: 'Enter PIN for ${profile.name}',
        profileId: profile.id,
        onVerify:
            (pin) => ref
                .read(profileServiceProvider.notifier)
                .switchProfile(profile.id, pin: pin),
      );
      if (verified && context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      final success = await ref
          .read(profileServiceProvider.notifier)
          .switchProfile(profile.id);
      if (success && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

/// A single profile tile inside [ProfileSwitcherSheet].
class _ProfileSwitcherTile extends StatelessWidget {
  const _ProfileSwitcherTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final avatarIcon =
        kProfileAvatarIcons[profile.avatarIndex % kProfileAvatarIcons.length];
    final avatarColor =
        kProfileAvatarColors[profile.avatarIndex % kProfileAvatarColors.length];

    return FocusWrapper(
      onSelect: onTap,
      borderRadius: CrispyRadius.sm,
      semanticLabel: [
        profile.name,
        if (isActive) 'active',
        if (profile.hasPIN) 'PIN protected',
      ].join(', '),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        decoration:
            isActive
                ? BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                )
                : null,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: profileAvatarGradient(avatarColor),
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                border:
                    isActive
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
              ),
              child: Icon(avatarIcon, size: 22, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: CrispySpacing.md),
            // Name
            Expanded(
              child: Text(
                profile.name,
                style: textTheme.bodyLarge?.copyWith(
                  color: isActive ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status indicators
            if (profile.hasPIN)
              Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.xs),
                child: Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (isActive)
              Icon(Icons.check_circle, size: 20, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

// ── FE-AS-09: "NEW" pill badge ────────────────────────────────────────────────

/// Small "NEW" pill shown next to a nav label when content has been
/// added to that section since the user last visited it.
///
/// FE-AS-09: Disappears once [navFreshnessProvider] records a visit
/// for the associated route.
class _NewPill extends StatelessWidget {
  const _NewPill({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.tertiary,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Text(
        'NEW',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: colorScheme.onTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
