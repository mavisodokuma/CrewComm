import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../features/room/room_controller.dart';
import '../../features/room/room_models.dart';
import '../components/crew_tile.dart';
import '../components/ptt_button.dart';
import '../components/status_led.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomControllerProvider);
    final controller = ref.read(roomControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(room.roomName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Invite',
            icon: const Icon(Icons.qr_code_2),
            onPressed: room.invite == null
                ? null
                : () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: AppTheme.panel,
                      builder: (_) => _InviteSheet(invite: room.invite!),
                    ),
          ),
          IconButton(
            tooltip: 'Floating PTT',
            icon: const Icon(Icons.radio),
            onPressed: controller.showOverlay,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      StatusLed(
                        color: room.isTransmitting
                            ? AppTheme.red
                            : room.isReceiving
                                ? AppTheme.yellow
                                : AppTheme.green,
                        label: room.isTransmitting
                            ? 'LIVE TX'
                            : room.isReceiving
                                ? 'RX'
                                : 'CONNECTED',
                      ),
                      const Spacer(),
                      Text(
                        room.mode == NetworkMode.localWifi
                            ? 'LOCAL OFFLINE'
                            : 'CLOUD FALLBACK',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.panel,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: SwitchListTile(
                            value: room.allowCrewToCrew,
                            onChanged: controller.toggleCrewTalk,
                            title: const Text('Crew-to-Crew'),
                            subtitle:
                                const Text('Disable for director listen-only'),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            value: room.masterMuted,
                            onChanged: controller.toggleMasterMute,
                            title: const Text('Master Mute'),
                            subtitle:
                                const Text('Silence outgoing room traffic'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 178,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: room.members.length,
                itemBuilder: (context, index) {
                  final member = room.members[index];
                  return CrewTile(
                    member: member,
                    onDirectPttDown: () => controller.startPtt(
                      RadioTarget.direct,
                      peerId: member.id,
                    ),
                    onDirectPttUp: controller.stopPtt,
                    onMute: () => controller.toggleMemberMute(member.id),
                    onKick: () => controller.kickMember(member.id),
                    onTransfer: () => controller.transferAdmin(member.id),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(color: AppTheme.background),
              child: PttButton(
                label: 'BROADCAST ALL',
                active: room.isBroadcasting,
                icon: Icons.campaign,
                size: 170,
                onDown: () => controller.startPtt(RadioTarget.broadcast),
                onUp: controller.stopPtt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.invite});

  final RoomInvite invite;

  @override
  Widget build(BuildContext context) {
    final uri = invite.toUri().toString();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QrImageView(
              data: uri,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 16),
            SelectableText(
              uri,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.text),
            ),
          ],
        ),
      ),
    );
  }
}
