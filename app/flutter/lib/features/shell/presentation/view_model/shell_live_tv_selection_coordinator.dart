import 'package:crispy_tivi/features/shell/domain/shell_navigation.dart';

final class ShellLiveTvSelectionCoordinator {
  ShellLiveTvSelectionCoordinator({
    required LiveTvPanel liveTvPanel,
    required String liveTvGroupId,
  }) : _liveTvPanel = liveTvPanel,
       _liveTvGroupId = liveTvGroupId;

  LiveTvPanel _liveTvPanel;
  String _liveTvGroupId;
  int _liveTvFocusedChannelIndex = 0;
  int _liveTvPlayingChannelIndex = 0;

  LiveTvPanel get liveTvPanel => _liveTvPanel;
  bool get liveTvChannelsActive => _liveTvPanel == LiveTvPanel.channels;
  bool get liveTvGuideActive => _liveTvPanel == LiveTvPanel.guide;
  String get liveTvGroupId => _liveTvGroupId;
  int get liveTvFocusedChannelIndex => _liveTvFocusedChannelIndex;
  int get liveTvPlayingChannelIndex => _liveTvPlayingChannelIndex;

  bool selectLiveTvPanel(LiveTvPanel panel) {
    if (_liveTvPanel == panel) {
      return false;
    }
    _liveTvPanel = panel;
    return true;
  }

  bool selectLiveTvGroup(String groupId) {
    if (_liveTvGroupId == groupId) {
      return false;
    }
    _liveTvGroupId = groupId;
    _liveTvFocusedChannelIndex = 0;
    _liveTvPlayingChannelIndex = 0;
    return true;
  }

  bool selectLiveTvChannelIndex(int index) {
    if (_liveTvFocusedChannelIndex == index) {
      return false;
    }
    _liveTvFocusedChannelIndex = index;
    return true;
  }

  bool activateLiveTvFocusedChannel() {
    if (_liveTvPlayingChannelIndex == _liveTvFocusedChannelIndex) {
      return false;
    }
    _liveTvPlayingChannelIndex = _liveTvFocusedChannelIndex;
    return true;
  }
}
