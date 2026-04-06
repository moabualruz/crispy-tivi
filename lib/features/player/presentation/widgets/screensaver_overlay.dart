import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/settings_notifier.dart';
import '../../../../core/theme/crispy_animation.dart';
import '../providers/player_providers.dart';

// ─────────────────────────────────────────────────────────────
//  Screensaver Mode Enum
// ─────────────────────────────────────────────────────────────

/// Screensaver display modes.
enum ScreensaverMode {
  /// DVD-style bouncing logo — OLED-safe.
  bouncingLogo,

  /// Large clock display, shifts position periodically.
  clock,

  /// Pure black screen — maximum OLED power saving.
  blackScreen;

  /// Human-readable label for settings UI.
  String get label => switch (this) {
    ScreensaverMode.bouncingLogo => 'Bouncing Logo',
    ScreensaverMode.clock => 'Clock',
    ScreensaverMode.blackScreen => 'Black Screen',
  };
}

/// Screensaver idle timeout presets (in minutes).
/// 0 means disabled (never activate).
const kScreensaverTimeoutOptions = [0, 2, 5, 10, 30];

/// Key for persisting screensaver mode.
const kScreensaverModeKey = 'crispy_screensaver_mode';

/// Key for persisting screensaver timeout in minutes.
const kScreensaverTimeoutKey = 'crispy_screensaver_timeout';

// ─────────────────────────────────────────────────────────────
//  Screensaver Controller (idle timer + overlay)
// ─────────────────────────────────────────────────────────────

