import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_elevation.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../data/notification_service.dart';

/// Overlay that shows toast notifications at the top of the
/// screen. Place this in the widget tree above your main
/// content (e.g. inside the app shell).
class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(
      notificationServiceProvider.select((s) => s.toasts),
    );

    return Stack(
      children: [
        child,
        // Toast stack
        if (toasts.isNotEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + CrispySpacing.sm,
            left: CrispySpacing.md,
            right: CrispySpacing.md,
            child: Column(
              children: toasts.map((t) => _ToastCard(toast: t)).toList(),
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends ConsumerWidget {
  const _ToastCard({required this.toast});

  final AppToast toast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final crispyColors = Theme.of(context).crispyColors;

    Color backgroundColor;
    IconData icon;
    switch (toast.type) {
      case ToastType.success:
        backgroundColor = crispyColors.successColor;
        icon = Icons.check_circle;
      case ToastType.warning:
        backgroundColor = crispyColors.warningColor;
        icon = Icons.warning;
      case ToastType.error:
        backgroundColor = cs.error;
        icon = Icons.error;
      case ToastType.info:
        backgroundColor = cs.primaryContainer;
        icon = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CrispySpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: CrispyElevation.level2,
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: Colors.white, size: 20),
          title: Text(
            toast.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            tooltip: 'Dismiss',
            onPressed:
                () => ref
                    .read(notificationServiceProvider.notifier)
                    .dismissToast(toast.id),
          ),
        ),
      ),
    );
  }
}
