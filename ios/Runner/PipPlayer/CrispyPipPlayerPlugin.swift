import Flutter
import AVKit

/// Flutter plugin that exposes an AVPlayer-based PiP player
/// via MethodChannel and EventChannel.
///
/// ## Channels
///
/// - `com.crispytivi/pip_player` — MethodChannel for commands
/// - `com.crispytivi/pip_player/events` — EventChannel for state updates
///
/// ## PlatformView
///
/// Registers `"crispy_pip_player"` PlatformView factory. The Dart side
/// creates a `UiKitView(viewType: 'crispy_pip_player')` which embeds
/// the `AVPlayerViewController` with PiP support.
class CrispyPipPlayerPlugin: NSObject, FlutterPlugin {

    var channel: FlutterMethodChannel?
    var eventChannel: FlutterEventChannel?
    var eventSink: FlutterEventSink?
    var playerView: CrispyPipPlayerView?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CrispyPipPlayerPlugin()

        let channel = FlutterMethodChannel(
            name: "com.crispytivi/pip_player",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.channel = channel

        let eventChannel = FlutterEventChannel(
            name: "com.crispytivi/pip_player/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
        instance.eventChannel = eventChannel

        registrar.register(
            CrispyPipPlayerFactory(plugin: instance),
            withId: "crispy_pip_player"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "open":
            handleOpen(call, result: result)
        case "play":
            playerView?.player?.play()
            result(nil)
        case "pause":
            playerView?.player?.pause()
            result(nil)
        case "stop":
            playerView?.player?.pause()
            playerView?.player?.replaceCurrentItem(with: nil)
            result(nil)
        case "seek":
            handleSeek(call, result: result)
        case "setVolume":
            handleSetVolume(call, result: result)
        case "setRate":
            handleSetRate(call, result: result)
        case "enterPiP":
            playerView?.startPiP()
            result(nil)
        case "exitPiP":
            playerView?.stopPiP()
            result(nil)
        case "dispose":
            playerView?.dispose()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleOpen(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_URL", message: "Missing or invalid URL", details: nil))
            return
        }

        let headers = args["headers"] as? [String: String] ?? [:]
        let startMs = args["startPositionMs"] as? Int ?? 0

        playerView?.openUrl(
            url,
            headers: headers,
            startPosition: CMTime(
                value: Int64(startMs),
                timescale: 1000
            )
        )
        result(nil)
    }

    private func handleSeek(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let positionMs = args["positionMs"] as? Int else {
            result(nil)
            return
        }
        let time = CMTime(value: Int64(positionMs), timescale: 1000)
        playerView?.player?.seek(
            to: time,
            toleranceBefore: .zero,
            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 1000)
        )
        result(nil)
    }

    private func handleSetVolume(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let volume = args["volume"] as? Float else {
            result(nil)
            return
        }
        playerView?.player?.volume = max(0.0, min(1.0, volume))
        result(nil)
    }

    private func handleSetRate(_ call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let rate = args["rate"] as? Float else {
            result(nil)
            return
        }
        playerView?.player?.rate = rate
        result(nil)
    }
}

// MARK: - FlutterStreamHandler

extension CrispyPipPlayerPlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
