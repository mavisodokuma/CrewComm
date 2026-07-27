import 'dart:async';

import 'package:flutter/services.dart';

class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('crewcomm/deeplink');
  final _linksController = StreamController<Uri>.broadcast();

  Stream<Uri> get links => _linksController.stream;

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'link') {
        return;
      }
      final uri = Uri.tryParse('${call.arguments}');
      if (uri != null) {
        _linksController.add(uri);
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      final uri = initial == null ? null : Uri.tryParse(initial);
      if (uri != null) {
        _linksController.add(uri);
      }
    } on MissingPluginException {
      // Tests and unsupported platforms can still use QR/manual invite flows.
    }
  }

  void dispose() {
    _linksController.close();
  }
}
