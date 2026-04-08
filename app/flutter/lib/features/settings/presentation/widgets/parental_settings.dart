import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/pin_input_dialog.dart';
import '../../../parental/domain/content_rating.dart';
import '../providers/external_service_providers.dart';
import '../../../profiles/domain/entities/user_profile.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Parental Controls settings section.
class ParentalSettingsSection extends ConsumerStatefulWidget {
  const ParentalSettingsSection({super.key});

  @override
  ConsumerState<ParentalSettingsSection> createState() =>
      _ParentalSettingsSectionState();
}

class _ParentalSettingsSectionState
    extends ConsumerState<ParentalSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final parentalAsync = ref.watch(parentalServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Parental Controls',
          icon: Icons.family_restroom,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        parentalAsync.when(
          loading:
              () => const SettingsCard(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock),
                    title: Text('Loading...'),
                  ),
                ],
              ),
          error:
              (e, _) => SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.error),
                    title: const Text('Error loading parental settings'),
                    subtitle: Text('$e'),
                  ),
                ],
              ),
          data:
              (parentalState) => SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Master PIN'),
                    subtitle: Text(
                      parentalState.hasMasterPin ? 'PIN is set' : 'No PIN set',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap:
                        () => _showMasterPinDialog(
                          context,
                          parentalState.hasMasterPin,
                        ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.child_care),
                    title: const Text('Profile Restrictions'),
                    subtitle: const Text('Set rating limits per profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showProfileRestrictionsDialog(context),
                  ),
                ],
              ),
        ),
      ],
    );
  }

  Future<void> _showMasterPinDialog(
    BuildContext context,
    bool hasMasterPin,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final parentalService = ref.read(parentalServiceProvider.notifier);

    if (!hasMasterPin) {
      final result = await PinInputDialog.show(
        context,
        title: 'Set Master PIN',
        subtitle:
            'This PIN protects parental control '
            'settings.',
        confirmMode: true,
        onSubmit: (pin) async {
          await parentalService.setMasterPin(pin);
        },
      );

      if (result && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Master PIN set successfully')),
        );
      }
    } else {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Master PIN'),
              content: const Text('What would you like to do?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _changeMasterPin(context);
                  },
                  child: const Text('Change PIN'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _clearMasterPin(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Remove PIN'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _changeMasterPin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final parentalService = ref.read(parentalServiceProvider.notifier);

    final verified = await PinInputDialog.show(
      context,
      title: 'Enter Current PIN',
      subtitle: 'Verify your current PIN to continue.',
      onVerify: (pin) => parentalService.verifyMasterPin(pin),
    );

    if (!verified || !mounted) return;

    final result = await PinInputDialog.show(
      // ignore: use_build_context_synchronously
      context,
      title: 'Set New PIN',
      confirmMode: true,
      onSubmit: (pin) async {
        await parentalService.setMasterPin(pin);
      },
    );

    if (result && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Master PIN changed successfully')),
      );
    }
  }

  Future<void> _clearMasterPin(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final parentalService = ref.read(parentalServiceProvider.notifier);

    final verified = await PinInputDialog.show(
      context,
      title: 'Enter Current PIN',
      subtitle: 'Verify your PIN to remove it.',
      onVerify: (pin) => parentalService.clearMasterPin(pin),
    );

    if (verified && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Master PIN removed')),
      );
    }
  }

  Future<void> _showProfileRestrictionsDialog(BuildContext context) async {
    final profilesAsync = ref.read(profileServiceProvider);
    final profiles = profilesAsync.value?.profiles ?? [];

    if (profiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No profiles found')));
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => _ProfileRestrictionsDialog(profiles: profiles),
    );
  }
}

/// Dialog for managing profile content
/// restrictions.
class _ProfileRestrictionsDialog extends ConsumerStatefulWidget {
  const _ProfileRestrictionsDialog({required this.profiles});

  final List<UserProfile> profiles;

  @override
  ConsumerState<_ProfileRestrictionsDialog> createState() =>
      _ProfileRestrictionsDialogState();
}

class _ProfileRestrictionsDialogState
    extends ConsumerState<_ProfileRestrictionsDialog> {
  late Map<String, int> _ratings;
  late Map<String, bool> _isChild;

  @override
  void initState() {
    super.initState();
    _ratings = {for (final p in widget.profiles) p.id: p.maxAllowedRating};
    _isChild = {for (final p in widget.profiles) p.id: p.isChild};
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Profile Restrictions'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.profiles.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (ctx, i) {
            final profile = widget.profiles[i];
            final currentRating = _ratings[profile.id] ?? 4;
            final isChild = _isChild[profile.id] ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile name
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: CrispySpacing.xs),

                // Child profile toggle
                Row(
                  children: [
                    const Icon(Icons.child_care, size: 18),
                    const SizedBox(width: CrispySpacing.xs),
                    const Expanded(child: Text('Child Profile')),
                    Semantics(
                      label: 'Child profile',
                      toggled: isChild,
                      child: Switch(
                        value: isChild,
                        onChanged: (val) {
                          setState(() => _isChild[profile.id] = val);
                        },
                      ),
                    ),
                  ],
                ),

                // Rating limit dropdown
                Row(
                  children: [
                    const Icon(Icons.movie_filter, size: 18),
                    const SizedBox(width: CrispySpacing.xs),
                    const Expanded(child: Text('Max Rating')),
                    DropdownButton<int>(
                      value: currentRating,
                      underline: const SizedBox.shrink(),
                      items:
                          ContentRatingLevel.values
                              .where((r) => r != ContentRatingLevel.unrated)
                              .map((rating) {
                                return DropdownMenuItem(
                                  value: rating.value,
                                  child: Text(rating.code),
                                );
                              })
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _ratings[profile.id] = val);
                        }
                      },
                    ),
                  ],
                ),

                // Show restriction indicator
                if (isChild || currentRating < 4)
                  Padding(
                    padding: const EdgeInsets.only(top: CrispySpacing.xs),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: CrispySpacing.xs),
                        Text(
                          'Restricted',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _saveRestrictions, child: const Text('Save')),
      ],
    );
  }

  Future<void> _saveRestrictions() async {
    final profileService = ref.read(profileServiceProvider.notifier);

    for (final profile in widget.profiles) {
      final newRating = _ratings[profile.id];
      final newIsChild = _isChild[profile.id];

      if (newRating != profile.maxAllowedRating ||
          newIsChild != profile.isChild) {
        await profileService.updateProfile(
          profile.id,
          isChild: newIsChild,
          maxAllowedRating: newRating,
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile restrictions saved')),
      );
    }
  }
}
