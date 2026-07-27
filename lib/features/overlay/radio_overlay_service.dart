import 'dart:async';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class RadioOverlayService {
  Stream<dynamic> get events => FlutterOverlayWindow.overlayListener;

  Future<void> show() async {
    if (!Platform.isAndroid) {
      return;
    }
    final granted = await FlutterOverlayWindow.isPermissionGranted() ||
        (await FlutterOverlayWindow.requestPermission() ?? false);
    if (!granted || await FlutterOverlayWindow.isActive()) {
      return;
    }
    await FlutterOverlayWindow.showOverlay(
      height: 104,
      width: 104,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      overlayTitle: 'CrewComm PTT',
      overlayContent: 'Floating radio controls are available',
    );
  }

  Future<void> sendState(Map<String, Object?> state) {
    return FlutterOverlayWindow.shareData(state);
  }
}
