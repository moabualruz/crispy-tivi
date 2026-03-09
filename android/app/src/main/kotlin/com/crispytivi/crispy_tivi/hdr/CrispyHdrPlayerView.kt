package com.crispytivi.crispy_tivi.hdr

import android.content.Context
import android.view.View
import androidx.media3.common.C
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import io.flutter.plugin.platform.PlatformView

/// [PlatformView] that hosts an [ExoPlayer] with [PlayerView] using
/// the default SurfaceView for HDR passthrough.
///
/// SurfaceView is the only Android view type that preserves HDR
/// metadata through the hardware compositor. TextureView and
/// SurfaceTexture both strip HDR transfer functions.
class CrispyHdrPlayerView(
    context: Context,
    private val plugin: CrispyHdrPlayerPlugin,
) : PlatformView {

    private val playerView: PlayerView = PlayerView(context).apply {
        // CrispyTivi has its own OSD — hide Media3's default controls.
        useController = false
    }

    private val exoPlayer: ExoPlayer = ExoPlayer.Builder(context)
        .setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)
        .build()
        .also { player ->
            playerView.player = player
            plugin.attachPlayer(player)
        }

    override fun getView(): View = playerView

    override fun dispose() {
        plugin.detachPlayer()
        exoPlayer.release()
    }
}
