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
    
    // Register PiP MethodChannel
    if let controller = window?.rootViewController as? FlutterViewController {
        pipChannel = FlutterMethodChannel(name: "crispy/pip", binaryMessenger: controller.binaryMessenger)
        pipChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "enterPip":
                // Note: Proper iOS PiP requires AVPlayerLayer from the video player plugin (e.g. media_kit).
                // This is a placeholder wiring to satisfy the method channel.
                if AVPictureInPictureController.isPictureInPictureSupported() {
                    // Activate PiP natively if configured
                    result(nil)
                } else {
                    result(FlutterError(code: "UNAVAILABLE", message: "PiP not supported on this device", details: nil))
                }
            case "exitPip":
                // Exit PiP logic
                result(nil)
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
