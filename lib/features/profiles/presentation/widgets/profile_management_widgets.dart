import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../parental/domain/content_rating.dart';
import '../../data/profile_service.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/dvr_permission.dart';
import '../../domain/enums/user_role.dart';
import '../profile_constants.dart';
import '../providers/biometric_provider.dart';
import '../screens/profile_watch_history_screen.dart';
import 'add_profile_dialog.dart'
    show MaturityRatingBadge, MaturityRatingDropdown;
import 'profile_language_prefs_sheet.dart';
import 'profile_viewing_stats_tile.dart';
import 'role_badge.dart';

// PM-06: avatar icon size constant
const double _kAvatarIconSize = 48.0;

/// Card tile used in [ProfileManagementScreen] to display and edit a profile.
class ProfileManagementTile extends ConsumerWidget {
  const ProfileManagementTile({
    required this.profile,
    required this.isCurrentUser,
    required this.icon,
    required this.color,
    required this.onRoleChanged,
    required this.onDvrPermissionChanged,
    required this.onManageSources,
    super.key,
  });

  final UserProfile profile;
  final bool isCurrentUser;
  final IconData icon;
  final Color color;
  final ValueChanged<UserRole> onRoleChanged;
  final ValueChanged<DvrPermission> onDvrPermissionChanged;
  final VoidCallback onManageSources;

  /// Navigates to the per-profile watch history screen.
  void _showWatchHistory(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => ProfileWatchHistoryScreen(
              profileId: profile.id,
              profileName: profile.name,
            ),
      ),
    );
  }

  /// FE-PM-11: Export this profile's settings as JSON.
  ///
  /// Builds a JSON blob with name, avatar, language prefs, accent color
  /// and a watch history summary, then shares via [SharePlus] or copies
  /// to clipboard as fallback. Shows a confirmation snackbar on success.
  Future<void> _exportProfile(BuildContext context) async {
    final exportMap = <String, dynamic>{
      // FE-PM-11: profile export schema v1.
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': {
        'id': profile.id,
        'name': profile.name,
        'avatarIndex': profile.avatarIndex,
        'isChild': profile.isChild,
        'isGuest': profile.isGuest,
        'role': profile.role.name,
        'dvrPermission': profile.dvrPermission.name,
        'accentColorValue': profile.accentColorValue,
        'preferredAudioLanguage': profile.preferredAudioLanguage,
        'preferredSubtitleLanguage': profile.preferredSubtitleLanguage,
        'subtitleEnabledByDefault': profile.subtitleEnabledByDefault,
      },
      // Summary only — full history lives in WatchHistoryService.
      'watchHistorySummary': {'note': 'Full history not included in export.'},
    };

    final jsonText = const JsonEncoder.withIndent('  ').convert(exportMap);

    bool shared = false;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: jsonText,
          subject: 'CrispyTivi Profile — ${profile.name}',
        ),
      );
      shared =
          result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (_) {
      // share_plus not available on this platform — fall back to clipboard.
    }

    if (!shared) {
      await Clipboard.setData(ClipboardData(text: jsonText));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shared
                ? 'Profile "${profile.name}" shared.'
                : 'Profile "${profile.name}" copied to clipboard.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: CrispySpacing.md),
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(CrispySpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Row(
              children: [
                // Avatar (PM-06: CrispyRadius.tv, PM-08: Semantics)
                Semantics(
                  label: '${profile.name} avatar',
                  child: Container(
                    width: _kAvatarIconSize,
                    height: _kAvatarIconSize,
                    decoration: BoxDecoration(
                      // FE-PM-10: guest profiles use a muted grey gradient.
                      gradient:
                          profile.isGuest
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colorScheme.surfaceContainerHighest,
                                  colorScheme.outlineVariant,
                                ],
                              )
                              : profileAvatarGradient(color),
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                // Name and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            profile.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: CrispySpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xs,
                                vertical: CrispySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'You',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                          // FE-PM-10: "Guest" label badge.
                          if (profile.isGuest) ...[
                            const SizedBox(width: CrispySpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xs,
                                vertical: CrispySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'Guest',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          // FE-PM-02: "KIDS" badge for kids profiles.
                          if (profile.isKids) ...[
                            const SizedBox(width: CrispySpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.xs,
                                vertical: CrispySpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'KIDS',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          // FE-PM-04: maturity rating badge.
                          if (!profile.isKids) ...[
                            const SizedBox(width: CrispySpacing.sm),
                            MaturityRatingBadge(
                              level: ContentRatingLevel.fromValue(
                                profile.maxAllowedRating,
                              ),
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: CrispySpacing.xs),
                      Row(
                        children: [
                          RoleBadge(role: profile.role),
                          const SizedBox(width: CrispySpacing.sm),
                          DvrPermissionBadge(permission: profile.dvrPermission),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.md),
            const Divider(height: 1),
            const SizedBox(height: CrispySpacing.md),

            // Controls
            Row(
              children: [
                // Role dropdown
                Expanded(
                  child: ProfileSettingDropdown<UserRole>(
                    label: 'Role',
                    value: profile.role,
                    items: UserRole.values,
                    itemLabel: (r) => r.label,
                    onChanged: isCurrentUser ? null : onRoleChanged,
                    disabledReason:
                        isCurrentUser ? "Can't change your own role" : null,
                  ),
                ),
                const SizedBox(width: CrispySpacing.md),
                // DVR permission dropdown
                Expanded(
                  child: ProfileSettingDropdown<DvrPermission>(
                    label: 'DVR Access',
                    value: profile.dvrPermission,
                    items: DvrPermission.values,
                    itemLabel: (p) => p.label,
                    onChanged: onDvrPermissionChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.md),

            // FE-PM-04: per-profile maturity rating cap.
            // Disabled for kids profiles (always capped at PG).
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Max Content Rating',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CrispySpacing.xs),
                if (profile.isKids)
                  Text(
                    'Kids profiles are always capped at PG',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  MaturityRatingDropdown(
                    value: ContentRatingLevel.fromValue(
                      profile.maxAllowedRating,
                    ),
                    onChanged: (level) {
                      // FE-PM-04: persist updated rating cap.
                      ref
                          .read(profileServiceProvider.notifier)
                          .updateProfile(
                            profile.id,
                            maxAllowedRating: level.value,
                          );
                    },
                  ),
              ],
            ),
            const SizedBox(height: CrispySpacing.md),

            // Manage sources button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onManageSources,
                icon: const Icon(Icons.playlist_add_check),
                label: Text(
                  profile.isAdmin
                      ? 'Full Source Access (Admin)'
                      : 'Manage Source Access',
                ),
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),

            // FE-PM-05: Watch history button.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showWatchHistory(context),
                icon: const Icon(Icons.history),
                label: const Text('Watch History'),
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),

            // FE-PM-07: Language & subtitle preferences button.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    () => ProfileLanguagePrefsSheet.show(
                      context,
                      ref,
                      profile: profile,
                    ),
                icon: const Icon(Icons.subtitles_outlined),
                label: Text(
                  profile.preferredAudioLanguage != null ||
                          profile.preferredSubtitleLanguage != null
                      ? 'Language Prefs (configured)'
                      : 'Language & Subtitle Prefs',
                ),
              ),
            ),
            const SizedBox(height: CrispySpacing.sm),

            // FE-PS-05: "Use Biometric" toggle — only shown for PIN profiles
            // on mobile platforms (iOS / Android) where local_auth is available.
            if (profile.hasPIN &&
                !kIsWeb &&
                (Platform.isIOS || Platform.isAndroid)) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Use Biometric to Unlock'),
                subtitle: const Text(
                  'Allow fingerprint or face unlock instead of PIN',
                ),
                value:
                    ref.watch(biometricPreferenceProvider).value?[profile.id] ??
                    false,
                onChanged:
                    (enabled) => ref
                        .read(biometricPreferenceProvider.notifier)
                        .set(profile.id, enabled: enabled),
              ),
              const SizedBox(height: CrispySpacing.sm),
            ],

            // FE-PM-11: Export profile as JSON.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _exportProfile(context),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Export Profile'),
              ),
            ),
            const SizedBox(height: CrispySpacing.md),
            const Divider(height: 1),
            const SizedBox(height: CrispySpacing.md),

            // FE-PM-08: per-profile accent color picker.
            Text(
              'Accent Color',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: CrispySpacing.xs),
            ProfileAccentColorPicker(
              selectedColor:
                  profile.accentColorValue != null
                      ? Color(profile.accentColorValue!)
                      : null,
              onSelected: (color) {
                ref
                    .read(profileServiceProvider.notifier)
                    .updateProfileAccentColor(profile.id, color?.toARGB32());
              },
            ),
            const SizedBox(height: CrispySpacing.md),
            const Divider(height: 1),
            const SizedBox(height: CrispySpacing.md),

            // FE-PM-09: Viewing stats tile.
            ProfileViewingStatsTile(profileId: profile.id),
          ],
        ),
      ),
    );
  }
}

