import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin that tracks which list item had focus, so focus can be
/// restored after data reloads or tab switches (critical for TV/keyboard).
///
/// Usage:
/// 1. Apply the mixin: `with FocusMemoryMixin<MyScreen>`
/// 2. In your item builder: `focusNode: focusNodeFor(item.id)`
/// 3. In item's onFocusChange: `if (hasFocus) onItemFocused(item.id);`
/// 4. After data loads: call `restoreFocus()` via addPostFrameCallback
/// 5. In dispose: call `disposeFocusMemory()` before super.dispose()
mixin FocusMemoryMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _focusMemory = <String, FocusNode>{};
  String? _lastFocusedKey;

  /// Returns (or creates) a FocusNode for the given key.
  FocusNode focusNodeFor(String key) {
    return _focusMemory.putIfAbsent(key, () => FocusNode(debugLabel: key));
  }

  /// Record which item currently has focus.
  void onItemFocused(String key) => _lastFocusedKey = key;

  /// Restore focus to the last-focused item after a rebuild.
  void restoreFocus() {
    final key = _lastFocusedKey;
    if (key != null && _focusMemory.containsKey(key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusMemory[key]?.requestFocus();
      });
    }
  }

  /// Dispose all managed FocusNodes. Call in dispose() before super.
  void disposeFocusMemory() {
    for (final node in _focusMemory.values) {
      node.dispose();
    }
    _focusMemory.clear();
  }
}
