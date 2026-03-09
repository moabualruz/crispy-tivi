import 'package:crispy_tivi/l10n/l10n_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';

import '../../../../../core/testing/test_keys.dart';
import 'osd_shared.dart';

/// Overflow menu for less-used OSD controls.
///
/// Contains items moved from top/bottom bars per the
/// redesign: favorite, aspect ratio, sleep
/// timer, PiP, external player, stream info, refresh,
/// search, channels, recordings, audio track, copy URL,
/// deinterlace.
class OsdOverflowMenu extends StatelessWidget {
  const OsdOverflowMenu({
    required this.onAudioTrack,
    required this.onAspectRatio,
    required this.onRefresh,
    required this.onStreamInfo,
    required this.aspectRatioLabel,
    required this.isLive,
    required this.isFavorite,
    this.onEnterPip,
    this.onSleepTimer,
    this.onCopyUrl,
    this.onOpenExternal,
    this.onSearch,
    this.onChannelList,
    this.onRecordings,
    this.onFavorite,
    this.onScreenshot,
    this.onQuality,
    this.streamProfileLabel,
    this.onDeinterlace,
    this.deinterlaceMode,
    this.onRotationLock,
    this.onSyncOffset,
    this.onAudioPassthrough,
    this.audioPassthroughEnabled = false,
    this.onAudioDevice,
    this.onAlwaysOnTop,
    this.isAlwaysOnTop = false,
    this.onBrightness,
    this.onShaderPreset,
    this.shaderPresetLabel,
    super.key,
  });

  final VoidCallback onAudioTrack;
  final VoidCallback onAspectRatio;
  final VoidCallback onRefresh;
  final VoidCallback onStreamInfo;
  final String aspectRatioLabel;
  final bool isLive;
  final bool isFavorite;
  final VoidCallback? onEnterPip;
  final VoidCallback? onSleepTimer;
  final VoidCallback? onCopyUrl;
  final VoidCallback? onOpenExternal;
  final VoidCallback? onSearch;
  final VoidCallback? onChannelList;
  final VoidCallback? onRecordings;
  final VoidCallback? onFavorite;

  /// Callback to capture a screenshot of the player.
  final VoidCallback? onScreenshot;

  /// Callback to open the quality/bitrate picker.
  final VoidCallback? onQuality;

  /// Current stream profile label (e.g. "Auto", "High").
  final String? streamProfileLabel;

  /// Callback to cycle deinterlace mode. Hidden on web.
  final VoidCallback? onDeinterlace;

  /// Current deinterlace mode label (e.g. "Auto", "Off", "On").
  final String? deinterlaceMode;

  /// Callback to open rotation lock dialog. Mobile only.
  final VoidCallback? onRotationLock;

  /// Callback to open sync offset dialog. Hidden on web.
  final VoidCallback? onSyncOffset;

  /// Callback to toggle audio passthrough. Desktop only.
  final VoidCallback? onAudioPassthrough;

  /// Whether audio passthrough is currently enabled.
  final bool audioPassthroughEnabled;

  /// Callback to open audio device picker. Desktop only.
  final VoidCallback? onAudioDevice;

  /// Callback to toggle always-on-top. Desktop (Win/Linux) only.
  final VoidCallback? onAlwaysOnTop;

  /// Whether always-on-top is currently enabled.
  final bool isAlwaysOnTop;

  /// Callback to open brightness dialog. Mobile only.
  final VoidCallback? onBrightness;

  /// Callback to open shader preset picker. Desktop only.
  final VoidCallback? onShaderPreset;