/// Generic dropdown used inside [ProfileManagementTile] for role and DVR access.
class ProfileSettingDropdown<T> extends StatelessWidget {
  const ProfileSettingDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.disabledReason,
    super.key,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T>? onChanged;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = onChanged == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CrispySpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  isDisabled
                      ? colorScheme.outline.withValues(alpha: 0.3)
                      : colorScheme.outline,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDisabled ? colorScheme.outline : null,
            ),
            items:
                items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      style: TextStyle(
                        color: isDisabled ? colorScheme.outline : null,
                      ),
                    ),
                  );
                }).toList(),
            onChanged:
                isDisabled
                    ? null
                    : (newValue) {
                      if (newValue != null) onChanged!(newValue);
                    },
          ),
        ),
        if (disabledReason != null)
          Padding(
            padding: const EdgeInsets.only(top: CrispySpacing.xs),
            child: Text(
              disabledReason!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// Small badge showing DVR permission level.
class DvrPermissionBadge extends StatelessWidget {
  const DvrPermissionBadge({required this.permission, super.key});

  final DvrPermission permission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = _getStyle(permission, theme);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: CrispySpacing.xs),
          Text(
            'DVR: ${permission.label}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) _getStyle(DvrPermission perm, ThemeData theme) {
    switch (perm) {
      case DvrPermission.none:
        return (theme.colorScheme.error, Icons.block);
      case DvrPermission.viewOnly:
        return (theme.colorScheme.tertiary, Icons.visibility);
      case DvrPermission.full:
        return (theme.colorScheme.primary, Icons.videocam);
    }
  }
}
