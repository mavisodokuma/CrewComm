import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRtcAudioService {
  final Map<String, RTCPeerConnection> _peers = <String, RTCPeerConnection>{};
  MediaStream? _localStream;

  Future<void> prepareMic() async {
    _localStream ??= await navigator.mediaDevices.getUserMedia(
      <String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      },
    );
  }

  Future<RTCSessionDescription> createOffer(String peerId) async {
    final peer = await _peer(peerId);
    final offer = await peer.createOffer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await peer.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> acceptOffer(
    String peerId,
    RTCSessionDescription offer,
  ) async {
    final peer = await _peer(peerId);
    await peer.setRemoteDescription(offer);
    final answer = await peer.createAnswer(<String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    await peer.setLocalDescription(answer);
    return answer;
  }

  Future<void> acceptAnswer(String peerId, RTCSessionDescription answer) async {
    final peer = await _peer(peerId);
    await peer.setRemoteDescription(answer);
  }

  Future<void> addIceCandidate(String peerId, RTCIceCandidate candidate) async {
    final peer = await _peer(peerId);
    await peer.addCandidate(candidate);
  }

  Future<void> setMicEnabled(bool enabled) async {
    await prepareMic();
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  Future<RTCPeerConnection> _peer(String peerId) async {
    final existing = _peers[peerId];
    if (existing != null) {
      return existing;
    }
    await prepareMic();
    final peer = await createPeerConnection(<String, dynamic>{
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unified-plan',
    });
    for (final track in _localStream!.getTracks()) {
      await peer.addTrack(track, _localStream!);
    }
    _peers[peerId] = peer;
    return peer;
  }

  Future<void> dispose() async {
    for (final peer in _peers.values) {
      await peer.close();
    }
    _peers.clear();
    await _localStream?.dispose();
    _localStream = null;
  }
}
