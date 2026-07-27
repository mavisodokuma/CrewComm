import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class CloudSignal {
  const CloudSignal({
    required this.type,
    required this.roomId,
    required this.senderId,
    this.targetId,
    this.payload = const <String, dynamic>{},
  });

  final String type;
  final String roomId;
  final String senderId;
  final String? targetId;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'roomId': roomId,
        'senderId': senderId,
        'targetId': targetId,
        'payload': payload,
      };

  static CloudSignal fromJson(Map<String, dynamic> json) => CloudSignal(
        type: json['type'] as String,
        roomId: json['roomId'] as String,
        senderId: json['senderId'] as String,
        targetId: json['targetId'] as String?,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
}

class CloudSignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _signalsController = StreamController<CloudSignal>.broadcast();

  Stream<CloudSignal> get signals => _signalsController.stream;

  Future<void> connect(Uri endpoint) async {
    await disconnect();
    _channel = WebSocketChannel.connect(endpoint);
    _subscription = _channel!.stream.listen((event) {
      try {
        _signalsController.add(
          CloudSignal.fromJson(jsonDecode('$event') as Map<String, dynamic>),
        );
      } catch (_) {
        // Invalid signaling frames are ignored instead of taking down radio UI.
      }
    });
  }

  void send(CloudSignal signal) {
    _channel?.sink.add(jsonEncode(signal.toJson()));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }

  void dispose() {
    disconnect();
    _signalsController.close();
  }
}
