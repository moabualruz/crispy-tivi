import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Convenience extension for accessing localized strings.
///
/// Usage: `context.l10n.commonCancel`
extension L10nExtension on BuildContext {
  /// Shorthand for `AppLocalizations.of(this)`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
