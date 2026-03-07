import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../parental/domain/content_rating.dart';
import '../../data/profile_service.dart';
import '../../domain/entities/user_profile.dart';
import '../profile_constants.dart';

/// Dialog for adding a new user profile.
///
/// Shows a name field and an avatar picker grid with D-pad/TV focus support.
///
/// Usage:
/// ```dart
/// AddProfileDialog.show(context, ref);
/// ```
class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({required this.ref, super.key});

  /// The [WidgetRef] from the calling screen — used to write to providers.
  final WidgetRef ref;

  /// Shows the add-profile dialog over [context].
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (_) => AddProfileDialog(ref: ref),
    );
  }

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  final _nameController = TextEditingController();
  int _selectedAvatar = 0;

  /// Per-profile accent color override; null means "use global theme".
  Color? _selectedAccentColor;

  // FE-PM-04: Per-profile maturity rating cap.
  // Default: NC-17 (value 4) — unrestricted.
  ContentRatingLevel _selectedRating = ContentRatingLevel.nc17;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.ref
        .read(profileServiceProvider.notifier)
        .addProfile(
          name: name,
          avatarIndex: _selectedAvatar,
          // FE-PM-08: pass the selected accent color as ARGB int.
          accentColorValue: _selectedAccentColor?.toARGB32(),
          // FE-PM-04: pass selected maturity rating cap.
          maxAllowedRating: _selectedRating.value,
        );
    Navigator.pop(context);
  }

  /// FE-PM-10: Create a guest profile and close the dialog.
  void _submitGuest() {
    widget.ref.read(profileServiceProvider.notifier).addGuestProfile();
    Navigator.pop(context);
  }

  /// FE-PM-02: Create a kids profile with PG content cap and kids type.
  void _submitKids() {
    final name = _nameController.text.trim();
    // Kids profile name defaults to "Kids" when field is empty.
    final effectiveName = name.isEmpty ? 'Kids' : name;
    widget.ref
        .read(profileServiceProvider.notifier)
        .addProfile(
          name: effectiveName,
          avatarIndex: _selectedAvatar,
          isChild: true,
          // PG = index 1
          maxAllowedRating: 1,
          profileType: ProfileType.kids,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Add Profile'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Profile Name'),
              ),
              const SizedBox(height: CrispySpacing.md),
              const Text('Choose Avatar'),
              const SizedBox(height: CrispySpacing.sm),
              _AvatarPickerGrid(
                selectedIndex: _selectedAvatar,
                onSelected: (i) => setState(() => _selectedAvatar = i),
              ),
              const SizedBox(height: CrispySpacing.md),
              // FE-PM-04: per-profile maturity rating cap.
              const Text('Maturity Rating'),
              const SizedBox(height: CrispySpacing.xs),
              MaturityRatingDropdown(
                value: _selectedRating,
                onChanged: (rating) => setState(() => _selectedRating = rating),
              ),
              const SizedBox(height: CrispySpacing.md),
              // FE-PM-08: per-profile accent color picker.
              const Text('Accent Color'),
              const SizedBox(height: CrispySpacing.sm),
              ProfileAccentColorPicker(
                selectedColor: _selectedAccentColor,
                onSelected:
                    (color) => setState(() => _selectedAccentColor = color),
              ),
              const SizedBox(height: CrispySpacing.md),
              const Divider(height: 1),
              const SizedBox(height: CrispySpacing.md),
              // FE-PM-02: Kids profile shortcut.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitKids,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.tertiary,
                    side: BorderSide(
                      color: colorScheme.tertiary.withValues(alpha: 0.6),
                    ),
                  ),
                  icon: const Icon(Icons.child_care),
                  label: const Text('Create Kids Profile'),
                ),
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                'Kids profiles cap content at PG and require an admin PIN to exit.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: CrispySpacing.sm),
              // FE-PM-10: guest profile shortcut.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitGuest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Create Guest Profile'),
                ),
              ),
              const SizedBox(height: CrispySpacing.xs),
              Text(
                'Guest profiles have no PIN and do not save watch history.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// FE-PM-01: Paginated icon picker grid with category headers.
///
/// Organises [kProfileAvatarIcons] into named sections defined
/// by [kProfileAvatarCategories] and [kProfileAvatarCategoryCounts].
/// The grid is rendered inside a fixed-height scrollable area so
/// the parent [AlertDialog] does not grow unbounded.
class _AvatarPickerGrid extends StatelessWidget {
  const _AvatarPickerGrid({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Build a flat list of section-header + grid-row children.
    final children = <Widget>[];
    var iconIndex = 0;

    for (var catIdx = 0; catIdx < kProfileAvatarCategories.length; catIdx++) {
      final count = kProfileAvatarCategoryCounts[catIdx];
      final label = kProfileAvatarCategories[catIdx];
      final start = iconIndex;
      iconIndex += count;

      children.add(
        Padding(
          padding: const EdgeInsets.only(
            top: CrispySpacing.sm,
            bottom: CrispySpacing.xs,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
        ),
      );

      // Render icons for this category in a Wrap.
      // Wrap avoids the RenderShrinkWrappingViewport intrinsic
      // dimension issue that GridView.builder(shrinkWrap: true)
      // triggers inside AlertDialog.
      final categoryIcons = List.generate(count, (j) => start + j);
      children.add(
        Wrap(
          spacing: CrispySpacing.xs,
          runSpacing: CrispySpacing.xs,
          children:
              categoryIcons.map((i) {
                return SizedBox(
                  width: 36,
                  height: 36,
                  child: _AvatarItem(
                    index: i,
                    isSelected: selectedIndex == i,
                    onSelected: onSelected,
                  ),
                );
              }).toList(),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// A single avatar icon cell in the grid (FE-PM-01).
class _AvatarItem extends StatelessWidget {
  const _AvatarItem({
    required this.index,
    required this.isSelected,
    required this.onSelected,
  });

  final int index;
  final bool isSelected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final color = kProfileAvatarColors[index % kProfileAvatarColors.length];

    return FocusWrapper(
      onSelect: () => onSelected(index),
      borderRadius: CrispyRadius.sm,
      scaleFactor: 1.1,
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isSelected ? color : color.withValues(alpha: 0.3),
                isSelected
                    ? Color.lerp(color, Colors.black, 0.3)!
                    : color.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(CrispyRadius.sm),
            border:
                isSelected ? Border.all(color: Colors.white, width: 2) : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            kProfileAvatarIcons[index],
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// FE-PM-04 ─────────────────────────────────────────────────────────────────────

/// Dropdown for selecting a per-profile maturity rating cap.
///
/// FE-PM-04: Shows all [ContentRatingLevel] values except [nc17] which is
/// relabelled as "All / Unrestricted". Used in both [AddProfileDialog] and
/// the management tile to set [UserProfile.maxAllowedRating].
class MaturityRatingDropdown extends StatelessWidget {
  const MaturityRatingDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ContentRatingLevel value;
  final ValueChanged<ContentRatingLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Ratings shown to the user: G, PG, PG-13, R, Unrestricted (= NC-17).
    const options = [
      ContentRatingLevel.g,
      ContentRatingLevel.pg,
      ContentRatingLevel.pg13,
      ContentRatingLevel.r,
      ContentRatingLevel.nc17,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.zero,
      ),
      child: DropdownButton<ContentRatingLevel>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items:
            options.map((level) {
              return DropdownMenuItem<ContentRatingLevel>(
                value: level,
                child: Row(
                  children: [
                    MaturityRatingBadge(level: level, compact: true),
                    const SizedBox(width: CrispySpacing.sm),
                    Text(level.displayLabel),
                  ],
                ),
              );
            }).toList(),
        onChanged: (level) {
          if (level != null) onChanged(level);
        },
      ),
    );
  }
}

/// Small rating badge shown next to a profile name.
///
/// FE-PM-04: Colour-coded label: G=green, PG=blue, PG-13=orange,
/// R=red, NC-17/unrestricted=no badge.
class MaturityRatingBadge extends StatelessWidget {
  const MaturityRatingBadge({
    required this.level,
    this.compact = false,
    super.key,
  });

  final ContentRatingLevel level;

  /// When true, renders a tight chip suitable for inline use.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // NC-17 / unrestricted — no badge needed.
    if (level == ContentRatingLevel.nc17 ||
        level == ContentRatingLevel.unrated) {
      return const SizedBox.shrink();
    }

    final (bgColor, labelText) = _style(context, level);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? CrispySpacing.xs : CrispySpacing.sm,
        vertical: CrispySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: bgColor.withValues(alpha: 0.6)),
      ),
      child: Text(
        labelText,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: bgColor,
          fontWeight: FontWeight.bold,
          fontSize: compact ? 10 : null,
        ),
      ),
    );
  }

  (Color, String) _style(BuildContext context, ContentRatingLevel level) {
    final cs = Theme.of(context).colorScheme;
    return switch (level) {
      ContentRatingLevel.g => (CrispyColors.statusSuccess, 'G'),
      ContentRatingLevel.pg => (cs.primary, 'PG'),
      ContentRatingLevel.pg13 => (CrispyColors.statusWarning, 'PG-13'),
      ContentRatingLevel.r => (cs.error, 'R'),
      _ => (cs.onSurfaceVariant, level.code),
    };
  }
}
