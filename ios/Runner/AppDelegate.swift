import Flutter
import UIKit
import AVFoundation

final class NativePcmPlayer {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let queue = DispatchQueue(label: "crewcomm.pcm.player")
  private var format: AVAudioFormat?

  func initialize(sampleRate: Double, channels: AVAudioChannelCount) throws {
    if format?.sampleRate == sampleRate &&
        format?.channelCount == channels &&
        engine.isRunning {
      return
    }
    if engine.attachedNodes.contains(player) {
      engine.disconnectNodeOutput(player)
      engine.detach(player)
    }
    engine.attach(player)
    guard let audioFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: sampleRate,
      channels: channels,
      interleaved: false
    ) else {
      throw NSError(
        domain: "CrewCommAudio",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Unable to create PCM format"]
      )
    }
    format = audioFormat
    engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
    engine.prepare()
    try engine.start()
    player.play()
  }

  func write(_ data: FlutterStandardTypedData, volume: Float) {
    guard let audioFormat = format else {
      return
    }
    let bytesPerFrame = Int(audioFormat.channelCount) * MemoryLayout<Int16>.size
    let frameCount = data.data.count / bytesPerFrame
    guard frameCount > 0,
          let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
          ),
          let channelData = buffer.int16ChannelData else {
      return
    }
    buffer.frameLength = AVAudioFrameCount(frameCount)
    data.data.withUnsafeBytes { source in
      guard let baseAddress = source.baseAddress else {
        return
      }
      memcpy(channelData[0], baseAddress, data.data.count)
    }
    queue.async { [weak self] in
      guard let self else {
        return
      }
      self.player.volume = max(0, min(1, volume))
      if !self.player.isPlaying {
        self.player.play()
      }
      self.player.scheduleBuffer(buffer)
    }
  }

  func stop() {
    queue.async { [weak self] in
      self?.player.stop()
      self?.player.play()
    }
  }

  func dispose() {
    queue.sync {
      player.stop()
      engine.stop()
      if engine.attachedNodes.contains(player) {
        engine.disconnectNodeOutput(player)
        engine.detach(player)
      }
      format = nil
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deepLinkChannel: FlutterMethodChannel?
  private var audioChannel: FlutterMethodChannel?
  private let pcmPlayer = NativePcmPlayer()
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
      audioChannel = FlutterMethodChannel(
        name: "crewcomm/audio",
        binaryMessenger: controller.binaryMessenger
      )
      audioChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "unavailable", message: "Audio player unavailable", details: nil))
          return
        }
        let arguments = call.arguments as? [String: Any]
        switch call.method {
        case "initialize":
          do {
            try self.pcmPlayer.initialize(
              sampleRate: (arguments?["sampleRate"] as? NSNumber)?.doubleValue ?? 16000,
              channels: AVAudioChannelCount(
                (arguments?["channels"] as? NSNumber)?.uint32Value ?? 1
              )
            )
            result(nil)
          } catch {
            result(
              FlutterError(
                code: "audio_init_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        case "write":
          guard let pcm = arguments?["pcm"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "invalid_pcm", message: "PCM payload is missing", details: nil))
            return
          }
          self.pcmPlayer.write(
            pcm,
            volume: (arguments?["volume"] as? NSNumber)?.floatValue ?? 1
          )
          result(nil)
        case "stop":
          self.pcmPlayer.stop()
          result(nil)
        case "dispose":
          self.pcmPlayer.dispose()
          result(nil)
        default:
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
