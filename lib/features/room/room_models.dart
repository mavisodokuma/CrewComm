import 'dart:convert';

enum NetworkMode { localWifi, cloud }

enum RadioRole { admin, crew }

enum RadioTarget { admin, broadcast, direct }

enum ConnectionStatus { idle, discovering, connected, transmitting, receiving }

class RoomInvite {
  const RoomInvite({
    required this.roomId,
    required this.roomName,
    required this.mode,
    this.host,
    this.port,
    this.cloudUrl,
  });

  final String roomId;
  final String roomName;
  final NetworkMode mode;
  final String? host;
  final int? port;
  final String? cloudUrl;

  Uri toUri() => Uri(
        scheme: 'crewcomm',
        host: 'room',
        queryParameters: <String, String>{
          'id': roomId,
          'name': roomName,
          'mode': mode.name,
          if (host != null) 'host': host!,
          if (port != null) 'port': '$port',
          if (cloudUrl != null) 'cloud': cloudUrl!,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'roomId': roomId,
        'roomName': roomName,
        'mode': mode.name,
        'host': host,
        'port': port,
        'cloudUrl': cloudUrl,
      };

  static RoomInvite fromUri(Uri uri) {
    final params = uri.queryParameters;
    return RoomInvite(
      roomId: params['id'] ?? '',
      roomName: params['name'] ?? 'Crew Room',
      mode: NetworkMode.values.firstWhere(
        (mode) => mode.name == params['mode'],
        orElse: () => NetworkMode.localWifi,
      ),
      host: params['host'],
      port: int.tryParse(params['port'] ?? ''),
      cloudUrl: params['cloud'],
    );
  }

  static RoomInvite fromJson(Map<String, dynamic> json) => RoomInvite(
        roomId: json['roomId'] as String,
        roomName: json['roomName'] as String,
        mode: NetworkMode.values.firstWhere(
          (mode) => mode.name == json['mode'],
          orElse: () => NetworkMode.localWifi,
        ),
        host: json['host'] as String?,
        port: json['port'] as int?,
        cloudUrl: json['cloudUrl'] as String?,
      );

  @override
  String toString() => jsonEncode(toJson());
}

class DiscoveredRoom {
  const DiscoveredRoom({
    required this.invite,
    required this.address,
    required this.lastSeen,
  });

  final RoomInvite invite;
  final String address;
  final DateTime lastSeen;
}

class CrewMember {
  const CrewMember({
    required this.id,
    required this.name,
    required this.roleLabel,
    required this.radioRole,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isOnline = true,
    this.signalStrength = 1,
    this.latencyMs = 0,
    this.audioLevel = 0,
  });

  final String id;
  final String name;
  final String roleLabel;
  final RadioRole radioRole;
  final bool isMuted;
  final bool isSpeaking;
  final bool isOnline;
  final double signalStrength;
  final int latencyMs;
  final double audioLevel;

  CrewMember copyWith({
    String? id,
    String? name,
    String? roleLabel,
    RadioRole? radioRole,
    bool? isMuted,
    bool? isSpeaking,
    bool? isOnline,
    double? signalStrength,
    int? latencyMs,
    double? audioLevel,
  }) {
    return CrewMember(
      id: id ?? this.id,
      name: name ?? this.name,
      roleLabel: roleLabel ?? this.roleLabel,
      radioRole: radioRole ?? this.radioRole,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isOnline: isOnline ?? this.isOnline,
      signalStrength: signalStrength ?? this.signalStrength,
      latencyMs: latencyMs ?? this.latencyMs,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }
}

class RoomState {
  const RoomState({
    required this.selfId,
    required this.displayName,
    this.roomId,
    this.roomName = 'Crew Comms',
    this.mode = NetworkMode.localWifi,
    this.role = RadioRole.crew,
    this.status = ConnectionStatus.idle,
    this.allowCrewToCrew = true,
    this.masterMuted = false,
    this.handsFree = false,
    this.micMuted = false,
    this.isTransmitting = false,
    this.isBroadcasting = false,
    this.isReceiving = false,
    this.activeSpeaker,
    this.selectedDirectPeerId,
    this.invite,
    this.discoveredRooms = const <DiscoveredRoom>[],
    this.members = const <CrewMember>[],
    this.log = const <String>[],
  });

  final String selfId;
  final String displayName;
  final String? roomId;
  final String roomName;
  final NetworkMode mode;
  final RadioRole role;
  final ConnectionStatus status;
  final bool allowCrewToCrew;
  final bool masterMuted;
  final bool handsFree;
  final bool micMuted;
  final bool isTransmitting;
  final bool isBroadcasting;
  final bool isReceiving;
  final String? activeSpeaker;
  final String? selectedDirectPeerId;
  final RoomInvite? invite;
  final List<DiscoveredRoom> discoveredRooms;
  final List<CrewMember> members;
  final List<String> log;

  bool get isAdmin => role == RadioRole.admin;
  bool get canCrewTalk => isAdmin || allowCrewToCrew;

  RoomState copyWith({
    String? selfId,
    String? displayName,
    String? roomId,
    String? roomName,
    NetworkMode? mode,
    RadioRole? role,
    ConnectionStatus? status,
    bool? allowCrewToCrew,
    bool? masterMuted,
    bool? handsFree,
    bool? micMuted,
    bool? isTransmitting,
    bool? isBroadcasting,
    bool? isReceiving,
    String? activeSpeaker,
    bool clearActiveSpeaker = false,
    String? selectedDirectPeerId,
    bool clearDirectPeer = false,
    RoomInvite? invite,
    bool clearInvite = false,
    List<DiscoveredRoom>? discoveredRooms,
    List<CrewMember>? members,
    List<String>? log,
  }) {
    return RoomState(
      selfId: selfId ?? this.selfId,
      displayName: displayName ?? this.displayName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      mode: mode ?? this.mode,
      role: role ?? this.role,
      status: status ?? this.status,
      allowCrewToCrew: allowCrewToCrew ?? this.allowCrewToCrew,
      masterMuted: masterMuted ?? this.masterMuted,
      handsFree: handsFree ?? this.handsFree,
      micMuted: micMuted ?? this.micMuted,
      isTransmitting: isTransmitting ?? this.isTransmitting,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isReceiving: isReceiving ?? this.isReceiving,
      activeSpeaker:
          clearActiveSpeaker ? null : activeSpeaker ?? this.activeSpeaker,
      selectedDirectPeerId: clearDirectPeer
          ? null
          : selectedDirectPeerId ?? this.selectedDirectPeerId,
      invite: clearInvite ? null : invite ?? this.invite,
      discoveredRooms: discoveredRooms ?? this.discoveredRooms,
      members: members ?? this.members,
      log: log ?? this.log,
    );
  }
}
