import 'package:flutter/material.dart';

/// Shows a generic radio-style selection dialog.
///
/// Renders a [SimpleDialog] with one [SimpleDialogOption] per
/// item in [options]. Each option shows a radio icon (checked/
/// unchecked), a bold label, and an optional description line.
///
/// On selection: pops the dialog, calls [onSelect], then shows
/// a [SnackBar] with the selected label.
///
/// Type parameter [T] is the option type. Pass [getDescription]
/// to add a secondary line; omit it (or return null) for
/// label-only rows.
///
/// Example:
/// ```dart
/// showSettingsSelectionDialog<UpscaleMode>(
///   context: context,
///   title: 'Upscaling Mode',
///   options: UpscaleMode.values,
///   currentValue: currentMode,
///   getLabel: (m) => m.label,
///   getDescription: (m) => m.description,
///   onSelect: (m) async {
///     ref.read(settingsNotifierProvider.notifier)
///        .setUpscaleMode(m.value);
///   },
///   isMounted: () => context.mounted,
/// );
/// ```
void showSettingsSelectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T currentValue,
  required String Function(T) getLabel,
  String? Function(T)? getDescription,
  required void Function(T) onSelect,
  required bool Function() isMounted,
}) {
  showDialog<void>(
    context: context,
    builder:
        (ctx) => SimpleDialog(
          title: Text(title),
          children:
              options.map((option) {
                final isSelected = option == currentValue;
                final label = getLabel(option);
                final description = getDescription?.call(option);

                return SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSelect(option);
                    if (isMounted()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$label selected')),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            description != null
                                ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                    Text(
                                      description,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
  );
}
