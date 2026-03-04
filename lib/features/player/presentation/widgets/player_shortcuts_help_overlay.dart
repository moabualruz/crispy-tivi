import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/crispy_radius.dart';
import '../../../../core/theme/crispy_spacing.dart';

/// Two-column keyboard shortcuts reference overlay.
///
/// Displayed when the user presses `?` in fullscreen.
/// Dismissable with Escape or `?` again.
///
/// Glassmorphism style: semi-transparent dark panel
/// with a subtle border, blur backdrop.
class PlayerShortcutsHelpOverlay extends StatelessWidget {
  const PlayerShortcutsHelpOverlay({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.slash) {
          onDismiss();
        }
      },
      child: GestureDetector(
        onTap: onDismiss,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: GestureDetector(
              // Prevent taps inside the panel from dismissing.
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CrispyRadius.tv),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    margin: const EdgeInsets.all(CrispySpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(CrispyRadius.tv),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(CrispySpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(
                                Icons.keyboard_outlined,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: CrispySpacing.sm),
                              Text(
                                'Keyboard Shortcuts',
                                style: textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: onDismiss,
                                tooltip: 'Close (Esc)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: CrispySpacing.md),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.12),
                            height: 1,
                          ),
                          const SizedBox(height: CrispySpacing.md),

                          // Two-column shortcut table
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ShortcutColumn(
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                  sections: const [
                                    _ShortcutSection(
                                      title: 'Playback',
                                      entries: [
                                        _ShortcutEntry(
                                          'Space / K',
                                          'Play / Pause',
                                        ),
                                        _ShortcutEntry('← / →', 'Seek ±10 s'),
                                        _ShortcutEntry(
                                          '< / >',
                                          'Speed −/+ step',
                                        ),
                                        _ShortcutEntry(
                                          '[ / ]',
                                          'Speed −/+ 0.1x',
                                        ),
                                        _ShortcutEntry(
                                          '0–9',
                                          'Jump to % (VOD)',
                                        ),
                                        _ShortcutEntry(
                                          ', / .',
                                          'Frame step ±1',
                                        ),
                                        _ShortcutEntry(
                                          'A',
                                          'Cycle aspect ratio',
                                        ),
                                        _ShortcutEntry('V', 'Cycle subtitles'),
                                      ],
                                    ),
                                    _ShortcutSection(
                                      title: 'Volume',
                                      entries: [
                                        _ShortcutEntry('↑ / ↓', 'Volume ±10 %'),
                                        _ShortcutEntry('M', 'Mute / unmute'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: CrispySpacing.lg),
                              Expanded(
                                child: _ShortcutColumn(
                                  colorScheme: colorScheme,
                                  textTheme: textTheme,
                                  sections: const [
                                    _ShortcutSection(
                                      title: 'Display',
                                      entries: [
                                        _ShortcutEntry(
                                          'F',
                                          'Fullscreen toggle',
                                        ),
                                        _ShortcutEntry(
                                          'Esc',
                                          'Exit fullscreen / back',
                                        ),
                                        _ShortcutEntry('I', 'Stream info'),
                                        _ShortcutEntry('A', 'Aspect ratio'),
                                      ],
                                    ),
                                    _ShortcutSection(
                                      title: 'Live TV',
                                      entries: [
                                        _ShortcutEntry('Page Up', 'Channel up'),
                                        _ShortcutEntry(
                                          'Page Down',
                                          'Channel down',
                                        ),
                                        _ShortcutEntry('C', 'Channel list'),
                                        _ShortcutEntry(
                                          'C (hold)',
                                          'Toggle zap overlay',
                                        ),
                                      ],
                                    ),
                                    _ShortcutSection(
                                      title: 'General',
                                      entries: [
                                        _ShortcutEntry(
                                          'C / CC',
                                          'Subtitles / CC',
                                        ),
                                        _ShortcutEntry('V', 'Cycle subtitles'),
                                        _ShortcutEntry('L', 'Screen lock'),
                                        _ShortcutEntry('?', 'This help screen'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: CrispySpacing.md),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.08),
                            height: 1,
                          ),
                          const SizedBox(height: CrispySpacing.sm),
                          Text(
                            'Press Esc or ? to close',
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One column of grouped shortcut sections.
class _ShortcutColumn extends StatelessWidget {
  const _ShortcutColumn({
    required this.sections,
    required this.colorScheme,
    required this.textTheme,
  });

  final List<_ShortcutSection> sections;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: CrispySpacing.md),
          _buildSection(sections[i]),
        ],
      ],
    );
  }

  Widget _buildSection(_ShortcutSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: CrispySpacing.xs),
        for (final entry in section.entries) _buildEntry(entry),
      ],
    );
  }

  Widget _buildEntry(_ShortcutEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _KeyChip(label: entry.key),
          const SizedBox(width: CrispySpacing.sm),
          Expanded(
            child: Text(
              entry.action,
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "key" pill chip.
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CrispySpacing.xs,
        vertical: CrispySpacing.xxs,
      ),
      constraints: const BoxConstraints(minWidth: 52),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CrispyRadius.tv),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          height: 1.3,
        ),
      ),
    );
  }
}

/// Immutable data class for a section of shortcuts.
class _ShortcutSection {
  const _ShortcutSection({required this.title, required this.entries});

  final String title;
  final List<_ShortcutEntry> entries;
}

/// Immutable data class for a single shortcut entry.
class _ShortcutEntry {
  const _ShortcutEntry(this.key, this.action);

  final String key;
  final String action;
}
