# CrewComm

CrewComm is a cross-platform Flutter push-to-talk walkie-talkie app for live production crews. It is offline-first over shared Wi-Fi and can fall back to cloud WebSocket signaling when crew are split across networks.

## Implemented

- Modular Flutter structure under `lib/features/room`, `lib/features/audio`, `lib/features/network`, `lib/features/overlay`, and `lib/ui/components`.
- Admin room creation with Local Wi-Fi or Cloud mode, QR invite links, member grid, direct PTT, broadcast all, master mute, crew talk permissions, kick, mute, and transfer controls.
- Crew join flow through local UDP discovery, QR scan, or `crewcomm://room?...` deep links.
- UDP local room discovery on port `41414` and raw UDP audio packet transport on port `41415`.
- WebRTC audio peer scaffolding with microphone capture and offer/answer helpers for P2P media.
- Cloud signaling abstraction over WebSockets for room joins, PTT state, permissions, and moderation events.
- PTT feedback with open/close chirps, admin broadcast haptics, audio ducking state, foreground radio service, and Android headset media-button MethodChannel hooks.
- Android system-wide overlay using `flutter_overlay_window`, plus an in-overlay mini PTT button with idle, transmitting, and receiving states.
- iOS microphone, local network, Bonjour, deep link, background audio, and `AVAudioSession.playAndRecord` configuration.
- Android mic, internet, Wi-Fi multicast, foreground service, special-use overlay, Bluetooth, deep link, and overlay service permissions.
- Consistent `CrewComm` display name on Android and iOS.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The Android APK output is generated at `build/app/outputs/flutter-apk/app-debug.apk`.

The project was validated with Flutter 3.24.5, Android compile SDK 36, Android Gradle Plugin 8.6.1, Kotlin 2.2.20, Gradle 8.14.3, and NDK 26.1.10909125. The verified debug APK is available at the path above.

### Device deployment

The debug APK was installed and launched successfully on a Samsung SM-S908U1 running Android 16:

```bash
flutter install -d <android-device-id> --use-application-binary build/app/outputs/flutter-apk/app-debug.apk
```

To produce an IPA, open the `ios` project on macOS, configure the Apple Development Team and provisioning profile for `com.crewcomm.cmc`, then run:

```bash
flutter build ipa --release
```

The signed IPA is generated under `build/ios/ipa`. iOS builds cannot be compiled or signed from Windows.

### Build an unsigned IPA from Windows

The GitHub Actions workflow at `.github/workflows/build-ios-ipa.yml` runs automatically after a push to `main` and can also be started manually. It uses a macOS runner to build and package `CrewComm-unsigned.ipa` without App Store signing:

1. Open the repository's **Actions** tab.
2. Select **Build unsigned iOS IPA**.
3. Select **Run workflow** and wait for the job to finish.
4. Download the `CrewComm-unsigned-ipa` artifact from the completed run.
5. Extract the artifact and sign/install the IPA from Windows with a sideloading tool.

The IPA produced by CI is unsigned and cannot be installed directly. A free Apple account normally requires the app to be re-signed periodically.

The iOS deployment target is 13.0, matching the minimum required by the pinned WebRTC plugin.

## Notes

- Local discovery uses UDP broadcast because it works without internet and does not require a separate router service.
- Physical iPhones require Apple's restricted `com.apple.developer.networking.multicast` entitlement for UDP broadcast discovery. Without that entitlement, use Cloud mode while testing this sideloaded build.
- Raw UDP audio transmit is available for ultra-low-latency local experimentation; WebRTC remains the preferred receive/playback path for production jitter buffering, device routing, and echo handling.
- `flutter_webrtc` is pinned to `0.12.11` for compatibility with the Flutter 3.24 Android texture API used by this project.
- iOS does not allow a true system-wide floating overlay above other apps, so the overlay feature is Android-only.
- Replace the sample `wss://crewcomm.example/ws` endpoint with a deployed signaling server before using Cloud mode with real crews.
