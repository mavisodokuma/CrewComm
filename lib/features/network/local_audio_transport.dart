import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'udp_discovery_service.dart';

class AudioPacket {
  const AudioPacket({
    required this.data,
    required this.address,
    required this.port,
    required this.receivedAt,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.target,
    required this.sequence,
    this.peerId,
  });

  final Uint8List data;
  final InternetAddress address;
  final int port;
  final DateTime receivedAt;
  final String roomId;
  final String senderId;
  final String senderName;
  final String target;
  final int sequence;
  final String? peerId;

  bool get isBroadcast => target == 'broadcast';
}

class LocalAudioTransport {
  static const List<int> _magic = <int>[0x43, 0x43, 0x4d, 0x01];

  RawDatagramSocket? _socket;
  final _audioController = StreamController<AudioPacket>.broadcast();

  Stream<AudioPacket> get audioPackets => _audioController.stream;

  Future<void> bind({int port = UdpDiscoveryService.audioPort}) async {
    if (_socket != null) {
      return;
    }
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = _socket!.receive();
      if (datagram == null) {
        return;
      }
      final packet = _decode(datagram);
      if (packet != null) {
        _audioController.add(packet);
      }
    });
  }

  void send({
    required Uint8List audio,
    required Iterable<InternetAddress> peers,
    required String roomId,
    required String senderId,
    required String senderName,
    required String target,
    required int sequence,
    String? peerId,
  }) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    final header = utf8.encode(
      jsonEncode(<String, dynamic>{
        'r': roomId,
        's': senderId,
        'n': senderName,
        't': target,
        'q': sequence,
        if (peerId != null) 'p': peerId,
      }),
    );
    final packet = Uint8List(6 + header.length + audio.length);
    packet.setRange(0, 4, _magic);
    ByteData.sublistView(packet).setUint16(4, header.length);
    packet.setRange(6, 6 + header.length, header);
    packet.setRange(6 + header.length, packet.length, audio);
    for (final peer in peers) {
      socket.send(packet, peer, UdpDiscoveryService.audioPort);
    }
  }

  AudioPacket? _decode(Datagram datagram) {
    final bytes = datagram.data;
    if (bytes.length < 7) {
      return null;
    }
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) {
        return null;
      }
    }
    final headerLength = ByteData.sublistView(bytes).getUint16(4);
    final audioOffset = 6 + headerLength;
    if (headerLength == 0 || audioOffset >= bytes.length) {
      return null;
    }
    try {
      final header = jsonDecode(
        utf8.decode(bytes.sublist(6, audioOffset)),
      ) as Map<String, dynamic>;
      return AudioPacket(
        data: Uint8List.fromList(bytes.sublist(audioOffset)),
        address: datagram.address,
        port: datagram.port,
        receivedAt: DateTime.now(),
        roomId: '${header['r']}',
        senderId: '${header['s']}',
        senderName: '${header['n'] ?? 'Crew'}',
        target: '${header['t']}',
        sequence: header['q'] as int? ?? 0,
        peerId: header['p'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _socket?.close();
    _socket = null;
    _audioController.close();
  }
}
