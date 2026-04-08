import Flutter

/// PlatformView factory for the PiP player.
///
/// Registered with view type `"crispy_pip_player"`. The Dart side
/// uses `UiKitView(viewType: 'crispy_pip_player')` to embed the
/// `AVPlayerViewController` view hierarchy that PiP requires.
class CrispyPipPlayerFactory: NSObject, FlutterPlatformViewFactory {

    private let plugin: CrispyPipPlayerPlugin

    init(plugin: CrispyPipPlayerPlugin) {
        self.plugin = plugin
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let view = CrispyPipPlayerView(frame: frame, plugin: plugin)
        plugin.playerView = view
        return view
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
