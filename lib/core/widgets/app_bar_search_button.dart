import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';

/// AppBar action button that navigates to the global search screen.
///
/// Use this in [AppBar.actions] for any screen that wants a search
/// shortcut to [AppRoutes.customSearch].
class AppBarSearchButton extends StatelessWidget {
  const AppBarSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Search',
      onPressed: () => context.go(AppRoutes.customSearch),
    );
  }
}
