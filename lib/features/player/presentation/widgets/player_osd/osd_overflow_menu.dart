import 'package:flutter/material.dart';

import '../../../../../core/testing/test_keys.dart';
import 'osd_shared.dart';

/// Overflow menu for less-used OSD controls.
///
/// Contains items moved from top/bottom bars per the
/// Netflix redesign: favorite, aspect ratio, sleep
/// timer, PiP, external player, stream info, refresh,
/// search, channels, recordings, audio track, copy URL.
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
      tooltip: 'More options',
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
                isFavorite ? 'Remove Favorite' : 'Add Favorite',
                iconColor: isFavorite ? Colors.red : null,
              ),
            _menuItem('audio', Icons.audiotrack, 'Audio Track'),
            _menuItem(
              'aspect',
              aspectRatioIcon(aspectRatioLabel),
              'Aspect Ratio ($aspectRatioLabel)',
            ),
            _menuItem('refresh', Icons.refresh_rounded, 'Refresh Stream'),
            _menuItem('info', Icons.info_outline_rounded, 'Stream Info'),
            if (onEnterPip != null)
              _menuItem(
                'pip',
                Icons.picture_in_picture_alt_rounded,
                'Picture-in-Picture',
              ),
            if (onSleepTimer != null)
              _menuItem('sleep', Icons.timer_outlined, 'Sleep Timer'),
            if (onCopyUrl != null)
              _menuItem('copyUrl', Icons.copy, 'Copy Stream URL'),
            if (onOpenExternal != null)
              _menuItem('external', Icons.open_in_new, 'External Player'),
            if (isLive && onSearch != null)
              _menuItem('search', Icons.search, 'Search Channels'),
            if (isLive && onChannelList != null)
              _menuItem('channels', Icons.live_tv, 'Channel List'),
            if (isLive && onRecordings != null)
              _menuItem('recordings', Icons.fiber_manual_record, 'Recordings'),
            if (onScreenshot != null)
              _menuItem(
                'screenshot',
                Icons.photo_camera_outlined,
                'Screenshot',
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
