import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base class for boolean toggle notifiers.
///
/// Provides a standard `build() => false`, `toggle()`, and `set()`
/// pattern for simple on/off state providers.
abstract class ToggleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Flip state.
  void toggle() => state = !state;

  /// Set state to a specific value.
  void set({required bool value}) => state = value;
}
