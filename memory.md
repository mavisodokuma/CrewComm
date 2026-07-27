# Memory

## 2026-07-27

- Scaffolded a new Flutter project named `cmc` in `C:\Users\me\Documents\Projects\CMC`.
- Built CrewComm, an offline-first live production PTT app with Admin and Crew experiences.
- Added dependencies for Riverpod, QR scanning/generation, deep links, foreground service, Android overlay, permissions, recording, haptics, WebSockets, and WebRTC.
- Added modular code under `lib/features/room`, `lib/features/audio`, `lib/features/network`, `lib/features/overlay`, and `lib/ui/components`.
- Configured Android permissions/services for microphone foreground audio, UDP/Wi-Fi, Bluetooth media buttons, deep links, and true system-wide overlay.
- Configured iOS permissions for microphone, local network, Bonjour, background audio/fetch, deep links, and `AVAudioSession.playAndRecord`.
- Replaced `app_links` with a native `crewcomm/deeplink` MethodChannel because `app_links 6.4.1` does not build cleanly with the installed Flutter 3.24.5 Android Gradle setup.
- Aligned the Android build with compile SDK 36, AGP 8.6.1, Kotlin 2.2.20, Gradle 8.14.3, and NDK 26.1.10909125; added a scoped `record_android` compile SDK compatibility value for Flutter 3.24.
- Pinned `flutter_webrtc` to `0.12.11`, the latest checked release that uses the Flutter 3.24-compatible Android texture API.
- Validation completed: `dart format`, `flutter analyze`, and `flutter test` pass.
- Deployment completed as a debug APK at `build/app/outputs/flutter-apk/app-debug.apk` (261,820,655 bytes, SHA-256 `48CF32D638B5C4EDAD422E0AAE0C7F2E3A6363530B0937D2865C71C2601E60F7`).
- Installed and launched `com.crewcomm.cmc` successfully on a Samsung SM-S908U1 running Android 16; the activity was foregrounded and startup logs contained no fatal exception.
- Documented the macOS/Xcode signing workflow required to produce an IPA for sideloading.
- Updated the Android and iOS display names from the generated `cmc` label to `CrewComm`.
- Rebuilt, reinstalled, and launched the final `CrewComm`-labeled APK on the connected Android device with no fatal startup log.
- Added `.github/workflows/build-ios-ipa.yml` to build and upload an unsigned CrewComm IPA on a GitHub-hosted macOS runner.
- Documented the GitHub Actions download and Windows sideload handoff, including the restricted iOS multicast entitlement limitation for UDP broadcast discovery.
- Configured the unsigned IPA workflow to run automatically on pushes to `main` as well as through manual dispatch.
- Raised the iOS deployment target and Flutter framework minimum from 12.0 to 13.0 after the first macOS build identified the WebRTC pod requirement.
