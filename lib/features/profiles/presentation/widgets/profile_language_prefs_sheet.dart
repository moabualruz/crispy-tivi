import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../data/profile_service.dart';
import '../../domain/entities/user_profile.dart';

/// Known BCP-47 language codes with human-readable labels.
const List<(String, String)> _kKnownLanguages = [
  ('en', 'English'),
  ('fr', 'French'),
  ('de', 'German'),
  ('es', 'Spanish'),
  ('it', 'Italian'),
  ('pt', 'Portuguese'),
  ('nl', 'Dutch'),
  ('pl', 'Polish'),
  ('ru', 'Russian'),
  ('ja', 'Japanese'),
  ('ko', 'Korean'),
  ('zh', 'Chinese'),
  ('ar', 'Arabic'),
  ('tr', 'Turkish'),
  ('sv', 'Swedish'),
  ('da', 'Danish'),
  ('fi', 'Finnish'),
  ('nb', 'Norwegian'),
  ('cs', 'Czech'),
  ('hu', 'Hungarian'),
];

/// A modal bottom sheet for editing per-profile language and subtitle
/// preferences (FE-PM-07).
///
/// Shows three controls:
/// - Preferred audio language dropdown
/// - Preferred subtitle language dropdown
/// - Subtitle enabled by default toggle
///
/// Usage:
/// ```dart
/// ProfileLanguagePrefsSheet.show(context, ref, profile: profile);
/// ```
class ProfileLanguagePrefsSheet extends ConsumerStatefulWidget {
  const ProfileLanguagePrefsSheet({required this.profile, super.key});

  /// The profile whose language preferences are being edited.
  final UserProfile profile;

  /// Shows the sheet over [context].
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required UserProfile profile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProfileLanguagePrefsSheet(profile: profile),
    );
  }

  @override
  ConsumerState<ProfileLanguagePrefsSheet> createState() =>
      _ProfileLanguagePrefsSheetState();
}

class _ProfileLanguagePrefsSheetState
    extends ConsumerState<ProfileLanguagePrefsSheet> {
  late String? _audioLanguage;
  late String? _subtitleLanguage;
  late bool _subtitleEnabled;

  @override
  void initState() {
    super.initState();
    _audioLanguage = widget.profile.preferredAudioLanguage;
    _subtitleLanguage = widget.profile.preferredSubtitleLanguage;
    _subtitleEnabled = widget.profile.subtitleEnabledByDefault;
  }

  Future<void> _save() async {
    await ref
        .read(profileServiceProvider.notifier)
        .updateProfileLanguagePrefs(
          widget.profile.id,
          preferredAudioLanguage: _audioLanguage,
          clearAudioLanguage: _audioLanguage == null,
          preferredSubtitleLanguage: _subtitleLanguage,
          clearSubtitleLanguage: _subtitleLanguage == null,
          subtitleEnabledByDefault: _subtitleEnabled,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        CrispySpacing.md,
        CrispySpacing.md,
        CrispySpacing.md,
        CrispySpacing.md + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // Title
          Text(
            'Language & Subtitle Preferences',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'Settings for ${widget.profile.name}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),

          // Audio language
          _SectionLabel(label: 'Preferred Audio Language'),
          const SizedBox(height: CrispySpacing.xs),
          _LanguageDropdown(
            value: _audioLanguage,
            hint: 'No preference (stream default)',
            onChanged: (lang) => setState(() => _audioLanguage = lang),
          ),
          const SizedBox(height: CrispySpacing.md),

          // Subtitle language
          _SectionLabel(label: 'Preferred Subtitle Language'),
          const SizedBox(height: CrispySpacing.xs),
          _LanguageDropdown(
            value: _subtitleLanguage,
            hint: 'No preference (stream default)',
            onChanged: (lang) => setState(() => _subtitleLanguage = lang),
          ),
          const SizedBox(height: CrispySpacing.md),

          // Subtitle enabled toggle
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(CrispyRadius.tv),
            ),
            child: SwitchListTile(
              value: _subtitleEnabled,
              onChanged: (v) => setState(() => _subtitleEnabled = v),
              title: const Text('Enable Subtitles by Default'),
              subtitle: Text(
                'Turn on subtitles automatically when playback starts.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CrispySpacing.md,
                vertical: CrispySpacing.xs,
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.lg),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save Preferences'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small section label used inside the language prefs sheet.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Dropdown for selecting a BCP-47 language code from [_kKnownLanguages].
///
/// Null value maps to "No preference".
class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CrispySpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: DropdownButton<String?>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Text(hint),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              hint,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ..._kKnownLanguages.map(
            ((String, String) lang) => DropdownMenuItem<String?>(
              value: lang.$1,
              child: Text('${lang.$2} (${lang.$1})'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
