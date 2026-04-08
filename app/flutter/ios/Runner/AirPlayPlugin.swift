import Flutter
import UIKit
import AVKit
import MediaPlayer

/// Flutter plugin for AirPlay streaming support.
///
/// Uses AVPlayer with external playback enabled for AirPlay output
/// and AVRoutePickerView for device selection.
public class AirPlayPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "crispy_tivi/airplay",
            binaryMessenger: registrar.messenger()
        )
        let instance = AirPlayPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Monitor AirPlay route changes
        NotificationCenter.default.addObserver(
            instance,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        // Configure audio session for AirPlay
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AirPlay: Failed to configure audio session: \(error)")
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "showPicker":
            showAirPlayPicker(result: result)
        case "playUrl":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(false)
                return
            }
            let title = args["title"] as? String
            playUrl(url, title: title, result: result)
        case "pause":
            pause(result: result)
        case "resume":
            resume(result: result)
        case "stop":
            stop(result: result)
        case "disconnect":
            disconnect(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - AirPlay Picker

    private func showAirPlayPicker(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.getKeyWindow(),
                  let rootVC = window.rootViewController else {
                result(nil)
                return
            }

            // Create AVRoutePickerView
            let picker = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            picker.prioritizesVideoDevices = true
            picker.tintColor = .white

            // Add to view temporarily (required for programmatic trigger)
            rootVC.view.addSubview(picker)
            picker.isHidden = true

            // Programmatically trigger the picker button
            for subview in picker.subviews {
                if let button = subview as? UIButton {
                    button.sendActions(for: .touchUpInside)
                    break
                }
            }

            // Remove after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                picker.removeFromSuperview()
            }

            result(nil)
        }
    }

    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }

    // MARK: - Playback Control

    private func playUrl(_ urlString: String, title: String?, result: @escaping FlutterResult) {
        guard let url = URL(string: urlString) else {
            print("AirPlay: Invalid URL: \(urlString)")
            result(false)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(false)
                return
            }

            // Create player item
            self.playerItem = AVPlayerItem(url: url)

            // Create or reuse player
            if self.player == nil {
                self.player = AVPlayer(playerItem: self.playerItem)

                // Enable AirPlay
                self.player?.allowsExternalPlayback = true
                self.player?.usesExternalPlaybackWhileExternalScreenIsActive = true

                // Observe playback status
                self.addPlayerObservers()
            } else {
                self.player?.replaceCurrentItem(with: self.playerItem)
            }

            // Update Now Playing info
            self.updateNowPlayingInfo(title: title ?? "CrispyTivi")

            // Start playback
            self.player?.play()

            print("AirPlay: Playing \(urlString)")
            result(true)
        }
    }

    private func pause(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.pause()
            result(nil)
        }
    }

    private func resume(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.play()
            result(nil)
        }
    }

    private func stop(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.pause()
            self?.player?.replaceCurrentItem(with: nil)
            self?.clearNowPlayingInfo()
            result(nil)
        }
    }

    private func disconnect(result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            self?.removePlayerObservers()
            self?.player?.pause()
            self?.player = nil
            self?.playerItem = nil
            self?.clearNowPlayingInfo()
            result(nil)
        }
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo(title: String) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        if let item = playerItem {
            let duration = item.duration
            if duration.isNumeric && !duration.isIndefinite {
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(duration)
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Player Observers

    private func addPlayerObservers() {
        guard let player = player else { return }

        // Observe playback time
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Update Now Playing position
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(time)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    private func removePlayerObservers() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Route Change Handling

    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        let isAirPlayActive = currentRoute.outputs.contains { output in
            output.portType == .airPlay
        }

        print("AirPlay: Route changed - reason: \(reason), AirPlay active: \(isAirPlayActive)")

        DispatchQueue.main.async { [weak self] in
            if isAirPlayActive {
                self?.channel?.invokeMethod("onConnected", arguments: nil)
            } else if reason == .oldDeviceUnavailable {
                self?.channel?.invokeMethod("onDisconnected", arguments: nil)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        removePlayerObservers()
    }
}
