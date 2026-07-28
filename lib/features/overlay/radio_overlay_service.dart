import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class RadioOverlayService {
  RadioOverlayService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action') {
        if (call.arguments is Map &&
            (call.arguments as Map)['action'] == 'dismiss') {
          _visible = false;
        }
        _events.add(call.arguments);
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('crewcomm/overlay');
  final StreamController<dynamic> _events =
      StreamController<dynamic>.broadcast();
  bool _visible = false;

  Stream<dynamic> get events => _events.stream;

  Future<void> show() async {
    if (!Platform.isAndroid) {
      return;
    }
    _visible = true;
    await _channel.invokeMethod<void>('show');
  }

  Future<void> sendState(Map<String, Object?> state) async {
    if (!Platform.isAndroid || !_visible) {
      return;
    }
    await _channel.invokeMethod<void>('updateState', state);
  }

  Future<void> hide() async {
    if (!Platform.isAndroid) {
      return;
    }
    _visible = false;
    await _channel.invokeMethod<void>('hide');
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _events.close();
  }
}
