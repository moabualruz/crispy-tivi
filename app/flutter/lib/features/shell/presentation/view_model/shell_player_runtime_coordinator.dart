import 'dart:async';

import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_personalization_coordinator.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_player_coordinator.dart';

final class ShellPlayerRuntimeCoordinator {
  ShellPlayerRuntimeCoordinator({
    required ShellPersonalizationCoordinator personalizationCoordinator,
    required PersonalizationRuntimeSnapshot Function() getPersonalizationRuntime,
    required void Function(PersonalizationRuntimeSnapshot snapshot)
    setPersonalizationRuntime,
    required void Function() notifyChanged,
  }) : _personalizationCoordinator = personalizationCoordinator,
       _getPersonalizationRuntime = getPersonalizationRuntime,
       _setPersonalizationRuntime = setPersonalizationRuntime,
       _notifyChanged = notifyChanged {
    const PlaybackSessionRuntimeRepository playbackSessionRuntimeRepository =
        RustPlaybackSessionRuntimeRepository();
    _playerPlaybackController = PlayerPlaybackController(
      onPlaybackProgress: ({
        required Duration position,
        Duration? duration,
      }) {
        _playerCoordinator.updatePlayerPlaybackProgress(
          position: position,
          duration: duration,
        );
      },
      playbackSessionRuntimeRepository: playbackSessionRuntimeRepository,
    );
    _playerCoordinator = ShellPlayerCoordinator(
      playbackController: _playerPlaybackController,
      playbackSessionRuntimeRepository: playbackSessionRuntimeRepository,
      personalizationCoordinator: _personalizationCoordinator,
      getPersonalizationRuntime: _getPersonalizationRuntime,
      setPersonalizationRuntime: _setPersonalizationRuntime,
      notifyChanged: _notifyChanged,
    );
  }

  final ShellPersonalizationCoordinator _personalizationCoordinator;
  final PersonalizationRuntimeSnapshot Function() _getPersonalizationRuntime;
  final void Function(PersonalizationRuntimeSnapshot snapshot)
  _setPersonalizationRuntime;
  final void Function() _notifyChanged;
  late final ShellPlayerCoordinator _playerCoordinator;
  late final PlayerPlaybackController _playerPlaybackController;

  PlayerSession? get playerSession => _playerCoordinator.playerSession;
  PlayerChromeState get playerChromeState => _playerCoordinator.playerChromeState;
  PlayerChooserKind? get activePlayerChooser =>
      _playerCoordinator.activePlayerChooser;
  PlayerPlaybackController get playerPlaybackController =>
      _playerPlaybackController;

  void launchPlayer(PlayerSession session) {
    _playerCoordinator.launchPlayer(session);
  }

  void openPlayerInfo() {
    _playerCoordinator.openPlayerInfo();
  }

  void openPlayerChooser(PlayerChooserKind kind) {
    _playerCoordinator.openPlayerChooser(kind);
  }

  void closePlayerChooser() {
    _playerCoordinator.closePlayerChooser();
  }

  void unwindPlayer() {
    unawaited(_playerCoordinator.unwindPlayer());
  }

  void selectPlayerQueueIndex(int index) {
    _playerCoordinator.selectPlayerQueueIndex(index);
  }

  void selectPlayerChooserOption(PlayerChooserKind kind, int optionIndex) {
    _playerCoordinator.selectPlayerChooserOption(kind, optionIndex);
  }

  void dispose() {
    _playerCoordinator.dispose();
  }
}
