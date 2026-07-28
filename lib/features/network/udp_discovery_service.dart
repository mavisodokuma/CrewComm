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
  Timer? _presenceTimer;
  final _roomsController = StreamController<DiscoveredRoom>.broadcast();
  final _peersController = StreamController<PeerPresence>.broadcast();

  Stream<DiscoveredRoom> get rooms => _roomsController.stream;
  Stream<PeerPresence> get peers => _peersController.stream;

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
        switch (data['type']) {
          case 'crewcomm.room':
            final rawInvite = RoomInvite.fromJson(
              data['invite'] as Map<String, dynamic>,
            );
            final invite = RoomInvite(
              roomId: rawInvite.roomId,
              roomName: rawInvite.roomName,
              mode: rawInvite.mode,
              host: datagram.address.address,
              port: rawInvite.port,
              cloudUrl: rawInvite.cloudUrl,
            );
            _roomsController.add(
              DiscoveredRoom(
                invite: invite,
                address: datagram.address.address,
                lastSeen: DateTime.now(),
              ),
            );
          case 'crewcomm.peer':
            _peersController.add(
              PeerPresence(
                roomId: '${data['roomId']}',
                peerId: '${data['peerId']}',
                name: '${data['name'] ?? 'Crew'}',
                roleLabel: '${data['roleLabel'] ?? 'Crew'}',
                isAdmin: data['isAdmin'] == true,
                address: datagram.address.address,
                lastSeen: DateTime.now(),
              ),
            );
        }
      } catch (_) {
        // Ignore non-CrewComm UDP packets on shared production networks.
      }
    });
  }

  Future<void> announcePresence({
    required String roomId,
    required String peerId,
    required String name,
    required bool isAdmin,
  }) async {
    await startListening();
    final packet = utf8.encode(
      jsonEncode(<String, dynamic>{
        'type': 'crewcomm.peer',
        'roomId': roomId,
        'peerId': peerId,
        'name': name,
        'roleLabel': isAdmin ? 'DIR' : 'Crew',
        'isAdmin': isAdmin,
      }),
    );
    void send() {
      _socket?.send(packet, InternetAddress('255.255.255.255'), discoveryPort);
    }

    send();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 2), (_) => send());
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
    _presenceTimer?.cancel();
    _socket?.close();
    _socket = null;
    _roomsController.close();
    _peersController.close();
  }
}

class PeerPresence {
  const PeerPresence({
    required this.roomId,
    required this.peerId,
    required this.name,
    required this.roleLabel,
    required this.isAdmin,
    required this.address,
    required this.lastSeen,
  });

  final String roomId;
  final String peerId;
  final String name;
  final String roleLabel;
  final bool isAdmin;
  final String address;
  final DateTime lastSeen;
}
