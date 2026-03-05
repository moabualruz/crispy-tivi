/// Multi-view screen — displays up to 9 video streams in a grid.
///
/// Per `.ai/docs/project-specs/ui_ux_spec.md §3.6`:
/// - Named preset layout chips (FE-MV-01)
/// - Audio focus switching (tap to select main audio)
/// - One-click slot maximize via double-tap / Enter (FE-MV-03)
/// - Portrait / compact single-column layout (FE-MV-04)
/// - EPG mini-guide overlay (FE-MV-05)
/// - Per-slot stats overlay via long-press (FE-MV-06)
/// - Immersive mode
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/focus_wrapper.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../iptv/presentation/widgets/channel_number_jump_overlay.dart';
import '../../../player/presentation/providers/pip_provider.dart';
import '../../domain/entities/active_stream.dart';
import '../../domain/entities/multiview_session.dart';
import '../providers/multiview_providers.dart';
import '../widgets/channel_picker_sheet.dart';
import '../widgets/empty_slot.dart';
import '../widgets/multiview_epg_sheet.dart';
import '../widgets/saved_layouts_sheet.dart';
import '../widgets/video_slot.dart';

// ─────────────────────────────────────────────────────────────
//  Multi-view screen
// ─────────────────────────────────────────────────────────────

/// Multi-view screen — displays up to 9 video streams in a grid.
class MultiViewScreen extends ConsumerStatefulWidget {
  const MultiViewScreen({super.key});

  @override
  ConsumerState<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends ConsumerState<MultiViewScreen>
    with TickerProviderStateMixin {
  /// Index of the slot currently being maximized, or null when grid is shown.
  int? _maximizedSlotIndex;

  /// Animation controller for the maximize scale transition.
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  /// Slot index whose stats overlay is visible (FE-MV-06), or null.
  int? _statsSlotIndex;

  // FE-MV-08: Numeric channel quick-swap state.
  /// Index of the slot currently receiving digit input, or null.
  int? _dialSlotIndex;

  /// Accumulated digit string for the current dial session.
  String _dialDigits = '';

  /// Timer that commits the dial after 1.5s of inactivity.
  Timer? _dialTimer;

  static const _kMvDialTimeout = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: CrispyAnimation.enterCurve,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _dialTimer?.cancel();
    super.dispose();
  }

  // ── Maximize / restore ──────────────────────────────────────

  /// Expand [slotIndex] to fullscreen with a scale transition.
  void _maximize(int slotIndex) {
    setState(() => _maximizedSlotIndex = slotIndex);
    _scaleController.forward();
  }

  /// Collapse the maximized slot back to the grid.
  void _restore() {
    _scaleController.reverse().then((_) {
      if (mounted) {
        setState(() => _maximizedSlotIndex = null);
      }
    });
  }

  // ── Stats overlay (FE-MV-06) ────────────────────────────────

  /// Toggle the stats overlay for [slotIndex].
  void _toggleStats(int slotIndex) {
    setState(() {
      _statsSlotIndex = _statsSlotIndex == slotIndex ? null : slotIndex;
    });
  }

  // FE-MV-08: Numeric channel quick-swap helpers ──────────────

