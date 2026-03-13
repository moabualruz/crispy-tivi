import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/testing/test_keys.dart';
import 'package:crispy_tivi/l10n/l10n_extension.dart';

import '../../../../core/widgets/async_value_ui.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/pin_input_dialog.dart';
import '../../data/profile_service.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/user_role.dart';
import '../profile_constants.dart';
import '../widgets/add_profile_dialog.dart';
import '../widgets/role_badge.dart';
import '../../../player/data/watch_history_service.dart';
import '../../../player/domain/entities/watch_history_entry.dart';
import '../../../player/presentation/providers/player_providers.dart';

/// Profile selection screen.
///
/// Shown on app launch or when switching profiles.
/// Single-profile auto-skip is handled by the GoRouter
/// redirect in [app_router.dart] — this screen is never
/// instantiated when only one profile exists.
///
/// FE-PS-07: Drag-to-reorder enabled via [ReorderableWrap]/row list.
/// FE-PS-09: TV D-pad focus expands the focused tile to reveal
///           the last-watched content name.
class ProfileSelectionScreen extends ConsumerWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(profileServiceProvider);

    return Scaffold(
      key: TestKeys.profileSelectionScreen,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: stateAsync.whenUi(
        onRetry: () => ref.invalidate(profileServiceProvider),
        data:
            (state) => FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.profilesWhoIsWatching,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: CrispySpacing.xl),

                    // FE-PS-07: Reorderable profile grid.
                    // Wrap ReorderableListView in a constrained box so it
                    // lays out horizontally at a capped width.
                    _ReorderableProfileGrid(
                      profiles: state.profiles,
                      onReorder:
                          (oldIndex, newIndex) => ref
                              .read(profileServiceProvider.notifier)
                              .reorderProfiles(oldIndex, newIndex),
                      onProfileTap:
                          (profile) => _onProfileTap(context, ref, profile),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _onProfileTap(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    if (profile.hasPIN) {
      // FE-PM-03: pass profileId so wrong-attempt lockout is per-profile.
      // FE-PS-05: pass showBiometric so fingerprint button appears when
      //           the user has enabled biometric auth for this profile.
      final verified = await PinInputDialog.show(
        context,
        title: 'Enter PIN for ${profile.name}',
        profileId: profile.id,
        showBiometric: true,
        onVerify:
            (pin) => ref
                .read(profileServiceProvider.notifier)
                .switchProfile(profile.id, pin: pin),
      );
      if (verified && context.mounted) {
        await _handlePostSelectionNavigation(context, ref, profile);
      }
    } else {
      final success = await ref
          .read(profileServiceProvider.notifier)
          .switchProfile(profile.id);

      if (success && context.mounted) {
        await _handlePostSelectionNavigation(context, ref, profile);
      }
    }
  }

  Future<void> _handlePostSelectionNavigation(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    // Check if we need to set up a playlist.
    // Non-blocking check: If settings are loading, assume we have sources (fail open).
    // Only redirect if we are sure there are no sources.
    final settingsState = ref.read(settingsNotifierProvider);
    final settings = settingsState.value;
    final hasSources = settings?.sources.isNotEmpty ?? true;

    if (!context.mounted) return;

    if (!hasSources) {
      context.go(AppRoutes.onboarding);
      return;
    }

    final defaultScreen = settings?.defaultScreen ?? 'home';
    final isAutoResume = settings?.autoResumeChannel == true;

    if (isAutoResume && defaultScreen == 'live_tv') {
      final notifier = ref.read(settingsNotifierProvider.notifier);
      final lastChannelId = await notifier.getLastChannelId();
      if (lastChannelId != null) {
        if (kDebugMode) {
          debugPrint('[Profile] Auto-resume active: entering fullscreen mode.');
        }
        ref
            .read(playerModeProvider.notifier)
            .enterFullscreen(hostRoute: AppRoutes.tv);
        ref.read(playerServiceProvider).forceStateEmit();
      }
    }

    if (!context.mounted) return;

    // Standard navigation
    final alwaysGoToLive = isAutoResume && defaultScreen == 'live_tv';
    if (GoRouter.of(context).canPop() && !alwaysGoToLive) {
      if (kDebugMode) {
        debugPrint('[Profile] Popping profile selection.');
      }
      context.pop(profile);
    } else {
      if (defaultScreen == 'live_tv') {
        context.go(AppRoutes.tv);
      } else {
        context.go(AppRoutes.home);
      }
    }
  }
}

// ── FE-PS-07: Reorderable profile grid ───────────────────────────────────────

/// Horizontal reorderable grid of profile tiles + "Add" button.
///
/// FE-PS-07: Uses [ReorderableListView] in horizontal scroll mode so
/// users can long-press-drag tiles to reorder them. The "Add" tile is
/// pinned at the end and excluded from reordering.
class _ReorderableProfileGrid extends StatelessWidget {
  const _ReorderableProfileGrid({
    required this.profiles,
    required this.onReorder,
    required this.onProfileTap,
  });

  final List<UserProfile> profiles;
  final ReorderCallback onReorder;
  final void Function(UserProfile) onProfileTap;

  @override
  Widget build(BuildContext context) {
    // Use a Wrap for the grid with an invisible ReorderableWrap delegate.
    // ReorderableListView only supports 1D lists — we use a scrollable row
    // with drag handles. For the compact grid we rely on the
    // standard Wrap + a long-press drag approach via ReorderableWrap.
    //
    // Implementation: wrap profiles in a horizontal ReorderableListView
    // capped at a reasonable width, then add the "Add" tile separately.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            // Fixed height avoids unbounded cross-axis for horizontal
            // ReorderableListView: avatar (80) + gap (8) + name (~20) +
            // role row (~16) + AnimatedSize expansion (~28) + padding.
            height: 170,
            child: ClipRect(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                physics: const ClampingScrollPhysics(),
                onReorder: onReorder,
                itemCount: profiles.length,
                proxyDecorator:
                    (child, index, animation) => Material(
                      color: Colors.transparent,
                      child: ScaleTransition(
                        scale: animation.drive(
                          Tween(begin: 1.0, end: 1.1).chain(
                            CurveTween(curve: CrispyAnimation.enterCurve),
                          ),
                        ),
                        child: child,
                      ),
                    ),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return Padding(
                    key: ValueKey(profile.id),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.sm,
                    ),
                    // FE-PS-07: wrap in ReorderableDragStartListener so the
                    // tile area acts as the drag handle.
                    child: ReorderableDragStartListener(
                      index: index,
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(index.toDouble()),
                        child: _ProfileTile(
                          profile: profile,
                          icon:
                              kProfileAvatarIcons[profile.avatarIndex %
                                  kProfileAvatarIcons.length],
                          color:
                              kProfileAvatarColors[profile.avatarIndex %
                                  kProfileAvatarColors.length],
                          autofocus: index == 0,
                          onTap: () => onProfileTap(profile),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),
          // "Add Profile" tile is always last and never reorderable.
          FocusTraversalOrder(
            order: NumericFocusOrder(profiles.length.toDouble()),
            child: Consumer(
              builder:
                  (context, ref, _) => _AddProfileTile(
                    onTap: () => AddProfileDialog.show(context, ref),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── FE-PS-09: Profile tile with TV focus expansion ────────────────────────────

/// Individual profile tile.
///
/// FE-PS-09: When focused on TV (D-pad), expands vertically via
/// [AnimatedSize] to show the last-watched content name sourced from
/// [watchHistoryServiceProvider].
class _ProfileTile extends ConsumerStatefulWidget {
  const _ProfileTile({
    required this.profile,
    required this.icon,
    required this.color,
    required this.onTap,
    this.autofocus = false,
  });

  final UserProfile profile;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  ConsumerState<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends ConsumerState<_ProfileTile> {
  // FE-PS-09: tracks whether this tile is focused (TV D-pad).
  bool _isFocused = false;

  // FE-PS-09: the last-watched entry for this profile (loaded lazily).
  WatchHistoryEntry? _lastWatched;
  bool _loadedHistory = false;

  @override
  void initState() {
    super.initState();
    // Defer to avoid setState during the first layout/semantics pass.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    if (_loadedHistory) return;
    _loadedHistory = true;
    try {
      final service = ref.read(watchHistoryServiceProvider);
      final all = await service.getAll();
      // Filter to entries belonging to this profile.
      final profileEntries = all
          .where((e) => e.profileId == widget.profile.id)
          .toList(growable: false);
      if (profileEntries.isNotEmpty && mounted) {
        setState(() => _lastWatched = profileEntries.first);
      }
    } catch (_) {
      // Non-critical — expansion simply shows nothing if history fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // PS-10: Semantics label for screen readers and TV accessibility.
    final semanticsLabel = [
      widget.profile.name,
      if (widget.profile.isActive) 'active',
      if (widget.profile.hasPIN) 'PIN protected',
      if (widget.profile.role != UserRole.viewer) widget.profile.role.label,
    ].join(', ');

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Focus(
        // FE-PS-09: track focus state for TV expansion.
        onFocusChange: (focused) {
          if (mounted) setState(() => _isFocused = focused);
        },
        child: FocusWrapper(
          onSelect: widget.onTap,
          autofocus: widget.autofocus,
          borderRadius: CrispyRadius.tv,
          scaleFactor: 1.15,
          child: SizedBox(
            width: kProfileTileWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RoleIndicator(
                  role: widget.profile.role,
                  child: Container(
                    key: widget.profile.isGuest ? TestKeys.guestAvatar : null,
                    width: kProfileAvatarSize,
                    height: kProfileAvatarSize,
                    decoration: BoxDecoration(
                      gradient: profileAvatarGradient(widget.color),
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      border:
                          widget.profile.isActive
                              ? Border.all(color: colorScheme.primary, width: 3)
                              : null,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 40,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: CrispySpacing.sm),
                Text(
                  widget.profile.name,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.profile.hasPIN)
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    if (widget.profile.hasPIN &&
                        widget.profile.role != UserRole.viewer)
                      const SizedBox(width: CrispySpacing.xs),
                    if (widget.profile.role != UserRole.viewer)
                      RoleBadge(role: widget.profile.role, compact: true),
                  ],
                ),

                // FE-PS-09: Animated expansion when focused on TV.
                AnimatedSize(
                  duration: CrispyAnimation.fast,
                  curve: CrispyAnimation.enterCurve,
                  child:
                      _isFocused && _lastWatched != null
                          ? Padding(
                            padding: const EdgeInsets.only(
                              top: CrispySpacing.xs,
                            ),
                            child: Container(
                              width: kProfileTileWidth,
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xs,
                                vertical: CrispySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(
                                  CrispyRadius.tv,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 12,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: CrispySpacing.xxs),
                                  Expanded(
                                    child: Text(
                                      _lastWatched!.name,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.85),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add profile" button tile.
class _AddProfileTile extends StatelessWidget {
  const _AddProfileTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FocusWrapper(
      key: TestKeys.addProfileButton,
      onSelect: onTap,
      borderRadius: CrispyRadius.tv,
      scaleFactor: 1.15,
      child: SizedBox(
        width: kProfileTileWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: kProfileAvatarSize,
              height: kProfileAvatarSize,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person_add_outlined,
                size: 36,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              context.l10n.profilesCreate,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
