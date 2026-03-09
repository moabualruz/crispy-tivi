package com.crispytivi.crispy_tivi.hdr

import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// Flutter plugin that exposes an ExoPlayer (Media3) HDR player
/// via MethodChannel and EventChannel.
///
/// ## Channels
///
/// - `com.crispytivi/hdr_player` — MethodChannel for commands
/// - `com.crispytivi/hdr_player/events` — EventChannel for state updates
///
/// ## PlatformView
///
/// Registers `"crispy_hdr_player"` PlatformView factory. The Dart side
/// creates an `AndroidView(viewType: 'crispy_hdr_player')` which uses
/// Hybrid Composition mode, preserving SurfaceView HDR passthrough.
class CrispyHdrPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var player: ExoPlayer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var eventEmitter: PlayerEventEmitter? = null
    private var context: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        channel = MethodChannel(binding.binaryMessenger, "com.crispytivi/hdr_player")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.crispytivi/hdr_player/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        eventEmitter = PlayerEventEmitter { eventSink }

        binding.platformViewRegistry.registerViewFactory(
            "crispy_hdr_player",
            CrispyHdrPlayerFactory(this),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        detachPlayer()
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> handleOpen(call, result)
            "play" -> { player?.play(); result.success(null) }
            "pause" -> { player?.pause(); result.success(null) }
            "stop" -> { player?.stop(); result.success(null) }
            "seek" -> handleSeek(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "setRate" -> handleSetRate(call, result)
            "setAudioTrack" -> handleSetAudioTrack(call, result)
            "setSubtitleTrack" -> handleSetSubtitleTrack(call, result)
            "isHdrSupported" -> {
                val ctx = context
                if (ctx != null) {
                    result.success(HdrCapabilityDetector.isHdrSupported(ctx))
                } else {
                    result.success(false)
                }
            }
            "getSupportedHdrFormats" -> {
                val ctx = context
                if (ctx != null) {
                    result.success(HdrCapabilityDetector.getSupportedFormats(ctx))
                } else {
                    result.success(emptyList<String>())
                }
            }
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    /// Called by [CrispyHdrPlayerView] when the ExoPlayer is created.
    fun attachPlayer(exoPlayer: ExoPlayer) {
        player = exoPlayer
        eventEmitter?.attach(exoPlayer)
    }

    /// Called by [CrispyHdrPlayerView] when disposing.
    fun detachPlayer() {
        eventEmitter?.detach()
        player = null
    }

    private fun handleOpen(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url == null) {
            result.error("INVALID_ARG", "Missing 'url' argument", null)
            return
        }
        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
        val startPositionMs = call.argument<Number>("startPositionMs")?.toLong() ?: 0L

        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .build()

        player?.let { p ->
            p.setMediaItem(mediaItem)
            p.prepare()
            if (startPositionMs > 0) {
                p.seekTo(startPositionMs)
            }
            p.playWhenReady = true
            // Apply HTTP headers via DataSource.Factory if needed
            // For now, basic URL playback covers most IPTV streams
        }
        result.success(null)
    }

    private fun handleSeek(call: MethodCall, result: MethodChannel.Result) {
        val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
        player?.seekTo(positionMs)
        result.success(null)
    }

    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
        player?.volume = volume.coerceIn(0.0f, 1.0f)
        result.success(null)
    }

    private fun handleSetRate(call: MethodCall, result: MethodChannel.Result) {
        val rate = call.argument<Number>("rate")?.toFloat() ?: 1.0f
        player?.playbackParameters = PlaybackParameters(rate)
        result.success(null)
    }

    private fun handleSetAudioTrack(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Number>("index")?.toInt() ?: 0
        player?.let { p ->
            val trackGroups = p.currentTracks.groups
            var audioIndex = 0
            for (group in trackGroups) {
                val format = group.getTrackFormat(0)
                if (format.sampleMimeType?.startsWith("audio/") == true) {
                    if (audioIndex == index) {
                        p.trackSelectionParameters = p.trackSelectionParameters
                            .buildUpon()
                            .setOverrideForType(
                                androidx.media3.common.TrackSelectionOverride(
                                    group.mediaTrackGroup, 0,
                                ),
                            )
                            .build()
                        break
                    }
                    audioIndex++
                }
            }
        }
        result.success(null)
    }

    private fun handleSetSubtitleTrack(call: MethodCall, result: MethodChannel.Result) {
        val index = call.argument<Number>("index")?.toInt() ?: -1
        player?.let { p ->
            if (index < 0) {
                // Disable subtitles
                p.trackSelectionParameters = p.trackSelectionParameters
                    .buildUpon()
                    .setIgnoredTextSelectionFlags(0xFFFF)
                    .build()
            } else {
                val trackGroups = p.currentTracks.groups
                var subtitleIndex = 0
                for (group in trackGroups) {
                    val format = group.getTrackFormat(0)
                    if (format.sampleMimeType?.startsWith("text/") == true) {
                        if (subtitleIndex == index) {
                            p.trackSelectionParameters = p.trackSelectionParameters
                                .buildUpon()
                                .setOverrideForType(
                                    androidx.media3.common.TrackSelectionOverride(
                                        group.mediaTrackGroup, 0,
                                    ),
                                )
                                .build()
                            break
                        }
                        subtitleIndex++
                    }
                }
            }
        }
        result.success(null)
    }

    private fun handleDispose(result: MethodChannel.Result) {
        detachPlayer()
        result.success(null)
    }
}
