import 'package:flutter/widgets.dart';

/// Attempts to unfocus a text field that currently has primary focus.
///
/// Returns `true` if an [EditableText] ancestor was found and unfocused
/// (Escape first press should stop here). Returns `false` if no text
/// field was focused (caller should proceed to pop/navigate back).
bool tryUnfocusTextFieldFirst() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus != null &&
      primaryFocus.context?.findAncestorWidgetOfExactType<EditableText>() !=
          null) {
    primaryFocus.unfocus();
    return true;
  }
  return false;
}
