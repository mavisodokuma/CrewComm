import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../network/local_audio_transport.dart';
import '../network/webrtc_audio_service.dart';
import 'priority_audio_mixer.dart';
import 'ptt_feedback_service.dart';

class AudioEngine {
  AudioEngine({
    required this.transport,
    required this.webRtc,
    required this.mixer,
    required this.feedback,
  });

  final LocalAudioTransport transport;
  final WebRtcAudioService webRtc;
  final PriorityAudioMixer mixer;
  final PttFeedbackService feedback;
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _micSubscription;
  StreamSubscription<AudioPacket>? _receiveSubscription;
  List<InternetAddress> _rawUdpPeers = const <InternetAddress>[];

  Future<bool> requestMicPermission() => _recorder.hasPermission();

  Future<void> prepareLocalAudio({
    Iterable<String> peerAddresses = const <String>[],
  }) async {
    _rawUdpPeers = peerAddresses.map(InternetAddress.new).toList();
    await transport.bind();
    await webRtc.prepareMic();
    _receiveSubscription ??= transport.audioPackets.listen((packet) {
      // Raw UDP reception is surfaced here for a native jitter buffer/player.
      // WebRTC playback is handled by remote tracks once signaling is wired.
    });
  }

  Future<void> startTransmit({bool useRawUdp = true}) async {
    await feedback.openingTone();
    await webRtc.setMicEnabled(true);
    if (!useRawUdp || _micSubscription != null) {
      return;
    }
    final supported = await _recorder.isEncoderSupported(AudioEncoder.opus);
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: supported ? AudioEncoder.opus : AudioEncoder.pcm16bits,
        bitRate: 24000,
        sampleRate: 48000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        streamBufferSize: 960,
      ),
    );
    _micSubscription = stream.listen((packet) {
      transport.send(packet, _rawUdpPeers);
    });
  }

  Future<void> stopTransmit() async {
    await webRtc.setMicEnabled(false);
    await _micSubscription?.cancel();
    _micSubscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await feedback.closingTone();
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
    await _recorder.dispose();
    transport.dispose();
    mixer.dispose();
    await webRtc.dispose();
  }
}
