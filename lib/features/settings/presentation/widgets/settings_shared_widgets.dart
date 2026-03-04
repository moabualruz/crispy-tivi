import 'package:flutter/material.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// Indent (dp) that aligns sub-items with the text of a leading icon tile.
///
/// Matches a 40 dp leading icon + 16 dp content padding gap. Use this
/// for [Divider.indent] on rows below a [ListTile] with a leading icon.
const double kSettingsIndent = 56.0;

/// Width (dp) of the settings side panel on TV/desktop layouts.
///
/// Passed to [SidePanel.width] in [showSettingsPanel]. Wider than the
/// default 400 dp to accommodate settings labels without truncation.
const double kSettingsPanelWidth = 450.0;

/// Small inline badge for settings tiles that are experimental or incomplete.
///
/// Use [SettingsBadge.experimental] for features that are wired up but lack
/// a full backend implementation. Use [SettingsBadge.comingSoon] for features
/// that are purely placeholder UI.
///
/// Intended usage — wrap the [ListTile.title] in a [Row]:
/// ```dart
/// title: Row(children: [
///   Text('My Feature'),
///   const SizedBox(width: CrispySpacing.sm),
///   const SettingsBadge.experimental(),
/// ]),
/// ```
class SettingsBadge extends StatelessWidget {
  /// Orange "Experimental" badge — feature works but backend is incomplete.
  const SettingsBadge.experimental({super.key})
    : _label = 'Experimental',
      _color = const Color(0xFFFF9800);

  /// Grey "Coming Soon" badge — feature is placeholder only.
  const SettingsBadge.comingSoon({super.key})
    : _label = 'Coming Soon',
      _color = const Color(0xFF9E9E9E);

  final String _label;
  final Color _color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(CrispyRadius.xs),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 9,
          color: _color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Rounded card container for settings groups.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