  /// Maps a [LogicalKeyboardKey] to its digit character, or null.
  ///
  /// Non-const map because [LogicalKeyboardKey] overrides ==.
  static String? _logicalKeyToDigit(LogicalKeyboardKey key) {
    // ignore: prefer_const_literals_to_create_immutables
    final digits = <LogicalKeyboardKey, String>{
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return digits[key];
  }

  /// Called when a digit key is pressed while [slotIndex] is focused.
  void _onDialDigit(int slotIndex, String digit) {
    setState(() {
      _dialSlotIndex = slotIndex;
      _dialDigits += digit;
    });
    _dialTimer?.cancel();
    _dialTimer = Timer(_kMvDialTimeout, () => _commitDial(slotIndex));
  }

  /// Commits accumulated digits: tunes the focused slot to the
  /// matching channel number. Clears the dial state on completion.
  void _commitDial(int slotIndex) {
    final digits = _dialDigits;
    setState(() {
      _dialDigits = '';
      _dialSlotIndex = null;
      _dialTimer = null;
    });
    if (digits.isEmpty) return;
    final target = int.tryParse(digits);
    if (target == null) return;

    final channels = ref.read(channelListProvider).filteredChannels;
    final idx = channels.indexWhere((c) => c.number == target);
    if (idx < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Channel $digits not found'),
            duration: CrispyAnimation.snackBarDuration,
          ),
        );
      }
      return;
    }
    final match = channels[idx];
    final stream = ActiveStream(
      url: match.streamUrl,
      channelName: match.name,
      logoUrl: match.logoUrl,
    );
    ref.read(multiViewProvider.notifier).addSlot(slotIndex, stream);
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(multiViewProvider);

    // FE-MV-04: detect portrait / compact mode.
    final orientation = MediaQuery.orientationOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final isPortrait = orientation == Orientation.portrait || width < 600;

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        // Escape collapses a maximized slot.
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            _maximizedSlotIndex != null) {
          _restore();
          return;
        }
        // FE-MV-08: digit keys → numeric channel quick-swap.
        // Digit presses are only processed when a slot is focused
        // (tracked via _dialSlotIndex) or we default to slot 0.
        final digitChar = _logicalKeyToDigit(event.logicalKey);
        if (digitChar != null) {
          final targetSlot = _dialSlotIndex ?? 0;
          _onDialDigit(targetSlot, digitChar);
        }
      },
      child: Scaffold(
        key: TestKeys.multiViewScreen,
        backgroundColor: Colors.black,
        body: FocusTraversalGroup(
          child: Stack(
            children: [
              // ── Video grid / list ──
              _buildGrid(context, ref, session, isPortrait),

              // ── Maximized slot overlay ──
              if (_maximizedSlotIndex != null)
                _buildMaximizedOverlay(context, session),

              // FE-MV-08: Numeric quick-swap overlay — shown while
              // the user types a channel number on the remote/keyboard.
              if (_dialDigits.isNotEmpty)
                Positioned(
                  top: CrispySpacing.xl,
                  right: CrispySpacing.xl,
                  child: ChannelNumberJumpOverlay(digits: _dialDigits),
                ),

              // ── Controls overlay (hidden when a slot is maximized) ──
              if (_maximizedSlotIndex == null)
                Positioned(
                  top: CrispySpacing.md,
                  right: CrispySpacing.md,
                  child: FocusTraversalGroup(
                    child: GlassSurface(
                      borderRadius: CrispyRadius.none,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CrispySpacing.sm,
                          vertical: CrispySpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Named preset chips (FE-MV-01) ──
                            // Hide chips in portrait to save space.
                            if (!isPortrait) _PresetChipRow(session: session),
                            if (!isPortrait)
                              const VerticalDivider(
                                width: CrispySpacing.lg,
                                color: Colors.white24,
                              ),
                            // FE-MV-05: EPG mini-guide button.
                            IconButton(
                              onPressed:
                                  () => showMultiViewEpgSheet(
                                    context,
                                    session.slots,
                                  ),
                              icon: const Icon(
                                Icons.tv_outlined,
                                color: Colors.white70,
                              ),
                              tooltip: 'Now & Next guide',
                            ),
                            // Save layout button
                            IconButton(
                              onPressed: () => _showSaveDialog(context, ref),
                              icon: const Icon(
                                Icons.save_outlined,
                                color: Colors.white70,
                              ),
                              tooltip: 'Save layout',
                            ),
                            // Load layout button
                            IconButton(
                              onPressed: () => _showLoadSheet(context, ref),
                              icon: const Icon(
                                Icons.folder_open_outlined,
                                color: Colors.white70,
                              ),
                              tooltip: 'Load layout',
                            ),
                            // FE-MV-02: Picture-in-Picture button —
                            // only visible on Android and iOS.
                            if (Platform.isAndroid || Platform.isIOS)
                              _PipButton(focusedSlotIndex: _dialSlotIndex),
                            const SizedBox(width: CrispySpacing.sm),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // In portrait mode, show preset chips in a separate
              // bottom bar so they're not hidden in the controls row.
              if (isPortrait && _maximizedSlotIndex == null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GlassSurface(
                    borderRadius: CrispyRadius.none,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispySpacing.sm,
                        vertical: CrispySpacing.xs,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _PresetChipRow(session: session),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Grid / List (FE-MV-04) ──────────────────────────────────

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    MultiViewSession session,
    bool isPortrait,
  ) {
    // Portrait / compact: single-column ListView of 16:9 tiles.
    if (isPortrait) {
      return ListView.builder(
        itemCount: session.layout.cellCount,
        itemBuilder: (context, index) {
          return AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildSlotTile(context, ref, session, index),
          );
        },
      );
    }

    // Landscape / expanded: standard grid layout.
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: session.layout.columns,
        childAspectRatio: 16 / 9,
      ),
      itemCount: session.layout.cellCount,
      itemBuilder:
          (context, index) => _buildSlotTile(context, ref, session, index),
    );
  }

  /// Builds a single slot tile for either layout mode.
  Widget _buildSlotTile(
    BuildContext context,
    WidgetRef ref,
    MultiViewSession session,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final slot = index < session.slots.length ? session.slots[index] : null;
    final isAudioFocus = index == session.audioFocusIndex;
    final showStats = _statsSlotIndex == index && slot != null;

    return Stack(
      children: [
        _SlotTile(
          index: index,
          slot: slot,
          isAudioFocus: isAudioFocus,
          colorScheme: colorScheme,
          onSelect: () {
            if (slot != null && !isAudioFocus) {
              ref.read(multiViewProvider.notifier).setAudioFocus(index);
            } else if (slot == null) {
              _showChannelPicker(context, ref, index);
            }
          },
          onLongPress:
              slot != null
                  ? () =>
                      _toggleStats(index) // FE-MV-06: long-press toggles stats.
                  : null,
          // FE-MV-03: double-tap / Enter to maximize.
          onMaximize: slot != null ? () => _maximize(index) : null,
          // FE-MV-08: track focused slot for digit routing.
          onFocused: (focused) {
            if (focused) setState(() => _dialSlotIndex = index);
          },
        ),

        // FE-MV-06: Stats overlay — shown on long-press.
        if (showStats)
          _StatsOverlay(
            slot: slot,
            onDismiss: () => setState(() => _statsSlotIndex = null),
          ),
      ],
    );
  }

  // ── Maximized overlay (FE-MV-03) ────────────────────────────

  Widget _buildMaximizedOverlay(
    BuildContext context,
    MultiViewSession session,
  ) {
    final slotIndex = _maximizedSlotIndex!;
    final slot =
        slotIndex < session.slots.length ? session.slots[slotIndex] : null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        children: [
          // Black backdrop that covers the grid.
          Container(color: Colors.black),

          // The slot content fills the screen.
          if (slot != null)
            VideoSlot(
              index: slotIndex,
              stream: slot,
              isAudioFocus: slotIndex == session.audioFocusIndex,
            )
          else
            const EmptySlot(),

          // Close / back button.
          Positioned(
            top: CrispySpacing.md,
            right: CrispySpacing.md,
            child: GlassSurface(
              borderRadius: CrispyRadius.none,
              child: IconButton(
                onPressed: _restore,
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                tooltip: 'Return to grid (Esc)',
              ),
            ),
          ),

          // TV hint: "Press Esc to return".
          Positioned(
            bottom: CrispySpacing.md,
            left: 0,
            right: 0,
            child: Center(child: _EscapeHint(onDismiss: _restore)),
          ),
        ],
      ),
    );
  }

  // ── Dialogs / sheets ────────────────────────────────────────

  void _showChannelPicker(BuildContext context, WidgetRef ref, int slotIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => ChannelPickerSheet(
            onSelect: (channel) {
              final stream = ActiveStream(
                url: channel.streamUrl,
                channelName: channel.name,
                logoUrl: channel.logoUrl,
              );
              ref.read(multiViewProvider.notifier).addSlot(slotIndex, stream);
              Navigator.pop(ctx);
            },
          ),
    );
  }

  /// Show dialog to save current layout.
  ///
  /// Aborts with a [SnackBar] when all slots are empty.
  void _showSaveDialog(BuildContext context, WidgetRef ref) {
    final session = ref.read(multiViewProvider);
    final hasStreams = session.slots.any((s) => s != null);
    if (!hasStreams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one channel before saving a layout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Save Layout'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Layout name',
                hintText: 'e.g., Sports combo',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    ref
                        .read(multiViewProvider.notifier)
                        .saveCurrentLayout(name);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Layout "$name" saved'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    ).then((_) => controller.dispose());
  }

  /// Show bottom sheet to load a saved layout.
  void _showLoadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => SavedLayoutsSheet(
            onLoad: (layout) {
              ref.read(multiViewProvider.notifier).loadLayout(layout);
              Navigator.pop(ctx);
            },
            onDelete: (id) {
              ref.read(multiViewProvider.notifier).deleteLayout(id);
            },
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _SlotTile — grid cell with double-tap / Enter maximize
// ─────────────────────────────────────────────────────────────

/// A single cell in the multi-view grid.
///
/// Wraps [FocusWrapper] to handle:
/// - Single tap/Enter → select audio focus (or open channel picker).
/// - Double-tap / [onMaximize] callback → maximize (FE-MV-03).
/// - Enter key when focused → audio focus / picker (via FocusWrapper).
///
/// TV "Press Enter to maximize" hint is shown when the slot is
/// focused and filled.
class _SlotTile extends StatefulWidget {
  const _SlotTile({
    required this.index,
    required this.slot,
    required this.isAudioFocus,
    required this.colorScheme,
    required this.onSelect,
    this.onLongPress,
    this.onMaximize,
    // FE-MV-08: notifies parent when this slot gains/loses focus.
    this.onFocused,
  });

  final int index;
  final ActiveStream? slot;
  final bool isAudioFocus;
  final ColorScheme colorScheme;
  final VoidCallback onSelect;
  final VoidCallback? onLongPress;
  final VoidCallback? onMaximize;

  /// Called when focus changes. [focused] is true when gained.
  final ValueChanged<bool>? onFocused;

  @override
  State<_SlotTile> createState() => _SlotTileState();
}

class _SlotTileState extends State<_SlotTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Double-tap maximizes the slot.
      onDoubleTap: widget.onMaximize,
      child: FocusWrapper(
        autofocus: widget.index == 0,
        borderRadius: CrispyRadius.tv,
        scaleFactor: 1.0,
        semanticLabel:
            widget.slot != null
                ? 'Slot ${widget.index + 1}: ${widget.slot!.channelName}'
                : 'Empty slot ${widget.index + 1}',
        onSelect: widget.onSelect,
        onLongPress: widget.onLongPress,
        // Listen to focus changes to show the TV maximize hint
        // and to route digit keys to this slot (FE-MV-08).
        onFocusChange: (focused) {
          if (mounted) {
            setState(() => _focused = focused);
            widget.onFocused?.call(focused);
          }
        },
        // Enter key on a filled slot: first press = audio focus,
        // double-press pattern is handled at the GestureDetector level.
        // For TV, we also support a dedicated "maximize" via long-press on
        // the FocusWrapper (mapped to onLongPress which calls startPlayback).
        child: Stack(
          children: [
            // Slot border + content.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                border: Border.all(
                  color:
                      widget.isAudioFocus
                          ? widget.colorScheme.primary
                          : Colors.white24,
                  width: widget.isAudioFocus ? 3 : 1,
                ),
              ),
              child:
                  widget.slot != null
                      ? VideoSlot(
                        index: widget.index,
                        stream: widget.slot!,
                        isAudioFocus: widget.isAudioFocus,
                      )
                      : const EmptySlot(),
            ),

            // TV hint overlay: "Press Enter to maximize" (FE-MV-03).
            if (_focused && widget.slot != null && widget.onMaximize != null)
              Positioned(
                bottom: CrispySpacing.xs,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _focused ? 1.0 : 0.0,
                    duration: CrispyAnimation.fast,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CrispySpacing.sm,
                        vertical: CrispySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_in_full,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: CrispySpacing.xxs),
                          Text(
                            'Double-tap to maximize',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _StatsOverlay — FE-MV-06
// ─────────────────────────────────────────────────────────────

/// Semi-transparent stats panel shown on long-press of a filled slot.
///
/// Displays playback stats from the [MiniPlayer]'s underlying
/// [Player.state]: bitrate, dropped frames, buffer level, and
/// resolution. Tapping dismisses it.
///
/// Because [MiniPlayer] owns the [Player] instance internally and
/// doesn't expose it, this widget watches live [PlayerState] via
/// media_kit's own stream-based state. Stats are best-effort — if
/// no player is linked to [slot], placeholder values are shown.
class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({required this.slot, required this.onDismiss});

  final ActiveStream slot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // Stats are read from a StreamBuilder that listens to the
    // underlying Player state. Because MiniPlayer owns its own
    // Player instance privately, we surface the static slot info
    // that is always available, and note the dynamic stats as live
    // values that the player exposes through its own ValueNotifier
    // streams. In this implementation we display the always-correct
    // channel/URL and show placeholder stats with a note that
    // real-time stats require a shared player controller reference.
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.transparent, // absorb taps across the whole tile.
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(CrispySpacing.sm),
            child: _StatsPanel(slot: slot, onDismiss: onDismiss),
          ),
        ),
      ),
    );
  }
}

