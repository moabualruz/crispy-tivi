import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/crispy_animation.dart';

/// A [CustomTransitionPage] that cross-fades between shell route sections.
///
/// Used for compact/medium layouts where screen transitions benefit from
/// a subtle visual cue. TV/large layouts use [NoTransitionPage] instead
/// to maintain the instant-response feel D-pad users expect.
///
/// Duration: [CrispyAnimation.normal] (300 ms, easeOutCubic).
///
/// Usage in GoRouter:
/// ```dart
/// GoRoute(
///   path: AppRoutes.home,
///   pageBuilder: (context, state) =>
///       CrispyFadeTransitionPage(key: state.pageKey, child: HomeScreen()),
/// )
/// ```
class CrispyFadeTransitionPage<T> extends CustomTransitionPage<T> {
  /// Creates a fade-transition page.
  // ignore: prefer_const_constructors_in_immutables
  CrispyFadeTransitionPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.maintainState,
    super.fullscreenDialog,
    super.opaque,
  }) : super(
         transitionDuration: CrispyAnimation.normal,
         reverseTransitionDuration: CrispyAnimation.fast,
         transitionsBuilder: _fadeTransition,
       );

  static Widget _fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: CrispyAnimation.enterCurve,
        reverseCurve: CrispyAnimation.exitCurve,
      ),
      child: child,
    );
  }
}
