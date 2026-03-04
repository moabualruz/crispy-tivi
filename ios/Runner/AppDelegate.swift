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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
