import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crispy_tivi/core/theme/crispy_radius.dart';
import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/features/media_servers/shared/data/models/media_server_user.dart';
import 'package:crispy_tivi/features/media_servers/shared/presentation/providers/public_users_provider.dart';

/// A circular avatar tile with the user name below, used on media-server
/// login screens to select a public user for login.
///
/// When [showPinBadge] is `true` and the user has a configured password,
/// a small lock icon badge is overlaid on the bottom-right of the avatar
/// (Emby behaviour). Jellyfin omits the badge.
class MediaServerUserAvatarTile extends StatelessWidget {
  const MediaServerUserAvatarTile({
    super.key,
    required this.user,
    required this.serverUrl,
    this.onTap,
    this.showPinBadge = false,
  });

  /// The user to display.
  final MediaServerUser user;

  /// Base URL of the media server, used to construct the avatar image URL.
  final String serverUrl;

  /// Called when the tile is tapped. If `null` the tile is non-interactive.
  final VoidCallback? onTap;

  /// When `true`, a lock-icon badge is shown when [user.hasConfiguredPassword]
  /// is set. Pass `true` for Emby, omit (defaults to `false`) for Jellyfin.
  final bool showPinBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final imageUrl =
        user.primaryImageTag != null
            ? '$serverUrl/Users/${user.id}/Images/Primary'
                '?tag=${user.primaryImageTag}&height=80'
            : null;

    final avatar = CircleAvatar(
      radius: 28,
      backgroundColor: cs.primaryContainer,
      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
      child:
          imageUrl == null
              ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );

    final avatarWithBadge =
        showPinBadge && user.hasConfiguredPassword
            ? Stack(
              alignment: Alignment.bottomRight,
              children: [
                avatar,
                Container(
                  padding: const EdgeInsets.all(CrispySpacing.xxs),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outline, width: 1),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 10,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            )
            : avatar;

    return Semantics(
      button: true,
      label: 'Select user',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                avatarWithBadge,
                const SizedBox(height: CrispySpacing.xs),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrollable row of [MediaServerUserAvatarTile]s.
///
/// Fetches public users from [mediaServerPublicUsersProvider] and renders
/// them as a labelled horizontal list. Returns [SizedBox.shrink] when there
/// are no public users.
///
/// Pass `showPinBadge: true` for Emby (lock badge on password-protected
/// accounts). Omit or pass `false` for Jellyfin.
class MediaServerUserPickerRow extends ConsumerWidget {
  const MediaServerUserPickerRow({
    super.key,
    required this.serverUrl,
    required this.onUserSelected,
    this.showPinBadge = false,
  });

  /// Base URL of the media server.
  final String serverUrl;

  /// Called with the selected [MediaServerUser] when a tile is tapped.
  final void Function(MediaServerUser user) onUserSelected;

  /// See [MediaServerUserAvatarTile.showPinBadge].
  final bool showPinBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(mediaServerPublicUsersProvider(serverUrl));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        return _UserListRow(
          users: users,
          serverUrl: serverUrl,
          onUserSelected: onUserSelected,
          showPinBadge: showPinBadge,
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: CrispySpacing.sm),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ── Internal: rendered row of tiles ────────────────────────────────────────

class _UserListRow extends StatelessWidget {
  const _UserListRow({
    required this.users,
    required this.serverUrl,
    required this.onUserSelected,
    required this.showPinBadge,
  });

  final List<MediaServerUser> users;
  final String serverUrl;
  final void Function(MediaServerUser user) onUserSelected;
  final bool showPinBadge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select user',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: CrispySpacing.sm),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              separatorBuilder:
                  (_, _) => const SizedBox(width: CrispySpacing.sm),
              itemBuilder: (context, index) {
                final user = users[index];
                return MediaServerUserAvatarTile(
                  user: user,
                  serverUrl: serverUrl,
                  onTap: () => onUserSelected(user),
                  showPinBadge: showPinBadge,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
