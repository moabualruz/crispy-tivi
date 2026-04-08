/// Multi-view screen — displays up to 9 video streams in a grid.
///
/// Per `the project UI/UX specification §3.6`:
/// - Named preset layout chips (FE-MV-01)
/// - Audio focus switching (tap to select main audio)
/// - One-click slot maximize via double-tap / Enter (FE-MV-03)
/// - Portrait / compact single-column layout (FE-MV-04)
/// - EPG mini-guide overlay (FE-MV-05)
/// - Per-slot stats overlay via long-press (FE-MV-06)
/// - Immersive mode
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/testing/test_keys.dart';
import '../../../../core/utils/platform_info.dart';
import '../../../../core/widgets/screen_template.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../iptv/presentation/providers/channel_providers.dart';
import '../../../iptv/presentation/widgets/channel_number_jump_overlay.dart';
import '../../domain/entities/active_stream.dart';
import '../../domain/entities/multiview_session.dart';
import '../providers/multiview_providers.dart';
import '../widgets/channel_picker_sheet.dart';
import '../widgets/empty_slot.dart';
import '../widgets/multiview_controls.dart';
import '../widgets/multiview_epg_sheet.dart';
import '../widgets/multiview_slot_tile.dart';
import '../widgets/multiview_stats_overlay.dart';
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

  /// Focus node for the root [KeyboardListener].
  late final FocusNode _focusNode;

  static const _kMvDialTimeout = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    // Enter immersive mode (hide system bars) like the player does.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    // Restore system UI bars on exit.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _focusNode.dispose();
    _scaleController.dispose();
    _dialTimer?.cancel();
    super.dispose();
  }

  /// Restore keyboard focus to the root node after interactions
  /// that may steal it (toolbar buttons, dialogs, etc.).
  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasPrimaryFocus) {
        _focusNode.requestFocus();
      }
    });
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
      focusNode: _focusNode,
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
        body: ScreenTemplate(
          focusRestorationKey: 'multiview',
          compactBody: _buildContent(context, ref, session, isPortrait),
          largeBody: _buildContent(context, ref, session, isPortrait),
        ),
      ),
    );
  }

  // ── Content (shared between compact and large) ──────────────

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MultiViewSession session,
    bool isPortrait,
  ) {
    return FocusTraversalGroup(
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
                        if (!isPortrait)
                          MultiviewPresetChipRow(session: session),
                        if (!isPortrait)
                          const VerticalDivider(
                            width: CrispySpacing.lg,
                            color: Colors.white24,
                          ),
                        // FE-MV-05: EPG mini-guide button.
                        IconButton(
                          onPressed:
                              () =>
                                  showMultiViewEpgSheet(context, session.slots),
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
                        if (PlatformInfo.instance.isAndroid ||
                            PlatformInfo.instance.isIOS)
                          MultiviewPipButton(focusedSlotIndex: _dialSlotIndex),
                        const SizedBox(width: CrispySpacing.sm),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
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
                    child: MultiviewPresetChipRow(session: session),
                  ),
                ),
              ),
            ),
        ],
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
        MultiviewSlotTile(
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
          MultiviewStatsOverlay(
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
            child: Center(child: MultiviewEscapeHint(onDismiss: _restore)),
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
    ).then((_) => _restoreFocus());
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
    ).then((_) {
      controller.dispose();
      _restoreFocus();
    });
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
    ).then((_) => _restoreFocus());
  }
}
