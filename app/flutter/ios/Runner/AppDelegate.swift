import Flutter
import UIKit
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  var pipChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // IOS-01: Configure audio session for background playback before
    // plugin registration (plugin order is not guaranteed).
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
    try? audioSession.setActive(true)

    GeneratedPluginRegistrant.register(with: self)

    // Register AirPlay plugin
    AirPlayPlugin.register(with: self.registrar(forPlugin: "AirPlayPlugin")!)

    // Register PiP native player plugin (AVPlayer + AVPlayerViewController)
    CrispyPipPlayerPlugin.register(with: self.registrar(forPlugin: "CrispyPipPlayerPlugin")!)
    
    // Register PiP MethodChannel
    if let controller = window?.rootViewController as? FlutterViewController {
        pipChannel = FlutterMethodChannel(name: "crispy/pip", binaryMessenger: controller.binaryMessenger)
        pipChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "enterPip":
                if !AVPictureInPictureController.isPictureInPictureSupported() {
                    result(["success": false, "errorCode": "not_supported"])
                    return
                }
                // iOS PiP is activated via IosPipPlayer → CrispyPipPlayerPlugin.
                // This channel returns success to update PipNotifier state.
                result(["success": true])
            case "exitPip":
                result(nil)
            case "setAutoPipReady":
                // iOS doesn't have native auto-PiP like Android.
                // The Dart lifecycle handler calls enterPip() directly.
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }

    // Register device form factor MethodChannel
    if let controller = window?.rootViewController as? FlutterViewController {
        let deviceChannel = FlutterMethodChannel(name: "crispy/device", binaryMessenger: controller.binaryMessenger)
        deviceChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "getFormFactor":
                switch UIDevice.current.userInterfaceIdiom {
                case .pad:
                    result("tablet")
                case .tv:
                    result("tv")
                default:
                    result("phone")
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