  /// Current shader preset label (e.g. "Off", "NVScaler").
  final String? shaderPresetLabel;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
      tooltip: context.l10n.playerMoreOptions,
      color: osdPanelColor,
      shape: const RoundedRectangleBorder(),
      offset: const Offset(0, -200),
      onSelected: (value) {
        switch (value) {
          case 'favorite':
            onFavorite?.call();
          case 'audio':
            onAudioTrack();
          case 'aspect':
            onAspectRatio();
          case 'refresh':
            onRefresh();
          case 'info':
            onStreamInfo();
          case 'pip':
            onEnterPip?.call();
          case 'sleep':
            onSleepTimer?.call();
          case 'copyUrl':
            onCopyUrl?.call();
          case 'external':
            onOpenExternal?.call();
          case 'search':
            onSearch?.call();
          case 'channels':
            onChannelList?.call();
          case 'recordings':
            onRecordings?.call();
          case 'screenshot':
            onScreenshot?.call();
          case 'quality':
            onQuality?.call();
          case 'deinterlace':
            onDeinterlace?.call();
          case 'rotationLock':
            onRotationLock?.call();
          case 'syncOffset':
            onSyncOffset?.call();
          case 'audioPassthrough':
            onAudioPassthrough?.call();
          case 'audioDevice':
            onAudioDevice?.call();
          case 'alwaysOnTop':
            onAlwaysOnTop?.call();
          case 'brightness':
            onBrightness?.call();
          case 'shaders':
            onShaderPreset?.call();
        }
      },
      itemBuilder:
          (context) => [
            // Favorite (moved from bottom bar)
            if (onFavorite != null)
              _menuItem(
                'favorite',
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                isFavorite
                    ? context.l10n.playerRemoveFavorite
                    : context.l10n.playerAddFavorite,
                iconColor: isFavorite ? Colors.red : null,
              ),
            _menuItem('audio', Icons.audiotrack, context.l10n.playerAudioTrack),
            _menuItem(
              'aspect',
              aspectRatioIcon(aspectRatioLabel),
              context.l10n.playerAspectRatio(aspectRatioLabel),
            ),
            _menuItem(
              'refresh',
              Icons.refresh_rounded,
              context.l10n.playerRefreshStream,
            ),
            _menuItem(
              'info',
              Icons.info_outline_rounded,
              context.l10n.playerStreamInfo,
            ),
            if (onEnterPip != null)
              _menuItem(
                'pip',
                Icons.picture_in_picture_alt_rounded,
                context.l10n.playerPip,
              ),
            if (onSleepTimer != null)
              _menuItem(
                'sleep',
                Icons.timer_outlined,
                context.l10n.playerSleepTimer,
              ),
            if (onCopyUrl != null)
              _menuItem('copyUrl', Icons.copy, 'Copy Stream URL'),
            if (onOpenExternal != null)
              _menuItem(
                'external',
                Icons.open_in_new,
                context.l10n.playerExternalPlayer,
              ),
            if (isLive && onSearch != null)
              _menuItem(
                'search',
                Icons.search,
                context.l10n.playerSearchChannels,
              ),
            if (isLive && onChannelList != null)
              _menuItem(
                'channels',
                Icons.live_tv,
                context.l10n.playerChannelList,
              ),
            if (isLive && onRecordings != null)
              _menuItem(
                'recordings',
                Icons.fiber_manual_record,
                context.l10n.playerRecordings,
              ),
            if (onScreenshot != null)
              _menuItem(
                'screenshot',
                Icons.photo_camera_outlined,
                context.l10n.playerScreenshot,
              ),
            if (onQuality != null)
              _menuItem(
                'quality',
                Icons.high_quality_rounded,
                context.l10n.playerStreamQualityOption(
                  streamProfileLabel ?? context.l10n.commonAuto,
                ),
              ),
            if (!kIsWeb && onDeinterlace != null)
              _menuItem(
                'deinterlace',
                Icons.deblur_rounded,
                context.l10n.playerDeinterlace(
                  deinterlaceMode ?? context.l10n.commonOff,
                ),
              ),
            if (!kIsWeb && onSyncOffset != null)
              _menuItem(
                'syncOffset',
                Icons.sync_rounded,
                context.l10n.playerSyncOffset,
              ),
            // Audio passthrough (desktop only)
            if (_isDesktop && onAudioPassthrough != null)
              _menuItem(
                'audioPassthrough',
                Icons.surround_sound_rounded,
                context.l10n.playerAudioPassthrough(
                  audioPassthroughEnabled
                      ? context.l10n.commonOn
                      : context.l10n.commonOff,
                ),
                iconColor: audioPassthroughEnabled ? Colors.amber : null,
              ),
            // Audio device picker (desktop only)
            if (_isDesktop && onAudioDevice != null)
              _menuItem(
                'audioDevice',
                Icons.speaker_rounded,
                context.l10n.playerAudioOutputDevice,
              ),
            if (!kIsWeb &&
                onRotationLock != null &&
                (Platform.isAndroid || Platform.isIOS))
              _menuItem(
                'rotationLock',
                Icons.screen_rotation_rounded,
                context.l10n.playerRotationLock,
              ),
            // Always-on-top (Windows + Linux only, not macOS)
            if (!kIsWeb &&
                onAlwaysOnTop != null &&
                (Platform.isWindows || Platform.isLinux))
              _menuItem(
                'alwaysOnTop',
                isAlwaysOnTop
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                context.l10n.playerAlwaysOnTop(
                  isAlwaysOnTop
                      ? context.l10n.commonOn
                      : context.l10n.commonOff,
                ),
                iconColor: isAlwaysOnTop ? Colors.amber : null,
              ),
            // Shader/upscale presets (desktop only)
            if (_isDesktop && onShaderPreset != null)
              _menuItem(
                'shaders',
                Icons.auto_fix_high_rounded,
                context.l10n.playerShaders(
                  shaderPresetLabel ?? context.l10n.commonOff,
                ),
              ),
            // Screen brightness (mobile only)
            if (!kIsWeb &&
                onBrightness != null &&
                (Platform.isAndroid || Platform.isIOS))
              _menuItem(
                'brightness',
                Icons.brightness_6_rounded,
                context.l10n.playerScreenBrightness,
              ),
          ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    return PopupMenuItem(
      key: TestKeys.osdOverflowItem(value),
      value: value,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
