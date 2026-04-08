import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';

/// Diameter of each cast member avatar.
const _kAvatarDiameter = 72.0;

/// Width of each cast member card (avatar + name + character).
const _kCardWidth = 80.0;

/// Total height of the cast scroll section (header + cards).
const _kSectionHeight = 130.0;

/// Horizontal scroll row of cast/crew members.
///
/// Displays a circular avatar placeholder with the actor name below.
/// When [castNames] is null or empty the widget renders nothing.
///
/// Used in both [VodDetailsScreen] (FE-VODS-01) and
/// [SeriesDetailsTab] (FE-SRD-07).
///
/// ```dart
/// CastScrollRow(castNames: item.cast)
/// ```
class CastScrollRow extends StatelessWidget {
  /// Creates a cast scroll row.
  ///
  /// Pass [castNames] from [VodItem.cast]. The widget is hidden when
  /// the list is null or empty.
  const CastScrollRow({super.key, required this.castNames});

  /// Actor/crew names to display. Null or empty → widget hidden.
  final List<String>? castNames;

  @override
  Widget build(BuildContext context) {
    final names = castNames;
    if (names == null || names.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: CrispySpacing.lg,
            right: CrispySpacing.lg,
            top: CrispySpacing.lg,
            bottom: CrispySpacing.sm,
          ),
          child: SectionHeader(
            title: 'Cast & Crew',
            icon: Icons.people_alt_outlined,
          ),
        ),
        SizedBox(
          height: _kSectionHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.lg),
            itemCount: names.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: CrispySpacing.md),
                child: SizedBox(
                  width: _kCardWidth,
                  child: _CastMemberCard(name: names[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Single cast member card: circular avatar + name.
class _CastMemberCard extends StatelessWidget {
  const _CastMemberCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Derive initials from name (up to 2 characters).
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials =
        parts.length >= 2
            ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
            : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular avatar with initials fallback.
        Container(
          width: _kAvatarDiameter,
          height: _kAvatarDiameter,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(CrispyRadius.full),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Center(
            child: Text(
              initials,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: CrispySpacing.xs),
        // Actor name — single line, ellipsis overflow.
        Text(
          name,
          style: tt.bodySmall?.copyWith(color: cs.onSurface),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
