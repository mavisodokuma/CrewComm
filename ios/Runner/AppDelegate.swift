import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var initialLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    initialLink = (launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL)?.absoluteString
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker]
      )
      try session.setActive(true)
    } catch {
      NSLog("CrewComm AVAudioSession setup failed: \(error.localizedDescription)")
    }
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(
        name: "crewcomm/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
      deepLinkChannel?.setMethodCallHandler { [weak self] call, result in
        if call.method == "getInitialLink" {
          result(self?.initialLink)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    deepLinkChannel?.invokeMethod("link", arguments: url.absoluteString)
    return true
  }
}
