import '../domain/crispy_player.dart';

/// Manages live switching between [CrispyPlayer] backends.
///
/// Used when a capability mismatch is detected (e.g., HDR content
/// on Android where media_kit can't pass through HDR, or PiP
/// requested on iOS where media_kit has no AVPlayerLayer).
///
/// The primary player (always media_kit) is the default. Takeover
/// players are registered by capability key and activated on demand.
class PlayerHandoffManager {
  PlayerHandoffManager({required this.primaryPlayer})
    : _activePlayer = primaryPlayer;

  /// The default (primary) player — always media_kit.
  final CrispyPlayer primaryPlayer;

  /// The currently active player backend.
  CrispyPlayer get activePlayer => _activePlayer;
  CrispyPlayer _activePlayer;

  /// Registered takeover players, keyed by capability.
  final Map<String, CrispyPlayer> _takeoverPlayers = {};

  /// Register a takeover player for a specific capability.
  void registerTakeover(String capability, CrispyPlayer player) {
    _takeoverPlayers[capability] = player;
  }

  /// Hand off to a registered takeover player.
  ///
  /// Pauses the current player, opens the target at the same
  /// position, and swaps the active reference.
  ///
  /// Returns `true` if handoff succeeded, `false` if no
  /// takeover player is registered for [capability].
  Future<bool> handoffTo(String capability) async {
    final target = _takeoverPlayers[capability];
    if (target == null) return false;

    final url = _activePlayer.currentUrl;
    final pos = _activePlayer.position;
    if (url == null) return false;

    await _activePlayer.pause();
    await target.open(url, startPosition: pos);
    _activePlayer = target;
    return true;
  }

  /// Hand back to the primary (media_kit) player.
  ///
  /// Stops the takeover player, opens the primary at the
  /// saved position, and swaps back.
  Future<void> handbackToPrimary() async {
    if (_activePlayer == primaryPlayer) return;

    final url = _activePlayer.currentUrl;
    final pos = _activePlayer.position;

    await _activePlayer.stop();
    if (url != null) {
      await primaryPlayer.open(url, startPosition: pos);
    }
    _activePlayer = primaryPlayer;
  }

  /// Dispose all registered takeover players.
  Future<void> disposeAll() async {
    for (final player in _takeoverPlayers.values) {
      await player.dispose();
    }
    _takeoverPlayers.clear();
  }
}
