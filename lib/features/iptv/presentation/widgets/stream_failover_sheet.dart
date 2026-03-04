import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/crispy_colors.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../domain/entities/channel.dart';

/// A single alternative stream option for a channel.
@immutable
class StreamOption {
  const StreamOption({required this.url, this.label, this.quality});

  /// The stream URL.
  final String url;

  /// Human-readable label (e.g. source name, server location).
  final String? label;

  /// Quality tag (e.g. "HD", "FHD", "SD", "4K").
  final String? quality;

  /// Display title shown in the picker list.
  String get displayTitle => label ?? _truncateUrl(url);

  /// Truncates a URL to the last 40 characters for display.
  static String _truncateUrl(String url) {
    if (url.length <= 40) return url;
    return '…${url.substring(url.length - 40)}';
  }
}

/// Builds the list of [StreamOption] objects for [channel].
///
/// Currently each [Channel] carries a single [Channel.streamUrl].
/// When backup URLs are available (e.g. Xtream multi-server),
/// callers pass them directly as [extraUrls]. The primary stream
/// is always listed first.
List<StreamOption> buildStreamOptions(
  Channel channel, {
  List<String> extraUrls = const [],
}) {
  return [
    StreamOption(
      url: channel.streamUrl,
      label: 'Primary stream',
      quality: channel.resolution,
    ),
    for (final (i, url) in extraUrls.indexed)
      StreamOption(url: url, label: 'Backup stream ${i + 1}'),
  ];
}

/// Shows a modal bottom sheet that lets the user pick an
/// alternative stream URL for [channel].
///
/// Returns the chosen [StreamOption], or `null` if dismissed.
///
/// Usage:
/// ```dart
/// final picked = await showStreamFailoverSheet(
///   context: context,
///   ref: ref,
///   channel: channel,
///   currentUrl: channel.streamUrl,
///   options: buildStreamOptions(channel, extraUrls: backups),
///   onStreamSelected: (option) { /* play option.url */ },
/// );
/// ```
Future<StreamOption?> showStreamFailoverSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  required List<StreamOption> options,
  required String currentUrl,
  required void Function(StreamOption) onStreamSelected,
}) {
  return showModalBottomSheet<StreamOption>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder:
        (_) => StreamFailoverSheet(
          channel: channel,
          options: options,
          currentUrl: currentUrl,
          onStreamSelected: onStreamSelected,
        ),
  );
}

/// Bottom sheet displaying stream alternatives for a channel.
///
/// Shows a list of [StreamOption] entries. The currently playing
/// URL is highlighted. Tapping a row fires [onStreamSelected] and
/// closes the sheet.
class StreamFailoverSheet extends ConsumerWidget {
  const StreamFailoverSheet({
    super.key,
    required this.channel,
    required this.options,
    required this.currentUrl,
    required this.onStreamSelected,
  });

  final Channel channel;
  final List<StreamOption> options;

  /// The URL that is currently playing (used to highlight
  /// the active stream).
  final String currentUrl;

  /// Called when the user selects a different stream.
  final void Function(StreamOption) onStreamSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final crispyColors = theme.crispyColors;

    // Sheet body — glassmorphic background matching
    // the design system's bottom sheet style.
    return ClipRRect(
      borderRadius: CrispyRadius.top(CrispyRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: crispyColors.glassBlur,
          sigmaY: crispyColors.glassBlur,
        ),
        child: Container(
          color: colorScheme.surface,
          // Limit height to 50 % of the screen so the sheet
          // doesn't cover the entire UI on phones.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    vertical: CrispySpacing.sm,
                  ),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  ),
                ),
              ),
              // ── Header ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CrispySpacing.md,
                  CrispySpacing.xs,
                  CrispySpacing.md,
                  CrispySpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stream sources',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: CrispySpacing.xxs),
                    Text(
                      channel.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // ── Stream list ──────────────────────────────
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.paddingOf(context).bottom + CrispySpacing.sm,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, i) {
                    final option = options[i];
                    final isActive = option.url == currentUrl;
                    return _StreamOptionTile(
                      option: option,
                      isActive: isActive,
                      onTap: () {
                        Navigator.of(context).pop(option);
                        onStreamSelected(option);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single stream option row in [StreamFailoverSheet].
class _StreamOptionTile extends StatelessWidget {
  const _StreamOptionTile({
    required this.option,
    required this.isActive,
    required this.onTap,
  });

  final StreamOption option;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.md,
        vertical: CrispySpacing.xs,
      ),
      leading: _StreamIcon(
        quality: option.quality,
        isActive: isActive,
        colorScheme: colorScheme,
      ),
      title: Text(
        option.displayTitle,
        style: textTheme.bodyMedium?.copyWith(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? colorScheme.primary : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          option.quality != null
              ? Text(
                option.quality!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              )
              : null,
      trailing:
          isActive
              ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
              : null,
      onTap: isActive ? null : onTap,
    );
  }
}

/// Leading icon for a stream option tile.
///
/// Shows an active play indicator when [isActive] or a
/// signal icon otherwise.
class _StreamIcon extends StatelessWidget {
  const _StreamIcon({
    required this.quality,
    required this.isActive,
    required this.colorScheme,
  });

  final String? quality;
  final bool isActive;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color:
            isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
      ),
      child: Icon(
        isActive ? Icons.play_circle_fill : Icons.signal_cellular_alt,
        color:
            isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface.withValues(alpha: 0.6),
        size: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stream Override Provider
// ─────────────────────────────────────────────────────────────

/// Notifier that tracks per-channel stream URL overrides.
///
/// Stores a map of channelId → selected stream URL.
/// Falls back to [Channel.streamUrl] when no override is set.
class ChannelStreamOverrideNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// Records [url] as the active stream for [channelId].
  void setUrl(String channelId, String url) {
    state = Map.unmodifiable({...state, channelId: url});
  }

  /// Clears the override for [channelId].
  void clear(String channelId) {
    final updated = Map<String, String>.from(state)..remove(channelId);
    state = Map.unmodifiable(updated);
  }

  /// Returns the active URL for [channelId], or `null` if none.
  String? urlFor(String channelId) => state[channelId];
}

/// Provider that tracks which stream URL the user has
/// manually selected, keyed by channel ID.
///
/// Read the active URL via:
/// ```dart
/// ref.watch(channelStreamOverrideProvider
///     .select((m) => m[channelId]));
/// ```
final channelStreamOverrideProvider =
    NotifierProvider<ChannelStreamOverrideNotifier, Map<String, String>>(
      ChannelStreamOverrideNotifier.new,
    );
