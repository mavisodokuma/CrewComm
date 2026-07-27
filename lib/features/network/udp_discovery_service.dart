import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../room/room_models.dart';

class UdpDiscoveryService {
  static const int discoveryPort = 41414;
  static const int audioPort = 41415;
  static const String serviceType = '_crewcomm._tcp';

  RawDatagramSocket? _socket;
  Timer? _advertiseTimer;
  final _roomsController = StreamController<DiscoveredRoom>.broadcast();

  Stream<DiscoveredRoom> get rooms => _roomsController.stream;

  Future<void> startListening() async {
    if (_socket != null) {
      return;
    }
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = _socket!.receive();
      if (datagram == null) {
        return;
      }
      try {
        final payload = utf8.decode(datagram.data);
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['type'] != 'crewcomm.room') {
          return;
        }
        final invite = RoomInvite.fromJson(
          data['invite'] as Map<String, dynamic>,
        );
        _roomsController.add(
          DiscoveredRoom(
            invite: invite,
            address: datagram.address.address,
            lastSeen: DateTime.now(),
          ),
        );
      } catch (_) {
        // Ignore non-CrewComm UDP packets on shared production networks.
      }
    });
  }

  Future<void> advertise(RoomInvite invite) async {
    await startListening();
    final packet = utf8.encode(
      jsonEncode(<String, dynamic>{
        'type': 'crewcomm.room',
        'service': serviceType,
        'invite': invite.toJson(),
        'sentAt': DateTime.now().toIso8601String(),
      }),
    );
    void send() {
      _socket?.send(packet, InternetAddress('255.255.255.255'), discoveryPort);
    }

    send();
    _advertiseTimer?.cancel();
    _advertiseTimer = Timer.periodic(const Duration(seconds: 2), (_) => send());
  }

  Future<String?> localAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }
    return null;
  }

  void dispose() {
    _advertiseTimer?.cancel();
    _socket?.close();
    _socket = null;
    _roomsController.close();
  }
}
