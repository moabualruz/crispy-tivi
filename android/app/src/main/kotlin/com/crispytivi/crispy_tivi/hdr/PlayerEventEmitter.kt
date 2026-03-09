package com.crispytivi.crispy_tivi.hdr

import android.os.Handler
import android.os.Looper
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import io.flutter.plugin.common.EventChannel

/// Forwards ExoPlayer events to Dart via [EventChannel].
///
/// Position updates are polled at 100ms intervals via a [Handler]
/// since ExoPlayer doesn't provide a position stream.
class PlayerEventEmitter(
    private val eventSink: () -> EventChannel.EventSink?,
) : Player.Listener {

    private val handler = Handler(Looper.getMainLooper())
    private var player: Player? = null
    private var positionRunnable: Runnable? = null

    /// Attach to a player and start position polling.
    fun attach(player: Player) {
        this.player = player
        player.addListener(this)
        startPositionPolling()
    }

    /// Detach from the player and stop polling.
    fun detach() {
        stopPositionPolling()
        player?.removeListener(this)
        player = null
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        eventSink()?.success(
            mapOf(
                "type" to "state",
                "value" to when (playbackState) {
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_READY -> "ready"
                    Player.STATE_ENDED -> "completed"
                    else -> "unknown"
                },
            ),
        )
        if (playbackState == Player.STATE_ENDED) {
            eventSink()?.success(mapOf("type" to "completed", "value" to true))
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        eventSink()?.success(mapOf("type" to "playing", "value" to isPlaying))
    }

    override fun onIsLoadingChanged(isLoading: Boolean) {
        eventSink()?.success(mapOf("type" to "buffering", "value" to isLoading))
    }

    override fun onPlayerError(error: PlaybackException) {
        eventSink()?.success(mapOf("type" to "error", "value" to error.message))
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        eventSink()?.success(
            mapOf(
                "type" to "videoSize",
                "width" to videoSize.width,
                "height" to videoSize.height,
            ),
        )
    }

    override fun onTracksChanged(tracks: Tracks) {
        val audioTracks = mutableListOf<Map<String, Any?>>()
        val subtitleTracks = mutableListOf<Map<String, Any?>>()

        for (group in tracks.groups) {
            for (i in 0 until group.length) {
                val format = group.getTrackFormat(i)
                val trackType = format.sampleMimeType ?: continue

                if (trackType.startsWith("audio/")) {
                    audioTracks.add(
                        mapOf(
                            "index" to audioTracks.size,
                            "title" to (format.label ?: format.language ?: "Track ${audioTracks.size + 1}"),
                            "language" to format.language,
                            "codec" to format.codecs,
                        ),
                    )
                } else if (trackType.startsWith("text/")) {
                    subtitleTracks.add(
                        mapOf(
                            "index" to subtitleTracks.size,
                            "title" to (format.label ?: format.language ?: "Track ${subtitleTracks.size + 1}"),
                            "language" to format.language,
                            "codec" to format.codecs,
                        ),
                    )
                }
            }
        }

        eventSink()?.success(
            mapOf(
                "type" to "tracks",
                "audio" to audioTracks,
                "subtitle" to subtitleTracks,
            ),
        )
    }

    private fun startPositionPolling() {
        positionRunnable = object : Runnable {
            override fun run() {
                player?.let { p ->
                    eventSink()?.success(
                        mapOf(
                            "type" to "position",
                            "value" to p.currentPosition,
                        ),
                    )
                    eventSink()?.success(
                        mapOf(
                            "type" to "duration",
                            "value" to p.duration.coerceAtLeast(0),
                        ),
                    )
                    eventSink()?.success(
                        mapOf(
                            "type" to "buffer",
                            "value" to p.bufferedPosition,
                        ),
                    )
                }
                handler.postDelayed(this, 100)
            }
        }
        handler.post(positionRunnable!!)
    }

    private fun stopPositionPolling() {
        positionRunnable?.let { handler.removeCallbacks(it) }
        positionRunnable = null
    }
}
