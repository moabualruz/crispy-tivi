import 'package:flutter/material.dart';

import '../extensions/safe_focus_extension.dart';

/// Shows a dialog that saves and restores focus around its
/// lifecycle.
///
/// Before opening the dialog, captures the currently focused
/// element via [FocusManager.instance.primaryFocus]. After the
/// dialog is dismissed, restores focus to that element using
/// [SafeFocusExtension.requestFocusSafely].
///
/// The dialog content is wrapped in a [FocusScope] with
/// [autofocus] to trap focus within the dialog.
///
/// ```dart
/// final result = await showFocusRestoringDialog<bool>(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Confirm'),
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.pop(context, true),
///         child: Text('OK'),
///       ),
///     ],
///   ),
/// );
/// ```
Future<T?> showFocusRestoringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) async {
  // Capture current focus before opening dialog.
  final previousFocus = FocusManager.instance.primaryFocus;

  final result = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    builder: (dialogContext) {
      return FocusScope(autofocus: true, child: builder(dialogContext));
    },
  );

  // Restore focus to the element that was focused before the
  // dialog opened. Uses requestFocusSafely so it's a no-op
  // if the node was disposed while the dialog was open.
  if (previousFocus != null) {
    previousFocus.requestFocusSafely();
  }

  return result;
}

/// Shows a modal bottom sheet that saves and restores focus
/// around its lifecycle.
///
/// Same pattern as [showFocusRestoringDialog] but for bottom
/// sheets. Captures focus before opening and restores after
/// dismissal.
Future<T?> showFocusRestoringModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  RouteSettings? routeSettings,
}) async {
  // Capture current focus before opening sheet.
  final previousFocus = FocusManager.instance.primaryFocus;

  final result = await showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    routeSettings: routeSettings,
    builder: (sheetContext) {
      return FocusScope(autofocus: true, child: builder(sheetContext));
    },
  );

  // Restore focus.
  if (previousFocus != null) {
    previousFocus.requestFocusSafely();
  }

  return result;
}
