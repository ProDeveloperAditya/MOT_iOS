import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  // Stores the file path shared from the Share Extension via UserDefaults
  private var sharedFilePath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register the MethodChannel so Dart can ask for any shared media file
    let controller = window?.rootViewController as! FlutterViewController
    let shareChannel = FlutterMethodChannel(
      name: "com.ministryoftruth/share",
      binaryMessenger: controller.binaryMessenger
    )

    shareChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "getSharedFile" {
        // Check UserDefaults for a path written by the Share Extension
        let defaults = UserDefaults(suiteName: "group.com.ministryoftruth.app")
        let path = defaults?.string(forKey: "sharedFilePath")
        // Clear it after reading so we don't re-process on next resume
        defaults?.removeObject(forKey: "sharedFilePath")
        result(path)  // returns nil if nothing was shared — that's correct
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
