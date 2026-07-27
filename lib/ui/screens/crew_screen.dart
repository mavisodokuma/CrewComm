import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../features/room/room_controller.dart';
import '../../features/room/room_models.dart';
import '../components/ptt_button.dart';
import '../components/status_led.dart';

class CrewScreen extends ConsumerWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(roomControllerProvider);
    final controller = ref.read(roomControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(room.roomName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Floating PTT',
            icon: const Icon(Icons.radio_button_checked),
            onPressed: controller.showOverlay,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                        ? 'TRANSMITTING'
                        : room.isReceiving
                            ? 'RECEIVING'
                            : 'STANDBY',
                  ),
                  const Spacer(),
                  Switch(
                    value: room.handsFree,
                    onChanged: (_) => controller.toggleHandsFree(),
                  ),
                  const Text('Latch'),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: room.isReceiving
                      ? AppTheme.yellow.withOpacity(0.13)
                      : AppTheme.panel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        room.isReceiving ? AppTheme.yellow : AppTheme.panelAlt,
                  ),
                ),
                child: Text(
                  room.activeSpeaker ?? 'Director channel clear',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: room.isReceiving ? AppTheme.yellow : AppTheme.muted,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              PttButton(
                label: room.handsFree && room.isTransmitting
                    ? 'LATCHED ON'
                    : 'PUSH TO TALK',
                active: room.isTransmitting,
                onDown: () {
                  if (room.handsFree) {
                    if (room.isTransmitting) {
                      controller.stopPtt();
                    } else {
                      controller.startPtt(RadioTarget.admin);
                    }
                    return;
                  }
                  controller.startPtt(RadioTarget.admin);
                },
                onUp: () {
                  if (!room.handsFree) {
                    controller.stopPtt();
                  }
                },
              ),
              const Spacer(),
              Text(
                room.canCrewTalk
                    ? 'Crew talk enabled'
                    : 'Listen only: director controls talkback',
                style: const TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
