part of 'player_service.dart';

/// Core fields and state management for [PlayerService].
///
/// Holds all shared mutable state (player instance,
/// stream controller, retry/reconnection bookkeeping)
/// and the [_updateState] method used by every mixin.
///
/// This is a `part of` the player_service library so all
/// mixins can access library-private members.
abstract class PlayerServiceBase {
  PlayerServiceBase({
    CrispyPlayer? player,
    DateTime Function()? clock,
    AdaptiveBufferManager? bufferManager,
    WarmFailoverEngine? warmFailover,
    OsMediaSession? mediaSession,
  }) : _player = player ?? MediaKitPlayer(),
       _clock = clock ?? DateTime.now,
       _bufferManager = bufferManager,
       _warmFailover = warmFailover,
       _mediaSession = mediaSession ?? OsMediaSession();

  // ── Core Player ──────────────────────────────────────
  // Mutable — PlayerHandoffManager swaps backends at runtime.
  // ignore: prefer_final_fields
  CrispyPlayer _player;

  /// The underlying [CrispyPlayer] for playback.
  CrispyPlayer get player => _player;

  /// Clock function, injectable for testing.
  final DateTime Function() _clock;

  /// Adaptive buffer tier manager (null when unavailable).
  final AdaptiveBufferManager? _bufferManager;

  /// Warm failover engine (null when unavailable or on web).
  final WarmFailoverEngine? _warmFailover;

  // ── Handoff Manager ────────────────────────────────
  late final PlayerHandoffManager _handoffManager;

  // ── Playback State ───────────────────────────────────
  app.PlaybackState _state = const app.PlaybackState();

  /// Current state snapshot.
  app.PlaybackState get state => _state;

  final _stateController = StreamController<app.PlaybackState>.broadcast();

  /// Stream of playback state changes.
  ///
  /// Position-only updates are throttled to ~4 Hz to
  /// avoid 60 Hz rebuild churn in the UI layer. All
  /// other state changes emit immediately.
  Stream<app.PlaybackState> get stateStream => _stateController.stream;

  // ── Position Throttle ────────────────────────────────
  DateTime _lastPositionEmit = DateTime(0);
  static const _positionInterval = Duration(milliseconds: 250);
  Timer? _positionFlushTimer;

  // ── Reconnection State ───────────────────────────────
  static const int maxRetries = 5;
  static const Duration retryDelay = Duration(seconds: 2);

  int _retryCount = 0;
  String? _lastUrl;
  bool _lastIsLive = false;
  String? _lastChannelName;
  String? _lastChannelLogoUrl;
  String? _lastCurrentProgram;
  Map<String, String>? _lastHeaders;

  /// Number of retry attempts made for the current
  /// stream.
  int get retryCount => _retryCount;

  /// The URL of the currently playing (or last played)
  /// stream.
  String? get currentUrl => _lastUrl;

  // ── Retry Timer ──────────────────────────────────────
  Timer? _retryTimer;

  // ── Volume ───────────────────────────────────────────
  /// Saved volume for mute/unmute toggle.
  double _lastVolumeBeforeMute = 1.0;

  // ── Web Video Bridge ─────────────────────────────────
  WebVideoBridge? _webBridge;
  Map<String, String> _externalStreamInfo = {};

  // ── Upscale Config ──────────────────────────────────
  // Setters are in PlayerUpscaleMixin.

  UpscaleMode _upscaleMode = UpscaleMode.auto;
  UpscaleQuality _upscaleQuality = UpscaleQuality.balanced;
  GpuInfo _gpuInfo = GpuInfo.unknown;
  final UpscaleManager _upscaleManager = UpscaleManager();
  int? _activeUpscaleTier;

  // ── Web Video Persistency ───────────────────────────
  /// A GlobalKey used to preserve the underlying HTML <video>
  /// element across route transitions on the web, allowing
  /// seamless playback from mini-player/preview to fullscreen.
  final GlobalKey webVideoKey = GlobalKey(debugLabel: 'WebHlsVideo');

  // ── Audio / Decoder Config ──────────────────────────
  // These fields live in the base class so all mixins
  // (especially PlayerStreamInfoMixin) can read them.
  // Setters are in PlayerAudioConfigMixin.

  /// Hardware decoder mode: 'auto-safe', 'auto', 'no', or specific.
  /// Default 'auto' lets mpv pick the preferred hardware decoder.
  String _hwdecMode = 'auto';

  /// Stream quality profile.
  StreamProfile _streamProfile = StreamProfile.auto;

  /// Audio output driver.
  String _audioOutput = 'auto';

  /// Whether audio passthrough is enabled.
  bool _audioPassthroughEnabled = false;

  /// Codecs to passthrough: 'ac3', 'dts', etc.
  List<String> _audioPassthroughCodecs = ['ac3', 'dts'];

  /// EBU R128 loudness normalization.
  bool _loudnessNormalization = true;

  /// Surround-to-stereo downmix.
  bool _stereoDownmix = false;

  /// Maximum volume percentage (100–300).
  int _maxVolume = 100;

