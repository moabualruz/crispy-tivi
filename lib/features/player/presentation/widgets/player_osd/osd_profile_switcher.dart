import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/crispy_animation.dart';
import '../../../../../core/widgets/async_value_ui.dart';
import '../../../../../core/theme/crispy_radius.dart';
import '../../../../../core/theme/crispy_spacing.dart';
import '../../../../../core/widgets/pin_input_dialog.dart';
import '../../../../profiles/data/profile_service.dart';
import '../../../../profiles/domain/entities/user_profile.dart';
import '../../../../profiles/presentation/profile_constants.dart';

/// Avatar button in the player OSD top bar that opens a profile
/// picker overlay.
///
/// Tap the avatar to show a bottom-sheet style picker listing all
/// profiles. Selecting a profile switches the active profile
/// context while the player stays open.
///
/// PIN-protected profiles open [PinInputDialog] for verification
/// before switching.
///
/// FE-PM-12 spec requirement.
class OsdProfileSwitcher extends ConsumerWidget {
  const OsdProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileServiceProvider);

    return profileAsync.whenShrink(
      data: (state) {
        final active = state.activeProfile;
        // Only show when multiple profiles exist.
        if (active == null || state.profiles.length <= 1) {
          return const SizedBox.shrink();
        }

        final color =
            kProfileAvatarColors[active.avatarIndex %
                kProfileAvatarColors.length];

        return Tooltip(
          message: 'Switch profile (${active.name})',
          child: InkWell(
            onTap: () => _showProfilePicker(context, ref, state),
            borderRadius: BorderRadius.circular(CrispyRadius.full),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: profileAvatarGradient(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                kProfileAvatarIcons[active.avatarIndex %
                    kProfileAvatarIcons.length],
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProfilePicker(
    BuildContext context,
    WidgetRef ref,
    ProfileState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfilePickerSheet(state: state, ref: ref),
    );
  }
}

/// Bottom-sheet profile picker shown from the player OSD.
///
/// Lists all available profiles as avatar tiles. Tapping one
/// switches the active profile (with PIN verification if needed).
/// The player stays open — only the profile context changes.
class _ProfilePickerSheet extends StatelessWidget {
  const _ProfilePickerSheet({required this.state, required this.ref});

  final ProfileState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CrispyRadius.tv),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: CrispySpacing.md),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(CrispyRadius.full),
                ),
              ),
            ),

            Text(
              "Switch Profile",
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: CrispySpacing.md),

            // Profile tiles
            Wrap(
              spacing: CrispySpacing.md,
              runSpacing: CrispySpacing.md,
              children:
                  state.profiles.map((profile) {
                    return _ProfilePickerTile(
                      profile: profile,
                      isActive: profile.id == state.activeProfileId,
                      onTap: () => _selectProfile(context, ref, profile),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    // Already on this profile — dismiss sheet.
    if (profile.id == state.activeProfileId) {
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    if (profile.hasPIN) {
      if (!context.mounted) return;
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
      await ref.read(profileServiceProvider.notifier).switchProfile(profile.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

/// Single profile avatar tile in the OSD profile picker sheet.
class _ProfilePickerTile extends StatelessWidget {
  const _ProfilePickerTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final UserProfile profile;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color =
        kProfileAvatarColors[profile.avatarIndex % kProfileAvatarColors.length];
    final icon =
        kProfileAvatarIcons[profile.avatarIndex % kProfileAvatarIcons.length];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1.0,
        duration: CrispyAnimation.fast,
        child: SizedBox(
          width: kProfileTileWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: kProfileAvatarSize,
                height: kProfileAvatarSize,
                decoration: BoxDecoration(
                  gradient: profileAvatarGradient(color),
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  border:
                      isActive ? Border.all(color: cs.primary, width: 3) : null,
                ),
                child: Icon(icon, size: 36, color: Colors.white),
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                profile.name,
                style: tt.bodySmall?.copyWith(
                  color: isActive ? cs.primary : cs.onSurface,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (profile.hasPIN)
                Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
