import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/dart_algorithm_fallbacks.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../iptv/domain/entities/channel.dart';

/// Slide-in channel zap overlay for quick channel switching
/// during playback.
///
/// Animates from the right edge, shows a scrollable list of
/// channels, and auto-dismisses when a channel is selected.
class ChannelZapOverlay extends StatefulWidget {
  const ChannelZapOverlay({
    required this.channels,
    required this.currentChannelId,
    required this.onChannelSelected,
    required this.onDismiss,
    required this.isVisible,
    super.key,
  });

  final List<Channel> channels;
  final String currentChannelId;
  final ValueChanged<Channel> onChannelSelected;
  final VoidCallback onDismiss;
  final bool isVisible;

  @override
  State<ChannelZapOverlay> createState() => _ChannelZapOverlayState();
}

/// Minimum width for the zap panel so it is always readable.
const double _kZapPanelMinWidth = 220.0;

class _ChannelZapOverlayState extends State<ChannelZapOverlay> {
  String? _selectedGroup;
  final _scrollController = ScrollController();

  // ── Memoised derived lists ───────────────────────────────
  List<String>? _cachedGroups;
  List<Channel>? _cachedChannels;
  List<Channel>? _cachedFilteredChannels;
  String? _cachedFilterGroup;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _groups {
    if (_cachedGroups == null || _cachedChannels != widget.channels) {
      _cachedChannels = widget.channels;
      _cachedGroups = null;
      _cachedFilteredChannels = null;
      final groups = <String>{};
      for (final ch in widget.channels) {
        if (ch.group != null && ch.group!.isNotEmpty) {
          groups.add(ch.group!);
        }
      }
      _cachedGroups = groups.toList()..sort(categoryBucketCompare);
    }
    return _cachedGroups!;
  }

  List<Channel> get _filteredChannels {
    if (_cachedFilteredChannels == null ||
        _cachedChannels != widget.channels ||
        _cachedFilterGroup != _selectedGroup) {
      _cachedChannels = widget.channels;
      _cachedFilterGroup = _selectedGroup;
      _cachedFilteredChannels =
          _selectedGroup == null
              ? widget.channels
              : widget.channels
                  .where((ch) => ch.group == _selectedGroup)
                  .toList();
    }
    return _cachedFilteredChannels!;
  }

  @override
  void didUpdateWidget(ChannelZapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to current channel when overlay becomes
    // visible.
    if (widget.isVisible && !oldWidget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentChannel();
      });
    }
  }

  void _scrollToCurrentChannel() {
    final channels = _filteredChannels;
    final idx = channels.indexWhere((ch) => ch.id == widget.currentChannelId);
    if (idx < 0 || !_scrollController.hasClients) return;

    // Approximate item height = 40px.
    final target = idx * 40.0;
    final viewport = _scrollController.position.viewportDimension;
    _scrollController.animateTo(
      (target - viewport / 2).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: CrispyAnimation.normal,
      curve: CrispyAnimation.scrollCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth * 0.35;
    final constrainedWidth = panelWidth.clamp(
      _kZapPanelMinWidth,
      double.infinity,
    );
    final groups = _groups;
    final filtered = _filteredChannels;

    return AnimatedPositioned(
      duration: CrispyAnimation.normal,
      curve: Curves.easeOutCubic,
      right: widget.isVisible ? 0 : -constrainedWidth,
      top: 0,
      bottom: 0,
      width: constrainedWidth,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                widget.onDismiss();
                return null;
              },
            ),
          },
          child: GlassSurface(
            borderRadius: 0,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + CrispySpacing.md,
              bottom: MediaQuery.paddingOf(context).bottom + CrispySpacing.md,
            ),
            child: FocusTraversalGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CrispySpacing.md,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Channels',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: Icon(
                            Icons.close,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: widget.onDismiss,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),

                  // ── Group filter tabs ──
                  if (groups.length > 1) ...[
                    const SizedBox(height: CrispySpacing.xs),
                    SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.sm,
                        ),
                        children: [
                          _GroupChip(
                            label: 'All',
                            isSelected: _selectedGroup == null,
                            onTap: () {
                              setState(() => _selectedGroup = null);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToCurrentChannel();
                              });
                            },
                          ),
                          ...groups.map(
                            (g) => _GroupChip(
                              label: g,
                              isSelected: _selectedGroup == g,
                              onTap: () {
                                setState(() => _selectedGroup = g);
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _scrollToCurrentChannel();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: CrispySpacing.sm),

                  // ── Channel list ──
                  Expanded(
                    child: FocusTraversalGroup(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.sm,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ch = filtered[index];
                          final isCurrent = ch.id == widget.currentChannelId;

                          return FocusWrapper(
                            autofocus: isCurrent,
                            onSelect: () => widget.onChannelSelected(ch),
                            borderRadius: CrispyRadius.sm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CrispySpacing.sm,
                                vertical: CrispySpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.zero,
                                color:
                                    isCurrent
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.15)
                                        : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  // Number
                                  if (ch.number != null)
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${ch.number}',
                                        style: TextStyle(
                                          color:
                                              isCurrent
                                                  ? colorScheme.onSurface
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                          fontWeight:
                                              isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),

                                  // Name
                                  Expanded(
                                    child: Text(
                                      ch.name,
                                      style: TextStyle(
                                        color:
                                            isCurrent
                                                ? colorScheme.onSurface
                                                : colorScheme.onSurfaceVariant,
                                        fontWeight:
                                            isCurrent
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Now playing indicator
                                  if (isCurrent)
                                    Icon(
                                      Icons.play_arrow,
                                      color: colorScheme.onSurface,
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chip for filtering channels by group.
class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: CrispySpacing.xs),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color:
                isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
        selectedColor: colorScheme.primary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}
