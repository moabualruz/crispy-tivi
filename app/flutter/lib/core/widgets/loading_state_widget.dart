import 'package:flutter/material.dart';

/// A centered [CircularProgressIndicator] for async loading states.
///
/// Use as a drop-in replacement for
/// `Center(child: CircularProgressIndicator())` throughout the app.
///
/// ```dart
/// if (isLoading) return const LoadingStateWidget();
/// ```
class LoadingStateWidget extends StatelessWidget {
  const LoadingStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
