import 'package:flutter/widgets.dart';

/// Returns `true` when the currently focused widget is inside an
/// [EditableText] (i.e., a [TextField] or [TextFormField] is active).
///
/// Use this at the top of global keyboard handlers to skip shortcuts
/// that would interfere with text input (letters, digits, slash, etc.).
/// D-pad / arrow keys are intentionally NOT blocked so focus traversal
/// between fields still works.
bool isTextFieldFocused() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;
  final context = primaryFocus.context;
  if (context == null) return false;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

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