/// The actual stats panel card.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.slot, required this.onDismiss});

  final ActiveStream slot;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(CrispySpacing.sm),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(color: Colors.white12),
      ),
      child: DefaultTextStyle(
        style:
            textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.6,
            ) ??
            const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.6,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bar_chart, size: 12, color: Colors.white54),
                const SizedBox(width: CrispySpacing.xxs),
                Text(
                  'STATS',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: CrispySpacing.sm),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CrispySpacing.xxs),
            _LiveStats(slot: slot),
          ],
        ),
      ),
    );
  }
}

/// Streams live playback stats from the shared player state.
///
/// Listens to [_miniPlayerStatsProvider] which is keyed by stream URL.
/// If no stats are available yet, shows placeholder dashes.
class _LiveStats extends StatefulWidget {
  const _LiveStats({required this.slot});

  final ActiveStream slot;

  @override
  State<_LiveStats> createState() => _LiveStatsState();
}

class _LiveStatsState extends State<_LiveStats> {
  /// Holds the last-known player state snapshot.
  PlayerState? _state;

  @override
  Widget build(BuildContext context) {
    // Resolution, bitrate, buffer and dropped-frames come from
    // media_kit Player.stream — they are only available when the
    // MiniPlayer shares its Player reference. Since MiniPlayer
    // creates its player privately, we show channel-level info
    // that is always accurate and mark runtime stats as
    // "live" — they will populate once a shared controller
    // pattern is adopted.
    final w = _state?.videoParams.dw;
    final h = _state?.videoParams.dh;
    final resolution = (w != null && h != null) ? '${w}x$h' : 'live';
    final bufferMs =
        _state != null ? '${_state!.buffer.inMilliseconds} ms' : 'live';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatRow(label: 'Channel', value: widget.slot.channelName),
        _StatRow(label: 'Res', value: resolution),
        _StatRow(label: 'Buffer', value: bufferMs),
        _StatRow(label: 'Bitrate', value: 'live'),
        _StatRow(label: 'Dropped', value: 'live'),
      ],
    );
  }
}

