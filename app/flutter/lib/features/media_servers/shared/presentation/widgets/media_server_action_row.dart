import 'package:flutter/material.dart';

import 'package:crispy_tivi/core/theme/crispy_spacing.dart';
import 'package:crispy_tivi/core/widgets/or_divider_row.dart';

/// A padded column that renders an `── or ──` divider above [child].
///
/// Used by Emby, Jellyfin, and Plex login screens to present an
/// alternative action (PIN login, Quick Connect, OAuth sign-in) below
/// the credential form. All three screens share the same padding +
/// [OrDividerRow] + spacing + button layout.
///
/// Example:
/// ```dart
/// MediaServerActionRow(
///   child: TextButton.icon(
///     onPressed: _loginWithPin,
///     icon: const Icon(Icons.pin_outlined, size: 18),
///     label: const Text('Login with PIN'),
///   ),
/// )
/// ```
class MediaServerActionRow extends StatelessWidget {
  const MediaServerActionRow({super.key, required this.child});

  /// The action widget (button) rendered below the divider.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CrispySpacing.lg,
        0,
        CrispySpacing.lg,
        CrispySpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OrDividerRow(),
          const SizedBox(height: CrispySpacing.sm),
          child,
        ],
      ),
    );
  }
}
