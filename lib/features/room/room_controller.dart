import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../audio/audio_engine.dart';
import '../audio/bluetooth_headset_service.dart';
import '../audio/foreground_radio_service.dart';
import '../audio/native_pcm_player.dart';
import '../audio/priority_audio_mixer.dart';
import '../audio/ptt_feedback_service.dart';
import '../network/cloud_signaling_service.dart';
import '../network/deep_link_service.dart';
import '../network/local_audio_transport.dart';
import '../network/udp_discovery_service.dart';
import '../network/webrtc_audio_service.dart';
import '../overlay/radio_overlay_service.dart';
import 'room_models.dart';

final udpDiscoveryProvider = Provider<UdpDiscoveryService>((ref) {
  final service = UdpDiscoveryService();
  ref.onDispose(service.dispose);
  return service;
});

final cloudSignalingProvider = Provider<CloudSignalingService>((ref) {
  final service = CloudSignalingService();
  ref.onDispose(service.dispose);
  return service;
});

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine(
    transport: LocalAudioTransport(),
    webRtc: WebRtcAudioService(),
    mixer: PriorityAudioMixer(),
    feedback: PttFeedbackService(),
    player: NativePcmPlayer(),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final foregroundRadioProvider = Provider<ForegroundRadioService>((ref) {
  return ForegroundRadioService()..init();
});

final overlayServiceProvider = Provider<RadioOverlayService>((ref) {
  final service = RadioOverlayService();
  ref.onDispose(service.dispose);
  return service;
});

final headsetServiceProvider = Provider<BluetoothHeadsetService>((ref) {
  final service = BluetoothHeadsetService()..start();
  ref.onDispose(service.dispose);
  return service;
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(service.dispose);
  return service;
});

final roomControllerProvider =
    StateNotifierProvider<RoomController, RoomState>((ref) {
  return RoomController(
    discovery: ref.watch(udpDiscoveryProvider),
    cloud: ref.watch(cloudSignalingProvider),
    audio: ref.watch(audioEngineProvider),
    foreground: ref.watch(foregroundRadioProvider),
    overlay: ref.watch(overlayServiceProvider),
    headset: ref.watch(headsetServiceProvider),
    deepLinks: ref.watch(deepLinkServiceProvider),
  )..init();
});

class RoomController extends StateNotifier<RoomState> {
  RoomController({
    required this.discovery,
    required this.cloud,
    required this.audio,
    required this.foreground,
    required this.overlay,
    required this.headset,
    required this.deepLinks,
  }) : super(
          RoomState(
            selfId: const Uuid().v4(),
            displayName:
                'Operator ${DateTime.now().millisecondsSinceEpoch % 100}',
          ),
        );

  final UdpDiscoveryService discovery;
  final CloudSignalingService cloud;
  final AudioEngine audio;
  final ForegroundRadioService foreground;
  final RadioOverlayService overlay;
  final BluetoothHeadsetService headset;
  final DeepLinkService deepLinks;

  final Uuid _uuid = const Uuid();
  StreamSubscription? _discoverySub;
  StreamSubscription? _cloudSub;
  StreamSubscription? _linkSub;
  StreamSubscription? _overlaySub;
  StreamSubscription? _headsetSub;
  StreamSubscription? _presenceSub;
  StreamSubscription? _audioReceptionSub;
  Timer? _receiveIdleTimer;

  Future<void> init() async {
    await Permission.microphone.request();
    await Permission.bluetoothConnect.request();
    await audio.requestMicPermission();
    await discovery.startListening();
    _discoverySub = discovery.rooms.listen(_upsertDiscoveredRoom);
    _presenceSub = discovery.peers.listen(_handlePeerPresence);
    _audioReceptionSub = audio.receptions.listen(_handleAudioReception);
    _cloudSub = cloud.signals.listen(_handleCloudSignal);
    _overlaySub = overlay.events.listen(_handleOverlayEvent);
    _headsetSub = headset.pttEvents.listen((down) {
      if (down) {
        startPtt(RadioTarget.admin);
      } else {
        stopPtt();
      }
    });
    await headset.register();
    _linkSub = deepLinks.links.listen(joinFromUri);
    await deepLinks.start();
  }

  Future<void> createRoom({
    required String roomName,
    required NetworkMode mode,
    String? cloudUrl,
  }) async {
    final roomId = _uuid.v4().substring(0, 8).toUpperCase();
    final localHost = await discovery.localAddress();
    final invite = RoomInvite(
      roomId: roomId,
      roomName: roomName.trim().isEmpty ? 'Crew Comms' : roomName.trim(),
      mode: mode,
      host: localHost,
      port: UdpDiscoveryService.audioPort,
      cloudUrl: cloudUrl?.trim().isEmpty ?? true ? null : cloudUrl!.trim(),
    );
    state = state.copyWith(
      roomId: roomId,
      roomName: invite.roomName,
      mode: mode,
      role: RadioRole.admin,
      status: ConnectionStatus.connected,
      invite: invite,
      members: const <CrewMember>[],
      log: _log('Created ${invite.roomName} in ${_modeLabel(mode)} mode'),
    );
    await audio.prepareLocalAudio(
      roomId: roomId,
      selfId: state.selfId,
      displayName: state.displayName,
      isAdmin: true,
    );
    await discovery.advertise(invite);
    await discovery.announcePresence(
      roomId: roomId,
      peerId: state.selfId,
      name: state.displayName,
      isAdmin: true,
    );
    await _connectCloudIfNeeded(invite);
    await foreground.start();
    await overlay.show();
    await _syncOverlay();
  }

  Future<void> joinFromInvite(RoomInvite invite) async {
    state = state.copyWith(
      roomId: invite.roomId,
      roomName: invite.roomName,
      mode: invite.mode,
      role: RadioRole.crew,
      status: ConnectionStatus.connected,
      invite: invite,
      members: const <CrewMember>[
        CrewMember(
          id: 'admin',
          name: 'Director',
          roleLabel: 'DIR',
          radioRole: RadioRole.admin,
          latencyMs: 12,
        ),
      ],
      log: _log('Joined ${invite.roomName}'),
    );
    await audio.prepareLocalAudio(
      roomId: invite.roomId,
      selfId: state.selfId,
      displayName: state.displayName,
      isAdmin: false,
      peerAddresses:
          invite.host == null ? const <String>[] : <String>[invite.host!],
    );
    await discovery.announcePresence(
      roomId: invite.roomId,
      peerId: state.selfId,
      name: state.displayName,
      isAdmin: false,
    );
    await _connectCloudIfNeeded(invite);
    _sendCloud('room.join', <String, dynamic>{
      'name': state.displayName,
      'roleLabel': 'Crew',
    });
    await foreground.start();
    await overlay.show();
    await _syncOverlay();
  }

  Future<void> joinFromUri(Uri uri) async {
    if (uri.scheme != 'crewcomm' || uri.host != 'room') {
      return;
    }
    await joinFromInvite(RoomInvite.fromUri(uri));
  }

  void setDisplayName(String value) {
    state = state.copyWith(displayName: value.trim().isEmpty ? 'Crew' : value);
  }

  void toggleCrewTalk(bool enabled) {
    state = state.copyWith(
      allowCrewToCrew: enabled,
      log: _log(
          enabled ? 'Crew-to-crew enabled' : 'Director listen-only enabled'),
    );
    _sendCloud(
        'room.permissions', <String, dynamic>{'allowCrewToCrew': enabled});
  }

  void toggleMasterMute(bool muted) {
    state = state.copyWith(
        masterMuted: muted, log: _log(muted ? 'Master muted' : 'Master live'));
  }

  void toggleHandsFree() {
    final next = !state.handsFree;
    state = state.copyWith(handsFree: next);
    if (!next && state.isTransmitting) {
      stopPtt();
    }
  }

  void toggleMemberMute(String id) {
    state = state.copyWith(
      members: state.members
          .map((member) => member.id == id
              ? member.copyWith(isMuted: !member.isMuted)
              : member)
          .toList(),
    );
  }

  void kickMember(String id) {
    state = state.copyWith(
      members: state.members.where((member) => member.id != id).toList(),
      log: _log('Kicked member $id'),
    );
    _sendCloud('room.kick', <String, dynamic>{'memberId': id});
  }

  void transferAdmin(String id) {
    state = state.copyWith(
      members: state.members
          .map((member) => member.copyWith(
                radioRole: member.id == id ? RadioRole.admin : RadioRole.crew,
              ))
          .toList(),
      log: _log('Transferred admin'),
    );
    _sendCloud('room.transfer_admin', <String, dynamic>{'memberId': id});
  }

  Future<void> startPtt(RadioTarget target, {String? peerId}) async {
    if (state.isTransmitting ||
        state.micMuted ||
        state.masterMuted ||
        (!state.canCrewTalk && !state.isAdmin)) {
      return;
    }
    final isBroadcast = target == RadioTarget.broadcast;
    state = state.copyWith(
      status: ConnectionStatus.transmitting,
      isTransmitting: true,
      isBroadcasting: isBroadcast,
      selectedDirectPeerId: peerId,
      log: _log(isBroadcast ? 'Broadcast all started' : 'PTT opened'),
    );
    try {
      await audio.setBroadcastPriority(isBroadcast);
      await audio.startTransmit(
        useRawUdp: state.mode == NetworkMode.localWifi,
        target: target.name,
        peerId: peerId,
      );
    } catch (error) {
      await audio.setBroadcastPriority(false);
      state = state.copyWith(
        status: ConnectionStatus.connected,
        isTransmitting: false,
        isBroadcasting: false,
        clearDirectPeer: true,
        log: _log('PTT failed: $error'),
      );
      await _syncOverlay();
      return;
    }
    _sendCloud('ptt.start', <String, dynamic>{
      'target': target.name,
      'peerId': peerId,
      'broadcast': isBroadcast,
    });
    await _syncOverlay();
  }

  Future<void> stopPtt() async {
    if (!state.isTransmitting) {
      return;
    }
    await audio.stopTransmit();
    await audio.setBroadcastPriority(false);
    state = state.copyWith(
      status: ConnectionStatus.connected,
      isTransmitting: false,
      isBroadcasting: false,
      clearDirectPeer: true,
      log: _log('PTT released'),
    );
    _sendCloud('ptt.stop', const <String, dynamic>{});
    await _syncOverlay();
  }

  Future<void> showOverlay() => overlay.show();

  void _upsertDiscoveredRoom(DiscoveredRoom room) {
    final rooms = <DiscoveredRoom>[
      room,
      ...state.discoveredRooms.where(
        (existing) => existing.invite.roomId != room.invite.roomId,
      ),
    ].take(6).toList();
    state = state.copyWith(
      status: state.status == ConnectionStatus.idle
          ? ConnectionStatus.discovering
          : state.status,
      discoveredRooms: rooms,
    );
  }

  void _handlePeerPresence(PeerPresence peer) {
    if (peer.roomId != state.roomId || peer.peerId == state.selfId) {
      return;
    }
    audio.addPeer(peer.address);
    final member = CrewMember(
      id: peer.peerId,
      name: peer.name,
      roleLabel: peer.roleLabel,
      radioRole: peer.isAdmin ? RadioRole.admin : RadioRole.crew,
      latencyMs: 0,
      signalStrength: 1,
    );
    state = state.copyWith(
      members: <CrewMember>[
        member,
        ...state.members.where(
          (existing) =>
              existing.id != member.id &&
              !(peer.isAdmin && existing.radioRole == RadioRole.admin),
        ),
      ],
    );
  }

  void _handleAudioReception(AudioReception reception) {
    if (state.isTransmitting) {
      return;
    }
    final speaker = reception.broadcast
        ? '${reception.senderName.toUpperCase()} BROADCASTING...'
        : '${reception.senderName} speaking';
    final changed = !state.isReceiving || state.activeSpeaker != speaker;
    if (changed) {
      state = state.copyWith(
        status: ConnectionStatus.receiving,
        isReceiving: true,
        activeSpeaker: speaker,
      );
      _syncOverlay();
    }
    _receiveIdleTimer?.cancel();
    _receiveIdleTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || state.isTransmitting) {
        return;
      }
      state = state.copyWith(
        status: ConnectionStatus.connected,
        isReceiving: false,
        clearActiveSpeaker: true,
      );
      _syncOverlay();
    });
  }

  void _handleCloudSignal(CloudSignal signal) {
    if (signal.roomId != state.roomId || signal.senderId == state.selfId) {
      return;
    }
    switch (signal.type) {
      case 'room.join':
        final member = CrewMember(
          id: signal.senderId,
          name: '${signal.payload['name'] ?? 'Crew'}',
          roleLabel: '${signal.payload['roleLabel'] ?? 'Crew'}',
          radioRole: RadioRole.crew,
          latencyMs: 32,
          signalStrength: 0.82,
        );
        state = state.copyWith(
          members: <CrewMember>[
            member,
            ...state.members.where((item) => item.id != member.id),
          ],
          log: _log('${member.name} joined'),
        );
      case 'ptt.start':
        final name = '${signal.payload['name'] ?? 'Crew'}';
        final broadcast = signal.payload['broadcast'] == true;
        audio.setBroadcastPriority(broadcast);
        state = state.copyWith(
          status: ConnectionStatus.receiving,
          isReceiving: true,
          activeSpeaker:
              broadcast ? 'DIRECTOR BROADCASTING...' : '$name speaking',
        );
      case 'ptt.stop':
        audio.setBroadcastPriority(false);
        state = state.copyWith(
          status: ConnectionStatus.connected,
          isReceiving: false,
          clearActiveSpeaker: true,
        );
      case 'room.permissions':
        state = state.copyWith(
          allowCrewToCrew: signal.payload['allowCrewToCrew'] == true,
        );
    }
    _syncOverlay();
  }

  void _handleOverlayEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    switch (event['action']) {
      case 'pttDown':
        startPtt(state.isAdmin ? RadioTarget.broadcast : RadioTarget.admin);
      case 'pttUp':
        stopPtt();
      case 'broadcast':
        startPtt(RadioTarget.broadcast);
      case 'broadcastDown':
        startPtt(RadioTarget.broadcast);
      case 'mute':
        state = state.copyWith(micMuted: !state.micMuted);
        _syncOverlay();
      case 'dismiss':
        if (state.isTransmitting) {
          stopPtt();
        }
      case 'open':
        break;
    }
  }

  Future<void> _connectCloudIfNeeded(RoomInvite invite) async {
    if (invite.mode != NetworkMode.cloud || invite.cloudUrl == null) {
      return;
    }
    await cloud.connect(Uri.parse(invite.cloudUrl!));
    _sendCloud('room.join', <String, dynamic>{
      'name': state.displayName,
      'roleLabel': state.isAdmin ? 'DIR' : 'Crew',
    });
  }

  void _sendCloud(String type, Map<String, dynamic> payload) {
    if (state.mode != NetworkMode.cloud || state.roomId == null) {
      return;
    }
    cloud.send(
      CloudSignal(
        type: type,
        roomId: state.roomId!,
        senderId: state.selfId,
        payload: <String, dynamic>{
          'name': state.displayName,
          ...payload,
        },
      ),
    );
  }

  Future<void> _syncOverlay() {
    return overlay.sendState(<String, Object?>{
      'connected': state.status != ConnectionStatus.idle,
      'transmitting': state.isTransmitting,
      'receiving': state.isReceiving,
      'speaker': state.activeSpeaker,
      'label': state.isAdmin ? 'DIR' : 'PTT',
      'muted': state.micMuted,
    });
  }

  List<String> _log(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    return <String>['$stamp  $message', ...state.log].take(10).toList();
  }

  String _modeLabel(NetworkMode mode) {
    return mode == NetworkMode.localWifi ? 'Local Wi-Fi' : 'Cloud';
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _cloudSub?.cancel();
    _linkSub?.cancel();
    _overlaySub?.cancel();
    _headsetSub?.cancel();
    _presenceSub?.cancel();
    _audioReceptionSub?.cancel();
    _receiveIdleTimer?.cancel();
    super.dispose();
  }
}