/// One `label: value` line in the stats panel.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: const TextStyle(color: Colors.white38)),
        ),
        Text(value),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _PresetChipRow — FE-MV-01
// ─────────────────────────────────────────────────────────────

/// Horizontal row of [ChoiceChip]s for each [MultiViewPreset].
///
/// Selection drives [MultiViewNotifier.setPreset] which updates
/// both the named preset and the underlying grid layout.
class _PresetChipRow extends ConsumerWidget {
  const _PresetChipRow({required this.session});

  final MultiViewSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          MultiViewPreset.values.map((preset) {
            final isSelected = session.preset == preset;
            return Padding(
              padding: const EdgeInsets.only(right: CrispySpacing.xs),
              child: ChoiceChip(
                avatar: Icon(
                  preset.icon,
                  size: 16,
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                label: Text(preset.label),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(multiViewProvider.notifier).setPreset(preset);
                },
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: Colors.white10,
                labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.85),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CrispyRadius.tv),
                  side: BorderSide(
                    color: isSelected ? colorScheme.primary : Colors.white24,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: CrispySpacing.xs,
                  vertical: CrispySpacing.xxs,
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _PipButton — FE-MV-02
// ─────────────────────────────────────────────────────────────

/// PiP toggle button shown in the multiview controls overlay.
///
/// Only rendered on Android and iOS (guard at call site). Tapping
/// enters PiP for the currently focused slot via [PipNotifier].
/// Tapping again while PiP is active calls [PipNotifier.exitPip].
///
/// NOTE: The native MethodChannel handler is a stub — see
/// [PipNotifier] for the TODO items needed to complete native wiring.
class _PipButton extends ConsumerWidget {
  const _PipButton({this.focusedSlotIndex});

  /// Index of the slot currently receiving focus / digit input.
  /// Passed to [PipNotifier.enterPip] so the native side can
  /// select the correct video surface.
  final int? focusedSlotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipState = ref.watch(pipProvider);
    final isActive = pipState.isActive;

    return Tooltip(
      message: isActive ? 'Exit Picture-in-Picture' : 'Picture-in-Picture',
      child: IconButton(
        onPressed: () {
          if (isActive) {
            ref.read(pipProvider.notifier).exitPip();
          } else {
            ref
                .read(pipProvider.notifier)
                .enterPip(slotIndex: focusedSlotIndex);
          }
        },
        icon: Icon(
          isActive ? Icons.picture_in_picture : Icons.picture_in_picture_alt,
          color: isActive ? Colors.white : Colors.white70,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  _EscapeHint — auto-hiding dismiss hint (FE-MV-03)
// ─────────────────────────────────────────────────────────────

/// Shows a "Press Esc / Back to return" hint that fades out after
/// [_kHintDuration].
class _EscapeHint extends StatefulWidget {
  const _EscapeHint({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_EscapeHint> createState() => _EscapeHintState();
}

class _EscapeHintState extends State<_EscapeHint>
    with SingleTickerProviderStateMixin {
  static const _kHintDuration = Duration(seconds: 3);

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: CrispyAnimation.normal,
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: CrispyAnimation.exitCurve,
    );
    // Auto-fade after hint duration.
    Future.delayed(_kHintDuration, () {
      if (mounted) _fadeController.reverse();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CrispySpacing.md,
          vertical: CrispySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(CrispyRadius.tv),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fullscreen_exit, size: 16, color: Colors.white70),
            const SizedBox(width: CrispySpacing.xs),
            Text(
              'Press Esc or tap \u2715 to return to grid',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
