import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/section_header.dart';
import 'settings_shared_widgets.dart';

/// Supported locales with their native display names.
///
/// Used by the language picker to show each language in its own
/// script so users can identify their language regardless of the
/// current app locale.
const Map<String, String> kSupportedLocaleNames = {
  'en': 'English',
  'ar': 'العربية',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'pt': 'Português',
  'ru': 'Русский',
  'tr': 'Türkçe',
  'zh': '中文',
};

/// Language settings section — locale selection dropdown.
///
/// Shows a dropdown with all supported locales. Selecting a locale
/// immediately updates [SettingsNotifier.setLocale] which causes
/// [MaterialApp] to rebuild with the new locale.
///
/// "System Default" clears the preference and falls back to the
/// device locale.
class LanguageSettingsSection extends ConsumerWidget {
  const LanguageSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(settingsNotifierProvider).value?.locale;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.settingsLanguage,
          icon: Icons.language,
          colorTitle: true,
        ),
        const SizedBox(height: CrispySpacing.sm),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.translate),
              title: Text(l10n.settingsLanguage),
              subtitle: Text(
                currentLocale != null
                    ? kSupportedLocaleNames[currentLocale] ?? currentLocale
                    : l10n.settingsLanguageSystem,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(context, ref, currentLocale),
            ),
          ],
        ),
      ],
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    String? currentLocale,
  ) {
    final l10n = context.l10n;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: CrispySpacing.sm),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CrispySpacing.md,
                    vertical: CrispySpacing.md,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.settingsLanguage,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        iconSize: 20,
                        tooltip: l10n.commonClose,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Language list
                Flexible(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: CrispySpacing.sm,
                    ),
                    children: [
                      // System Default option
                      _LanguageTile(
                        languageCode: null,
                        nativeName: l10n.settingsLanguageSystem,
                        isSelected: currentLocale == null,
                        onTap: () {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setLocale(null);
                          Navigator.of(context).pop();
                        },
                      ),
                      // All supported locales
                      ...kSupportedLocaleNames.entries.map(
                        (entry) => _LanguageTile(
                          languageCode: entry.key,
                          nativeName: entry.value,
                          isSelected: currentLocale == entry.key,
                          onTap: () {
                            ref
                                .read(settingsNotifierProvider.notifier)
                                .setLocale(entry.key);
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A single language option tile.
class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.languageCode,
    required this.nativeName,
    required this.isSelected,
    required this.onTap,
  });

  final String? languageCode;
  final String nativeName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading:
          languageCode == null
              ? const Icon(Icons.phone_android)
              : const Icon(Icons.language),
      title: Text(
        nativeName,
        style: textTheme.bodyLarge?.copyWith(
          color: isSelected ? colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle:
          languageCode != null
              ? Text(languageCode!.toUpperCase(), style: textTheme.bodySmall)
              : null,
      trailing:
          isSelected
              ? Icon(Icons.check_circle, color: colorScheme.primary)
              : null,
      onTap: onTap,
    );
  }
}