/// Manages the screensaver idle timer and overlay display.
///
/// Wraps a child widget and shows a screensaver overlay after
/// the configured idle timeout. Any user input (touch, key,
/// mouse) dismisses the screensaver and resets the timer.
class ScreensaverController extends ConsumerStatefulWidget {
  const ScreensaverController({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ScreensaverController> createState() =>
      _ScreensaverControllerState();
}

class _ScreensaverControllerState extends ConsumerState<ScreensaverController> {
  Timer? _idleTimer;
  bool _active = false;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    if (!mounted) return;
    if (_active) {
      setState(() => _active = false);
    }
    _idleTimer?.cancel();
    final timeout = ref.read(screensaverTimeoutProvider);
    if (timeout <= 0) return;
    _idleTimer = Timer(Duration(minutes: timeout), _activate);
  }

  void _activate() {
    if (!mounted) return;
    setState(() => _active = true);
  }

  void _onInput() {
    _resetTimer();
  }

  @override
  Widget build(BuildContext context) {
    final timeout = ref.watch(screensaverTimeoutProvider);
    final mode = ref.watch(screensaverModeProvider);

    // Reset timer when timeout setting changes.
    ref.listen(screensaverTimeoutProvider, (prev, next) => _resetTimer());

    // Reset timer on OSD toggle (user interaction).
    ref.listen(osdStateProvider, (prev, next) => _resetTimer());

    // Disabled — no screensaver.
    if (timeout <= 0) {
      return widget.child;
    }

    // Start the idle timer on first build if not running.
    if (_idleTimer == null || !_idleTimer!.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetTimer());
    }

    return Listener(
      onPointerDown: (_) => _onInput(),
      onPointerMove: (_) => _onInput(),
      behavior: HitTestBehavior.translucent,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (_) => _onInput(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_active)
              GestureDetector(
                onTap: _onInput,
                child: AnimatedOpacity(
                  opacity: _active ? 1.0 : 0.0,
                  duration: CrispyAnimation.normal,
                  child: _ScreensaverContent(mode: mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Screensaver Content (mode switcher)
// ─────────────────────────────────────────────────────────────

class _ScreensaverContent extends StatelessWidget {
  const _ScreensaverContent({required this.mode});

  final ScreensaverMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      ScreensaverMode.bouncingLogo => const _BouncingLogo(),
      ScreensaverMode.clock => const _ClockDisplay(),
      ScreensaverMode.blackScreen => const ColoredBox(color: Colors.black),
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  Bouncing Logo (DVD-style)
// ─────────────────────────────────────────────────────────────

class _BouncingLogo extends StatefulWidget {
  const _BouncingLogo();

  @override
  State<_BouncingLogo> createState() => _BouncingLogoState();
}

class _BouncingLogoState extends State<_BouncingLogo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _random = Random();

  static const _logoSize = 80.0;
  static const _speed = 1.5; // pixels per frame at 60fps

  double _x = 50;
  double _y = 50;
  double _dx = 1;
  double _dy = 1;
  Color _tint = Colors.white;

  @override
  void initState() {
    super.initState();
    _dx = _speed * (_random.nextBool() ? 1 : -1);
    _dy = _speed * (_random.nextBool() ? 1 : -1);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    final maxX = size.width - _logoSize;
    final maxY = size.height - _logoSize;
    if (maxX <= 0 || maxY <= 0) return;

    var newX = _x + _dx;
    var newY = _y + _dy;
    var bounced = false;

    if (newX <= 0 || newX >= maxX) {
      _dx = -_dx;
      newX = newX.clamp(0, maxX);
      bounced = true;
    }
    if (newY <= 0 || newY >= maxY) {
      _dy = -_dy;
      newY = newY.clamp(0, maxY);
      bounced = true;
    }

    if (bounced) {
      _tint = _randomColor();
    }

    setState(() {
      _x = newX;
      _y = newY;
    });
  }

  Color _randomColor() {
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.amber,
      Colors.purple,
      Colors.cyan,
      Colors.orange,
      Colors.pink,
      Colors.teal,
      Colors.white,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned(
            left: _x,
            top: _y,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                _tint.withValues(alpha: 0.8),
                BlendMode.modulate,
              ),
              child: Image.asset(
                'assets/logo.png',
                width: _logoSize,
                height: _logoSize,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Clock Display
// ─────────────────────────────────────────────────────────────

class _ClockDisplay extends StatefulWidget {
  const _ClockDisplay();

  @override
  State<_ClockDisplay> createState() => _ClockDisplayState();
}

class _ClockDisplayState extends State<_ClockDisplay> {
  late Timer _timer;
  final _random = Random();
  var _alignment = Alignment.center;

  @override
  void initState() {
    super.initState();
    _shiftPosition();
    // Update every second for time display, shift position every 60s.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (DateTime.now().second == 0) {
        _shiftPosition();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _shiftPosition() {
    const alignments = [
      Alignment.topLeft,
      Alignment.topCenter,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.center,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomCenter,
      Alignment.bottomRight,
    ];
    _alignment = alignments[_random.nextInt(alignments.length)];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final is24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final timeStr = _formatTime(now, is24h);

    return ColoredBox(
      color: Colors.black,
      child: AnimatedAlign(
        alignment: _alignment,
        duration: CrispyAnimation.slow,
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            timeStr,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 72,
              fontWeight: FontWeight.w200,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t, bool is24h) {
    if (is24h) {
      return '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    }
    final h =
        t.hour == 0
            ? 12
            : t.hour > 12
            ? t.hour - 12
            : t.hour;
    final amPm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $amPm';
  }
}

// ─────────────────────────────────────────────────────────────
//  Providers
// ─────────────────────────────────────────────────────────────

/// Screensaver mode setting provider.
///
/// Reads from [SettingsState] (persisted). Default: bouncingLogo.
final screensaverModeProvider = Provider<ScreensaverMode>((ref) {
  return ref.watch(
    settingsNotifierProvider.select(
      (s) => s.value?.screensaverMode ?? ScreensaverMode.bouncingLogo,
    ),
  );
});

/// Screensaver timeout in minutes. 0 = disabled.
final screensaverTimeoutProvider = Provider<int>((ref) {
  return ref.watch(
    settingsNotifierProvider.select((s) => s.value?.screensaverTimeout ?? 0),
  );
});