  // ── Stream Proxy ──────────────────────────────────
  /// Local ffmpeg proxy for codec repair (desktop only).
  final StreamProxy _streamProxy = StreamProxy();

  /// Whether the current stream is playing through the proxy.
  bool _proxyActive = false;

  /// URLs already retried through the proxy this session.
  /// Prevents infinite retry loops.
  final Set<String> _proxyRetriedUrls = {};

  /// Timer for audio track detection watchdog.
  Timer? _audioCheckTimer;

  // ── Audio Interruption ──────────────────────────────
  /// True when playback was auto-paused by an audio
  /// interruption (phone call, Siri, etc.) and should
  /// resume when the interruption ends.
  bool _autoPausedByInterruption = false;

  // ── OS Media Session ─────────────────────────────────
  final OsMediaSession _mediaSession;

  // ── Subscriptions ────────────────────────────────────
  final List<StreamSubscription<dynamic>> _subs = [];

  // ── Upscale Hook ────────────────────────────────────
  // No-op stub — overridden by PlayerUpscaleMixin.

  /// Applies video upscaling. Overridden by
  /// [PlayerUpscaleMixin].
  Future<void> applyUpscale() async {}

  // ── Abstract Methods ─────────────────────────────────
  // Declared here so mixins can call them without
  // depending on the concrete PlayerService class.

  /// Opens media — implemented by [PlayerService].
  Future<void> openMedia(String url, {bool isLive = false});

  /// Pause playback — implemented by [PlayerService].
  Future<void> pause();

  /// Resume playback — implemented by [PlayerService].
  Future<void> resume();

  /// Stop playback — implemented by [PlayerService].
  Future<void> stop();

  // ── updateState ──────────────────────────────────────

  /// Merges new values into [_state] and emits to
  /// [_stateController]. Position-only updates are
  /// throttled to ~4 Hz.
  void _updateState({
    app.PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? volume,
    bool? isMuted,
    double? speed,
    String? errorMessage,
    int? selectedAudioTrackId,
    int? selectedSubtitleTrackId,
    int? selectedSecondarySubtitleTrackId,
    bool clearSecondarySubtitle = false,
    String? aspectRatioLabel,
    int? retryCount,
    List<app.AudioTrack>? audioTracks,
    List<app.SubtitleTrack>? subtitleTracks,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
  }) {
    // Dedup: skip redundant status updates.
    if (status != null && status == _state.status) {
      status = null;
    }

    _state = _state.copyWith(
      status: status,
      position: position,
      duration: duration,
      bufferedPosition: bufferedPosition,
      volume: volume,
      isMuted: isMuted,
      speed: speed,
      errorMessage: errorMessage,
      selectedAudioTrackId: selectedAudioTrackId,
      selectedSubtitleTrackId: selectedSubtitleTrackId,
      selectedSecondarySubtitleTrackId: selectedSecondarySubtitleTrackId,
      clearSecondarySubtitle: clearSecondarySubtitle,
      aspectRatioLabel: aspectRatioLabel,
      retryCount: retryCount,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      sleepTimerRemaining: sleepTimerRemaining,
      clearSleepTimer: clearSleepTimer,
    );

    // Throttle position/buffer-only updates to ~4 Hz.
    // State transitions (play/pause/error/etc) always
    // emit immediately so UI reacts without delay.
    final isHighFreqOnly =
        (position != null || bufferedPosition != null) &&
        status == null &&
        duration == null &&
        volume == null &&
        isMuted == null &&
        speed == null &&
        errorMessage == null &&
        selectedAudioTrackId == null &&
        selectedSubtitleTrackId == null &&
        selectedSecondarySubtitleTrackId == null &&
        !clearSecondarySubtitle &&
        aspectRatioLabel == null &&
        retryCount == null &&
        audioTracks == null &&
        subtitleTracks == null &&
        sleepTimerRemaining == null &&
        !clearSleepTimer;

    if (isHighFreqOnly) {
      final now = _clock();
      if (now.difference(_lastPositionEmit) < _positionInterval) {
        // Schedule a flush so the latest position
        // still reaches the UI within 250ms.
        _positionFlushTimer ??= Timer(_positionInterval, () {
          _positionFlushTimer = null;
          _lastPositionEmit = _clock();
          _stateController.add(_state);
        });
        return;
      }
      _positionFlushTimer?.cancel();
      _positionFlushTimer = null;
      _lastPositionEmit = now;
    }

    _stateController.add(_state);

    // Keep screen awake during active playback.
    if (status != null) {
      _syncWakelock(status);
    }
  }

  /// Best-effort wakelock sync — ignores platform
  /// channel errors.
  Future<void> _syncWakelock(app.PlaybackStatus status) async {
    try {
      if (status == app.PlaybackStatus.playing) {
        await WakelockPlus.enable();
      } else if (status == app.PlaybackStatus.paused ||
          status == app.PlaybackStatus.idle ||
          status == app.PlaybackStatus.error) {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Wakelock unavailable (tests, unsupported
      // platform).
    }
  }

  /// Forces re-emission of the current state to all
  /// stream subscribers. Use after mode transitions
  /// so new OSD consumers read fresh status.
  void forceStateEmit() => _stateController.add(_state);
}
