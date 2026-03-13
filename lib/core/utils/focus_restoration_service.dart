import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/safe_focus_extension.dart';

/// Tracks the last-focused widget [Key] per route path.
///
/// Stores a map of route path strings to the [Key] of the last
/// focused widget on that route. When navigating away, call
/// [saveFocusKey] to persist the focused element's key. When
/// returning, call [restoreFocus] to re-focus that element.
///
/// ```dart
/// // Save before navigating away:
/// saveFocusKey(ref, '/home');
///
/// // Restore after returning:
/// restoreFocus(ref, '/home', context);
/// ```
final focusRestorationProvider =
    NotifierProvider<FocusRestorationNotifier, Map<String, Key>>(
      FocusRestorationNotifier.new,
    );

/// Notifier that maintains the per-route focus key map.
class FocusRestorationNotifier extends Notifier<Map<String, Key>> {
  @override
  Map<String, Key> build() => {};

  /// Stores [key] for the given [routePath].
  ///
  /// No-ops if the notifier has already been disposed (e.g., when
  /// a deferred callback fires after the Riverpod scope tears down).
  void setKey(String routePath, Key key) {
    try {
      state = {...state, routePath: key};
    } catch (_) {
      // Notifier or Ref disposed — ignore (deferred callback
      // fired after Riverpod scope teardown).
    }
  }

  /// Returns the saved key for [routePath], or `null`.
  Key? getKey(String routePath) => state[routePath];

  /// Clears the saved key for [routePath].
  void clearKey(String routePath) {
    state = Map.of(state)..remove(routePath);
  }
}

/// Saves the currently focused widget's [ValueKey] for the given
/// [routePath].
///
/// Reads [FocusManager.instance.primaryFocus], walks up the
/// ancestor element tree to find the nearest [ValueKey], and
/// stores it in [focusRestorationProvider].
///
/// If no [ValueKey] ancestor is found, does nothing.
///
/// Safe to call from [State.deactivate] — the provider mutation
/// is deferred to avoid modifying state during the build phase.
void saveFocusKey(WidgetRef ref, String routePath) {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return;

  final context = primaryFocus.context;
  if (context == null) return;

  // Check the focus node's own widget first.
  final directKey = context.widget.key;
  // Capture the notifier synchronously (safe during deactivate).
  // Guard with try-catch: ref.read() may throw if the Riverpod
  // scope is already tearing down (e.g., test teardown).
  final FocusRestorationNotifier notifier;
  try {
    notifier = ref.read(focusRestorationProvider.notifier);
  } catch (_) {
    return; // Widget/scope already disposed — nothing to save.
  }

  if (directKey is ValueKey) {
    // Defer the state mutation so it never fires during the
    // build phase, which would trigger "modified a provider while
    // the widget tree was building".
    scheduleMicrotask(() => notifier.setKey(routePath, directKey));
    return;
  }

  // Walk up to find the nearest ValueKey ancestor.
  Key? found;
  context.visitAncestorElements((element) {
    final key = element.widget.key;
    if (key is ValueKey) {
      found = key;
      return false; // stop walking
    }
    return true; // continue
  });

  if (found != null) {
    final key = found!;
    scheduleMicrotask(() => notifier.setKey(routePath, key));
  }
}

/// Restores focus to the widget identified by the saved [Key]
/// for the given [routePath].
///
/// Schedules a post-frame callback to find the widget by key
/// and request focus via [SafeFocusExtension.requestFocusSafely].
///
/// If the saved key is `null` or the widget is no longer in the
/// tree, this is a no-op.
void restoreFocus(WidgetRef ref, String routePath, BuildContext context) {
  final savedKey = ref
      .read(focusRestorationProvider.notifier)
      .getKey(routePath);
  if (savedKey == null) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Walk the element tree to find the widget with the saved key.
    void visitor(Element element) {
      if (element.widget.key == savedKey) {
        // Found the widget — try to find its FocusNode.
        final focusNode = _findFocusNode(element);
        focusNode?.requestFocusSafely();
        return;
      }
      element.visitChildren(visitor);
    }

    // Start from the nearest overlay or root.
    final rootElement = context as Element;
    rootElement.visitChildren(visitor);
  });
}

/// Finds the [FocusNode] associated with an element, if any.
FocusNode? _findFocusNode(Element element) {
  FocusNode? found;
  void visitor(Element child) {
    if (found != null) return;
    if (child.widget is Focus) {
      final focusWidget = child.widget as Focus;
      found = focusWidget.focusNode;
    }
    if (found == null) child.visitChildren(visitor);
  }

  // Check the element itself.
  if (element.widget is Focus) {
    return (element.widget as Focus).focusNode;
  }
  element.visitChildren(visitor);
  return found;
}
