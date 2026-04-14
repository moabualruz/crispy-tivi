import 'dart:async';

import 'package:crispy_tivi/features/shell/data/playback_session_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/personalization_runtime.dart';
import 'package:crispy_tivi/features/shell/domain/player_session.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/player_playback_controller.dart';
import 'package:crispy_tivi/features/shell/presentation/view_model/shell_personalization_coordinator.dart';

final class ShellPlayerCoordinator {
  ShellPlayerCoordinator({
    required PlayerPlaybackController playbackController,
    required PlaybackSessionRuntimeRepository playbackSessionRuntimeRepository,
    required ShellPersonalizationCoordinator personalizationCoordinator,
    required PersonalizationRuntimeSnapshot Function()
    getPersonalizationRuntime,
    required void Function(PersonalizationRuntimeSnapshot snapshot)
    setPersonalizationRuntime,
    required void Function() notifyChanged,
  }) : _playbackController = playbackController,
       _playbackSessionRuntimeRepository = playbackSessionRuntimeRepository,
       _personalizationCoordinator = personalizationCoordinator,
       _getPersonalizationRuntime = getPersonalizationRuntime,
       _setPersonalizationRuntime = setPersonalizationRuntime,
       _notifyChanged = notifyChanged;

  final PlayerPlaybackController _playbackController;
  final PlaybackSessionRuntimeRepository _playbackSessionRuntimeRepository;
  final ShellPersonalizationCoordinator _personalizationCoordinator;
  final PersonalizationRuntimeSnapshot Function() _getPersonalizationRuntime;
  final void Function(PersonalizationRuntimeSnapshot snapshot)
  _setPersonalizationRuntime;
  final void Function() _notifyChanged;

  PlayerSession? _playerSession;
  PlayerChromeState _playerChromeState = PlayerChromeState.transport;
  PlayerChooserKind? _activePlayerChooser;
  int _lastPlayerPositionSeconds = 0;
  int _lastPlayerDurationSeconds = 0;

  PlayerSession? get playerSession => _playerSession;
  PlayerChromeState get playerChromeState => _playerChromeState;
  PlayerChooserKind? get activePlayerChooser => _activePlayerChooser;

  void launchPlayer(PlayerSession session) {
    _playerSession = session;
    _playerChromeState = PlayerChromeState.transport;
    _activePlayerChooser = null;
    _lastPlayerPositionSeconds =
        session.activeItem.playbackStream?.resumePositionSeconds ?? 0;
    _lastPlayerDurationSeconds = 0;
    unawaited(_playbackController.syncSession(_playerSession));
    _notifyChanged();
  }

  void openPlayerInfo() {
    if (_playerSession == null ||
        _playerChromeState == PlayerChromeState.expandedInfo) {
      return;
    }
    _playerChromeState = PlayerChromeState.expandedInfo;
    _activePlayerChooser = null;
    _notifyChanged();
  }

  void openPlayerChooser(PlayerChooserKind kind) {
    if (_playerSession == null || _activePlayerChooser == kind) {
      return;
    }
    _activePlayerChooser = kind;
    _notifyChanged();
  }

  void closePlayerChooser() {
    if (_activePlayerChooser == null) {
      return;
    }
    _activePlayerChooser = null;
    _notifyChanged();
  }

  Future<void> unwindPlayer() async {
    final PlayerSession? session = _playerSession;
    if (session == null) {
      return;
    }
    if (_activePlayerChooser != null) {
      _activePlayerChooser = null;
      _notifyChanged();
      return;
    }
    if (_playerChromeState == PlayerChromeState.expandedInfo) {
      _playerChromeState = PlayerChromeState.transport;
      _notifyChanged();
      return;
    }
    _playerSession = null;
    _notifyChanged();
    await _persistPlayerSession(session);
    await _playbackController.clear();
  }

  void selectPlayerQueueIndex(int index) {
    final PlayerSession? session = _playerSession;
    if (session == null || index == session.activeIndex) {
      return;
    }
    _playerSession = _playbackSessionRuntimeRepository
        .selectPlayerSessionQueueIndex(session, index);
    _lastPlayerPositionSeconds =
        _playerSession!.activeItem.playbackStream?.resumePositionSeconds ?? 0;
    _lastPlayerDurationSeconds = 0;
    unawaited(_playbackController.syncSession(_playerSession));
    _notifyChanged();
  }

  void selectPlayerChooserOption(PlayerChooserKind kind, int optionIndex) {
    final PlayerSession? session = _playerSession;
    if (session == null) {
      return;
    }
    _playerSession = _playbackSessionRuntimeRepository
        .selectPlayerSessionChooserOption(session, kind, optionIndex);
    unawaited(_playbackController.syncSession(_playerSession));
    _notifyChanged();
  }

  void updatePlayerPlaybackProgress({
    required Duration position,
    Duration? duration,
  }) {
    _lastPlayerPositionSeconds = position.inSeconds;
    if (duration != null && duration.inSeconds > 0) {
      _lastPlayerDurationSeconds = duration.inSeconds;
    }
  }

  Future<void> _persistPlayerSession(PlayerSession session) async {
    _setPersonalizationRuntime(
      await _personalizationCoordinator.persistPlayerSession(
        snapshot: _getPersonalizationRuntime(),
        session: session,
        positionSeconds: _lastPlayerPositionSeconds,
        durationSeconds: _lastPlayerDurationSeconds,
      ),
    );
    _lastPlayerPositionSeconds = 0;
    _lastPlayerDurationSeconds = 0;
  }

  void dispose() {
    _playbackController.dispose();
  }
}
