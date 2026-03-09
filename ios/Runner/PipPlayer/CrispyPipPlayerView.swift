import Flutter
import AVKit

/// PlatformView hosting `AVPlayerViewController` with PiP support.
///
/// `AVPictureInPictureController` requires `AVPlayerLayer` from
/// `AVPlayerViewController`. This class manages the player lifecycle,
/// periodic position reporting, and PiP delegate callbacks.
class CrispyPipPlayerView: NSObject, FlutterPlatformView,
    AVPictureInPictureControllerDelegate {

    private let playerViewController = AVPlayerViewController()
    private var pipController: AVPictureInPictureController?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var durationObservation: NSKeyValueObservation?
    private let plugin: CrispyPipPlayerPlugin

    var player: AVPlayer? { playerViewController.player }

    init(frame: CGRect, plugin: CrispyPipPlayerPlugin) {
        self.plugin = plugin
        super.init()

        // CrispyTivi has its own OSD — hide native controls
        playerViewController.showsPlaybackControls = false
        playerViewController.view.frame = frame
        playerViewController.view.backgroundColor = .black

        // Audio session already configured in AppDelegate
    }

    func view() -> UIView {
        return playerViewController.view
    }

    func openUrl(_ url: URL, headers: [String: String],
                 startPosition: CMTime) {
        // Create AVURLAsset with custom HTTP headers
        var options: [String: Any] = [:]
        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)

        let avPlayer = AVPlayer(playerItem: item)
        playerViewController.player = avPlayer

        // Seek to start position before playing
        if startPosition != .zero {
            avPlayer.seek(
                to: startPosition,
                toleranceBefore: .zero,
                toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 1000)
            )
        }

        avPlayer.play()

        // Set up PiP controller after player is attached
        setupPipController()

        // Position observer at 250ms intervals
        timeObserver = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 1000),
            queue: .main
        ) { [weak self] time in
            self?.emitPosition(time)
        }

        // Observe player status for error/ready events
        setupItemObservers(item)
    }

    func startPiP() {
        pipController?.startPictureInPicture()
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        plugin.eventSink?(["type": "pipStarted"])
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        plugin.eventSink?(["type": "pipStopped"])
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
            completionHandler: @escaping (Bool) -> Void
    ) {
        // Notify Dart to restore the full UI before completing
        plugin.eventSink?(["type": "pipRestoreUI"])
        // Allow Dart time to rebuild the UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completionHandler(true)
        }
    }

    func dispose() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        durationObservation?.invalidate()
        durationObservation = nil
        pipController?.delegate = nil
        pipController = nil
        player?.pause()
        playerViewController.player = nil
    }

    // MARK: - Private

    private func setupPipController() {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let playerLayer = playerViewController.value(forKey: "playerLayer") as? AVPlayerLayer
        else { return }

        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self

        // iOS 14.2+: allow auto PiP when app goes to background
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
    }

    private func emitPosition(_ time: CMTime) {
        guard time.isValid && !time.isIndefinite else { return }
        let ms = Int(time.seconds * 1000)
        plugin.eventSink?([
            "type": "position",
            "value": ms,
        ])

        // Also emit duration and buffer
        if let item = player?.currentItem {
            let duration = item.duration
            if duration.isValid && !duration.isIndefinite {
                plugin.eventSink?([
                    "type": "duration",
                    "value": Int(duration.seconds * 1000),
                ])
            }

            // Buffered range
            if let range = item.loadedTimeRanges.last?.timeRangeValue {
                let bufferedMs = Int((range.start.seconds + range.duration.seconds) * 1000)
                plugin.eventSink?([
                    "type": "buffer",
                    "value": bufferedMs,
                ])
            }
        }
    }

    private func setupItemObservers(_ item: AVPlayerItem) {
        // Status observation for ready/error
        statusObservation = item.observe(\.status, options: [.new]) {
            [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                self?.plugin.eventSink?(["type": "state", "value": "ready"])
                // Emit playing state
                if self?.player?.rate ?? 0 > 0 {
                    self?.plugin.eventSink?(["type": "playing", "value": true])
                }
            case .failed:
                let message = item.error?.localizedDescription ?? "Unknown error"
                self?.plugin.eventSink?(["type": "error", "value": message])
            default:
                break
            }
        }

        // Observe when playback reaches end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.plugin.eventSink?(["type": "completed", "value": true])
        }
    }
}
