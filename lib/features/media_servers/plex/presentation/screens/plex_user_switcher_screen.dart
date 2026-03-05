import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/testing/test_keys.dart';
import 'package:crispy_tivi/core/theme/crispy_animation.dart';
import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import '../providers/plex_providers.dart';

// PX-FE-02

/// [PX-FE-02] Plex household / managed-user profile switcher screen.
///
/// Shown after initial login or tapped from the Plex home screen action
/// menu. Displays an avatar grid of managed users; tapping a card switches
/// the active session token stored in [plexActiveUserProvider].
///
/// If the server does not have Plex Home enabled, or the `/accounts`
/// endpoint returns fewer than 2 accounts, this screen degrades to an
/// empty state with a message.
// PX-FE-02
class PlexUserSwitcherScreen extends ConsumerWidget {
  const PlexUserSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PX-FE-02
    final usersAsync = ref.watch(plexManagedUsersProvider);
    final activeUser = ref.watch(plexActiveUserProvider);

    return Scaffold(
      key: TestKeys.plexUserSwitcherScreen,
      appBar: AppBar(title: const Text('Switch Profile')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: CrispySpacing.sm),
                    Text(
                      'Failed to load profiles.\n$e',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        data: (users) {
          if (users.isEmpty) {
            // PX-FE-02: degrade gracefully when Plex Home is not enabled.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(CrispySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: CrispySpacing.md),
                    Text(
                      'No managed profiles found.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: CrispySpacing.xs),
                    Text(
                      'Plex Home must be enabled on your server '
                      'to use profile switching.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return _PlexUserGrid(users: users, activeUser: activeUser);
        },
      ),
    );
  }
}

// ── PX-FE-02: Avatar grid ─────────────────────────────────────────────

/// [PX-FE-02] Grid of avatar cards, one per managed user.
// PX-FE-02
class _PlexUserGrid extends ConsumerWidget {
  const _PlexUserGrid({required this.users, required this.activeUser});

  final List<PlexManagedUser> users;
  final PlexManagedUser? activeUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PX-FE-02
    return GridView.builder(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.8,
        crossAxisSpacing: CrispySpacing.lg,
        mainAxisSpacing: CrispySpacing.lg,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isActive = activeUser?.id == user.id;
        return _PlexUserCard(
          user: user,
          isActive: isActive,
          onTap: () {
            ref.read(plexActiveUserProvider.notifier).switchTo(user);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}

// ── PX-FE-02: Single user avatar card ────────────────────────────────

/// [PX-FE-02] A single managed-user card: circular avatar + display name.
///
/// The active user is highlighted with a primary-color ring and a
/// checkmark badge.
// PX-FE-02
class _PlexUserCard extends StatelessWidget {
  const _PlexUserCard({
    required this.user,
    required this.isActive,
    required this.onTap,
  });

  final PlexManagedUser user;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // PX-FE-02
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Select user',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: isActive ? 1.05 : 1.0,
          duration: CrispyAnimation.fast,
          curve: CrispyAnimation.focusCurve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // PX-FE-02: selection ring.
                  AnimatedContainer(
                    duration: CrispyAnimation.fast,
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? cs.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  // PX-FE-02: avatar.
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage:
                        user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                    child:
                        user.avatarUrl == null
                            ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: tt.headlineMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            )
                            : null,
                  ),
                  // PX-FE-02: active checkmark badge.
                  if (isActive)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(CrispySpacing.xxs),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Icon(Icons.check, size: 14, color: cs.onPrimary),
                      ),
                    ),
                  // PX-FE-02: protected/PIN indicator.
                  if (user.isProtected && !isActive)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(CrispySpacing.xxs),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CrispySpacing.sm),
              Text(
                user.name,
                style: tt.labelMedium?.copyWith(
                  color: isActive ? cs.primary : cs.onSurface,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              // PX-FE-02: "Active" label under the selected user.
              if (isActive) ...[
                const SizedBox(height: CrispySpacing.xxs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.xs,
                    vertical: CrispySpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                  child: Text(
                    'Active',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
