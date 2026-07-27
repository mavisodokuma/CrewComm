import 'dart:async';

import 'package:flutter/services.dart';

class BluetoothHeadsetService {
  static const MethodChannel _channel = MethodChannel('crewcomm/headset');
  final _eventsController = StreamController<bool>.broadcast();

  Stream<bool> get pttEvents => _eventsController.stream;

  void start() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mediaButtonDown':
          _eventsController.add(true);
        case 'mediaButtonUp':
          _eventsController.add(false);
      }
    });
  }

  Future<void> register() async {
    try {
      await _channel.invokeMethod<void>('registerMediaButtons');
    } on MissingPluginException {
      // Native media-button routing can be added per platform without changing UI.
    }
  }

  void dispose() {
    _eventsController.close();
  }
}
