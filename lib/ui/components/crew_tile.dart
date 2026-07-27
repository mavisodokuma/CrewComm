import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../features/room/room_models.dart';
import 'audio_meter.dart';

class CrewTile extends StatelessWidget {
  const CrewTile({
    super.key,
    required this.member,
    required this.onDirectPttDown,
    required this.onDirectPttUp,
    required this.onMute,
    required this.onKick,
    required this.onTransfer,
  });

  final CrewMember member;
  final VoidCallback onDirectPttDown;
  final VoidCallback onDirectPttUp;
  final VoidCallback onMute;
  final VoidCallback onKick;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final statusColor = member.isSpeaking
        ? AppTheme.red
        : member.isOnline
            ? AppTheme.green
            : AppTheme.muted;
    return GestureDetector(
      onLongPressStart: (_) => onDirectPttDown(),
      onLongPressEnd: (_) => onDirectPttUp(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                            color: statusColor.withOpacity(0.6), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      member.roleLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'mute':
                          onMute();
                        case 'kick':
                          onKick();
                        case 'admin':
                          onTransfer();
                      }
                    },
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'mute',
                        child: Text(member.isMuted ? 'Unmute' : 'Mute'),
                      ),
                      const PopupMenuItem(value: 'kick', child: Text('Kick')),
                      const PopupMenuItem(
                          value: 'admin', child: Text('Transfer Admin')),
                    ],
                  ),
                ],
              ),
              Text(member.name, style: const TextStyle(color: AppTheme.muted)),
              const Spacer(),
              AudioMeter(
                level: member.isMuted ? 0.05 : member.audioLevel,
                color: member.isSpeaking ? AppTheme.red : AppTheme.green,
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.network_wifi, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Text('${(member.signalStrength * 100).round()}%'),
                  const Spacer(),
                  const Icon(Icons.speed, size: 18, color: AppTheme.yellow),
                  const SizedBox(width: 6),
                  Text('${member.latencyMs} ms'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
