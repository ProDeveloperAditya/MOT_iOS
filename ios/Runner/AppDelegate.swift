import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    guard shareChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else { return }
    shareChannel = FlutterMethodChannel(
      name: "com.ministryoftruth/share",
      binaryMessenger: controller.binaryMessenger
    )
    shareChannel?.setMethodCallHandler { (call, result) in
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
}
