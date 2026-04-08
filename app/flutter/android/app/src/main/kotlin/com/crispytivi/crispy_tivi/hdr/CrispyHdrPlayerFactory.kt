package com.crispytivi.crispy_tivi.hdr

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/// PlatformView factory that creates SurfaceView-backed player views
/// in Hybrid Composition mode.
///
/// Registered with view type `"crispy_hdr_player"`. The Dart side
/// uses `AndroidView(viewType: 'crispy_hdr_player')` which triggers
/// Hybrid Composition (HC), preserving the native SurfaceView's
/// hardware compositor HDR path.
class CrispyHdrPlayerFactory(
    private val plugin: CrispyHdrPlayerPlugin,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return CrispyHdrPlayerView(context, plugin)
    }
}
