import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../data/cast_service.dart';

/// Cast device picker dialog.
///
/// Shows available Cast devices and allows connection.
/// Displays a scanning indicator with elapsed time,
/// timeout message after 10 seconds, and error states.
class CastDevicePicker extends ConsumerStatefulWidget {
  /// Creates a [CastDevicePicker].
  const CastDevicePicker({super.key});

  /// Shows the picker as a modal bottom sheet.
  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const CastDevicePicker(),
    );
  }

  @override
  ConsumerState<CastDevicePicker> createState() => _CastDevicePickerState();
}

class _CastDevicePickerState extends ConsumerState<CastDevicePicker> {
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Start discovery when the picker opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(castServiceProvider.notifier).startDiscovery();
      _startElapsedTimer();
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = ref.read(castServiceProvider);
      if (state.isScanning) {
        setState(() => _elapsedSeconds++);
      } else {
        _elapsedTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _onRetry() {
    ref.read(castServiceProvider.notifier).retryDiscovery();
    _startElapsedTimer();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(castServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(CrispySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          const SizedBox(height: CrispySpacing.md),

          // Title row
          _buildTitleRow(state, colorScheme),
          const SizedBox(height: CrispySpacing.md),

          // Connected device banner
          if (state.isConnected && state.connectedDevice != null)
            _buildConnectedBanner(state, colorScheme),

          if (state.isConnected) const SizedBox(height: CrispySpacing.md),

          // Content area: scanning / error / timeout /
          // device list
          _buildContent(state, colorScheme),

          const SizedBox(height: CrispySpacing.md),
        ],
      ),
    );
  }

  Widget _buildTitleRow(CastState state, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(Icons.cast, color: colorScheme.primary),
        const SizedBox(width: CrispySpacing.sm),
        Text(
          'Cast to Device',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (state.isScanning)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_elapsedSeconds}s',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
              const SizedBox(width: CrispySpacing.xs),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ],
          )
        else
          TextButton(onPressed: _onRetry, child: const Text('Scan')),
      ],
    );
  }

  Widget _buildConnectedBanner(CastState state, ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.cast_connected, color: colorScheme.primary),
        title: Text(state.connectedDevice!.name),
        subtitle: Text(state.currentMedia?.title ?? 'Connected'),
        trailing: IconButton(
          onPressed: () => ref.read(castServiceProvider.notifier).disconnect(),
          icon: const Icon(Icons.close),
          tooltip: 'Disconnect',
        ),
      ),
    );
  }

  Widget _buildContent(CastState state, ColorScheme colorScheme) {
    // Error state
    if (state.errorMessage != null) {
      return _buildErrorState(state, colorScheme);
    }

    // Scanning in progress (no devices yet)
    if (state.isScanning && state.devices.isEmpty) {
      return _buildScanningState(colorScheme);
    }

    // Timed out with no devices
    if (state.timedOut && state.devices.isEmpty) {
      return _buildTimeoutState(colorScheme);
    }

    // No devices and not scanning (initial or stopped)
    if (state.devices.isEmpty && !state.isScanning) {
      return _buildEmptyState(colorScheme);
    }

    // Device list
    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          state.devices.map((device) {
            final isConnected = state.connectedDevice?.id == device.id;
            return ListTile(
              leading: Icon(
                isConnected ? Icons.cast_connected : Icons.cast,
                color: isConnected ? colorScheme.primary : null,
              ),
              title: Text(device.name),
              subtitle: device.model != null ? Text(device.model!) : null,
              trailing:
                  isConnected
                      ? Icon(Icons.check_circle, color: colorScheme.primary)
                      : null,
              onTap:
                  isConnected
                      ? null
                      : () async {
                        await ref
                            .read(castServiceProvider.notifier)
                            .connectToDevice(device.id);
                      },
            );
          }).toList(),
    );
  }

  Widget _buildScanningState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xl),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: CrispySpacing.md),
            Text(
              'Scanning for devices...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              '$_elapsedSeconds seconds elapsed',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cast, size: 48, color: colorScheme.outline),
            const SizedBox(height: CrispySpacing.sm),
            const Text('No devices found'),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              'Make sure your Cast device is on '
              'the same network',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: CrispySpacing.md),
            FilledButton.icon(
              onPressed: _onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(CastState state, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'Discovery Error',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: CrispySpacing.xs),
            Text(
              state.errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: CrispySpacing.md),
            FilledButton.icon(
              onPressed: _onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CrispySpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.cast, size: 48, color: colorScheme.outline),
            const SizedBox(height: CrispySpacing.sm),
            const Text('No devices found'),
            const SizedBox(height: CrispySpacing.sm),
            Text(
              'Make sure your Cast device is on '
              'the same network',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: CrispySpacing.md),
            FilledButton.icon(
              onPressed: _onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini-controller shown when casting — sits at the
/// bottom of the screen as a persistent bar.
class CastMiniController extends ConsumerWidget {
  /// Creates a [CastMiniController].
  const CastMiniController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(castServiceProvider);

    // Only show when casting media.
    if (!state.isConnected || state.currentMedia == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final media = state.currentMedia!;
    final isPlaying = state.sessionState == CastSessionState.playing;

    return GlassSurface(
      borderRadius: CrispyRadius.md,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        child: Row(
          children: [
            // Cast icon
            Icon(Icons.cast_connected, color: colorScheme.primary, size: 20),
            const SizedBox(width: CrispySpacing.sm),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    media.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CrispyColors.textHigh,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Casting to '
                    '${state.connectedDevice?.name ?? 'Unknown'}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Play/pause
            IconButton(
              tooltip: 'Play/Pause',
              onPressed: () {
                if (isPlaying) {
                  ref.read(castServiceProvider.notifier).pauseCast();
                } else {
                  ref.read(castServiceProvider.notifier).resumeCast();
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: CrispyColors.textHigh,
              ),
              iconSize: 28,
            ),

            // Stop
            IconButton(
              tooltip: 'Stop',
              onPressed: () {
                ref.read(castServiceProvider.notifier).stopCast();
              },
              icon: const Icon(Icons.stop, color: CrispyColors.textHigh),
              iconSize: 28,
            ),
          ],
        ),
      ),
    );
  }
}
