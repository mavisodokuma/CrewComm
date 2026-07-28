import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../network/local_audio_transport.dart';
import '../network/webrtc_audio_service.dart';
import 'native_pcm_player.dart';
import 'priority_audio_mixer.dart';
import 'ptt_feedback_service.dart';

class AudioReception {
  const AudioReception({
    required this.senderId,
    required this.senderName,
    required this.broadcast,
    required this.receivedAt,
  });

  final String senderId;
  final String senderName;
  final bool broadcast;
  final DateTime receivedAt;
}

class AudioEngine {
  AudioEngine({
    required this.transport,
    required this.webRtc,
    required this.mixer,
    required this.feedback,
    required this.player,
  });

  final LocalAudioTransport transport;
  final WebRtcAudioService webRtc;
  final PriorityAudioMixer mixer;
  final PttFeedbackService feedback;
  final NativePcmPlayer player;
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<AudioReception> _receptions =
      StreamController<AudioReception>.broadcast();

  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<AudioPacket>? _receiveSubscription;
  final Map<String, InternetAddress> _rawUdpPeers = <String, InternetAddress>{};
  String? _roomId;
  String? _selfId;
  String _displayName = 'Crew';
  bool _isAdmin = false;
  bool _usingRawUdp = false;
  int _sequence = 0;
  DateTime? _lastBroadcastHaptic;
  Timer? _broadcastDuckTimer;

  Stream<AudioReception> get receptions => _receptions.stream;

  Future<bool> requestMicPermission() => _recorder.hasPermission();

  Future<void> prepareLocalAudio({
    required String roomId,
    required String selfId,
    required String displayName,
    required bool isAdmin,
    Iterable<String> peerAddresses = const <String>[],
  }) async {
    _roomId = roomId;
    _selfId = selfId;
    _displayName = displayName;
    _isAdmin = isAdmin;
    for (final address in peerAddresses) {
      addPeer(address);
    }
    await transport.bind();
    await player.initialize();
    _receiveSubscription ??= transport.audioPackets.listen(_receivePacket);
  }

  void addPeer(String address) {
    final parsed = InternetAddress.tryParse(address);
    if (parsed == null || parsed.isLoopback) {
      return;
    }
    _rawUdpPeers[address] = parsed;
  }

  Future<void> startTransmit({
    bool useRawUdp = true,
    required String target,
    String? peerId,
  }) async {
    if (_micSubscription != null) {
      return;
    }
    await feedback.openingTone();
    _usingRawUdp = useRawUdp;
    if (!useRawUdp) {
      await webRtc.setMicEnabled(true);
      return;
    }
    if (_roomId == null || _selfId == null) {
      throw StateError('Local audio is not prepared');
    }
    if (_rawUdpPeers.isEmpty) {
      throw StateError('No local crew peers are connected');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        streamBufferSize: 640,
      ),
    );
    _micSubscription = stream.listen((packet) {
      transport.send(
        audio: packet,
        peers: _rawUdpPeers.values,
        roomId: _roomId!,
        senderId: _selfId!,
        senderName: _displayName,
        target: target,
        peerId: peerId,
        sequence: _sequence++,
      );
    });
  }

  Future<void> stopTransmit() async {
    if (!_usingRawUdp) {
      await webRtc.setMicEnabled(false);
    }
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await feedback.closingTone();
  }

  Future<void> _receivePacket(AudioPacket packet) async {
    if (packet.roomId != _roomId || packet.senderId == _selfId) {
      return;
    }
    final addressedToSelf = switch (packet.target) {
      'broadcast' => true,
      'admin' => _isAdmin,
      'direct' => packet.peerId == _selfId,
      _ => false,
    };
    if (!addressedToSelf) {
      return;
    }
    final volume = packet.isBroadcast ? 1.0 : mixer.crewVolume;
    if (packet.isBroadcast) {
      mixer.setAdminBroadcastActive(true);
      _broadcastDuckTimer?.cancel();
      _broadcastDuckTimer = Timer(const Duration(milliseconds: 360), () {
        mixer.setAdminBroadcastActive(false);
      });
    }
    await player.write(packet.data, volume: volume);
    _receptions.add(
      AudioReception(
        senderId: packet.senderId,
        senderName: packet.senderName,
        broadcast: packet.isBroadcast,
        receivedAt: packet.receivedAt,
      ),
    );
    if (packet.isBroadcast) {
      final now = DateTime.now();
      if (_lastBroadcastHaptic == null ||
          now.difference(_lastBroadcastHaptic!) > const Duration(seconds: 3)) {
        _lastBroadcastHaptic = now;
        await feedback.adminBroadcastHaptic();
      }
    }
  }

  Future<void> setBroadcastPriority(bool enabled) async {
    mixer.setAdminBroadcastActive(enabled);
    if (enabled) {
      await feedback.adminBroadcastHaptic();
    }
  }

  Future<void> dispose() async {
    await _micSubscription?.cancel();
    await _receiveSubscription?.cancel();
    _broadcastDuckTimer?.cancel();
    await _recorder.dispose();
    await player.dispose();
    transport.dispose();
    mixer.dispose();
    await webRtc.dispose();
    await _receptions.close();
  }
}
