import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'airplay_helper.dart';

/// Riverpod provider for AirPlay state management.
final airplayServiceProvider = NotifierProvider<AirPlayService, AirPlayState>(
  AirPlayService.new,
);

/// Service that manages AirPlay connectivity and playback state.
///
/// Wraps [AirPlayHelper] with Riverpod state management for reactive UI.
class AirPlayService extends Notifier<AirPlayState> {
  late final AirPlayHelper _helper;

  @override
  AirPlayState build() {
    _helper = AirPlayHelper();
    _helper.setOnConnectionChanged(_onConnectionChanged);

    // Clean up on dispose
    ref.onDispose(() {
      _helper.dispose();
    });

    return AirPlayState(isSupported: _helper.isSupported);
  }

  void _onConnectionChanged(bool connected) {
    if (connected) {
      state = state.copyWith(isConnected: true);
    } else {
      state = state.copyWith(
        isConnected: false,
        currentMedia: null,
        isPlaying: false,
      );
    }
  }

  /// Shows the native AirPlay device picker.
  void showPicker() {
    _helper.showPicker();
  }

  /// Plays a URL on the connected AirPlay device.
  ///
  /// Returns true if playback started successfully.
  Future<bool> playUrl(String url, {String? title}) async {
    final success = await _helper.playUrl(url, title: title);
    if (success) {
      state = state.copyWith(
        currentMedia: AirPlayMedia(url: url, title: title ?? 'Unknown'),
        isPlaying: true,
      );
    }
    return success;
  }

  /// Pauses playback on the AirPlay device.
  void pause() {
    _helper.pause();
    state = state.copyWith(isPlaying: false);
  }

  /// Resumes playback on the AirPlay device.
  void resume() {
    _helper.resume();
    state = state.copyWith(isPlaying: true);
  }

  /// Stops playback but maintains connection.
  void stop() {
    _helper.stop();
    state = state.copyWith(currentMedia: null, isPlaying: false);
  }

  /// Disconnects from the AirPlay device.
  void disconnect() {
    _helper.disconnect();
    state = state.copyWith(
      isConnected: false,
      currentMedia: null,
      isPlaying: false,
    );
  }

  /// Whether AirPlay is supported on this platform.
  bool get isSupported => _helper.isSupported;

  /// Whether currently connected to an AirPlay device.
  bool get isConnected => _helper.isConnected;
}

/// Immutable state for AirPlay service.
class AirPlayState extends Equatable {
  /// Whether AirPlay is supported on this platform.
  final bool isSupported;

  /// Whether connected to an AirPlay device.
  final bool isConnected;

  /// Whether media is currently playing.
  final bool isPlaying;

  /// Currently playing media info, if any.
  final AirPlayMedia? currentMedia;

  const AirPlayState({
    this.isSupported = false,
    this.isConnected = false,
    this.isPlaying = false,
    this.currentMedia,
  });

  AirPlayState copyWith({
    bool? isSupported,
    bool? isConnected,
    bool? isPlaying,
    AirPlayMedia? currentMedia,
  }) {
    return AirPlayState(
      isSupported: isSupported ?? this.isSupported,
      isConnected: isConnected ?? this.isConnected,
      isPlaying: isPlaying ?? this.isPlaying,
      currentMedia: currentMedia ?? this.currentMedia,
    );
  }

  @override
  List<Object?> get props => [
    isSupported,
    isConnected,
    isPlaying,
    currentMedia,
  ];
}

/// Information about media being streamed via AirPlay.
class AirPlayMedia extends Equatable {
  /// The URL being played.
  final String url;

  /// Display title for the media.
  final String title;

  const AirPlayMedia({required this.url, required this.title});

  @override
  List<Object?> get props => [url, title];
}
