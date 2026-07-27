import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'udp_discovery_service.dart';

class AudioPacket {
  const AudioPacket({
    required this.data,
    required this.address,
    required this.port,
    required this.receivedAt,
  });

  final Uint8List data;
  final InternetAddress address;
  final int port;
  final DateTime receivedAt;
}

class LocalAudioTransport {
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
      _audioController.add(
        AudioPacket(
          data: Uint8List.fromList(datagram.data),
          address: datagram.address,
          port: datagram.port,
          receivedAt: DateTime.now(),
        ),
      );
    });
  }

  void send(Uint8List packet, Iterable<InternetAddress> peers) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    for (final peer in peers) {
      socket.send(packet, peer, UdpDiscoveryService.audioPort);
    }
  }

  void dispose() {
    _socket?.close();
    _socket = null;
    _audioController.close();
  }
}
