import 'dart:io';

import 'package:flutter/services.dart';

class NativePcmPlayer {
  static const MethodChannel _channel = MethodChannel('crewcomm/audio');
  bool _initialized = false;

  Future<void> initialize({
    int sampleRate = 16000,
    int channels = 1,
  }) async {
    if (_initialized || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    await _channel.invokeMethod<void>('initialize', <String, Object>{
      'sampleRate': sampleRate,
      'channels': channels,
    });
    _initialized = true;
  }

  Future<void> write(Uint8List pcm, {double volume = 1}) async {
    await initialize();
    await _channel.invokeMethod<void>('write', <String, Object>{
      'pcm': pcm,
      'volume': volume.clamp(0, 1),
    });
  }

  Future<void> stop() async {
    if (!_initialized) {
      return;
    }
    await _channel.invokeMethod<void>('stop');
  }

  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }
    await _channel.invokeMethod<void>('dispose');
    _initialized = false;
  }
}
