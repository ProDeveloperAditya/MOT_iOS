import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let shareChannel = FlutterMethodChannel(
        name: "com.ministryoftruth/share",
        binaryMessenger: controller.binaryMessenger
      )
      shareChannel.setMethodCallHandler { (call, result) in
        guard call.method == "getSharedFile" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let defaults = UserDefaults(suiteName: "group.com.ministryoftruth.app")
        let path = defaults?.string(forKey: "sharedFilePath")
        defaults?.removeObject(forKey: "sharedFilePath")
        result(path)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
