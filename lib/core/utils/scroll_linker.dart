import 'package:flutter/widgets.dart';

/// A group of [ScrollController]s that are linked together.
///
/// When one controller scrolls, all other controllers in the group
/// are updated to match its offset.
class ScrollLinker {
  final Map<ScrollController, VoidCallback> _listeners = {};

  void add(ScrollController controller) {
    void listener() => _onScroll(controller);
    _listeners[controller] = listener;
    controller.addListener(listener);
  }

  bool _isSyncing = false;

  void _onScroll(ScrollController driver) {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      for (final controller in _listeners.keys) {
        if (controller != driver) {
          if (controller.hasClients) {
            controller.jumpTo(driver.offset);
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
  }
}
