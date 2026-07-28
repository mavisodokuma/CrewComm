import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../features/room/room_controller.dart';
import '../../features/room/room_models.dart';
import 'admin_dashboard_screen.dart';
import 'crew_screen.dart';
import 'scanner_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final _roomName = TextEditingController(text: 'Production A');
  final _displayName = TextEditingController();
  final _cloudUrl = TextEditingController(text: 'wss://crewcomm.example/ws');
  NetworkMode _mode = NetworkMode.localWifi;

  @override
  void dispose() {
    _roomName.dispose();
    _displayName.dispose();
    _cloudUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomControllerProvider);
    final controller = ref.read(roomControllerProvider.notifier);
    if (_displayName.text.isEmpty) {
      _displayName.text = room.displayName;
    }
    if (room.status == ConnectionStatus.connected ||
        room.status == ConnectionStatus.transmitting ||
        room.status == ConnectionStatus.receiving) {
      return room.isAdmin ? const AdminDashboardScreen() : const CrewScreen();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('CrewComm'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Show floating PTT',
            icon: const Icon(Icons.radio_button_checked),
            onPressed: controller.showOverlay,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: <Widget>[
            const _Header(),
            const SizedBox(height: 22),
            TextField(
              controller: _displayName,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.badge),
              ),
              onChanged: controller.setDisplayName,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _roomName,
              decoration: const InputDecoration(
                labelText: 'Room name',
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<NetworkMode>(
              segments: const <ButtonSegment<NetworkMode>>[
                ButtonSegment(
                  value: NetworkMode.localWifi,
                  label: Text('Local Wi-Fi'),
                  icon: Icon(Icons.wifi),
                ),
                ButtonSegment(
                  value: NetworkMode.cloud,
                  label: Text('Cloud'),
                  icon: Icon(Icons.cloud),
                ),
              ],
              selected: <NetworkMode>{_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            if (_mode == NetworkMode.cloud) ...<Widget>[
              const SizedBox(height: 14),
              TextField(
                controller: _cloudUrl,
                decoration: const InputDecoration(
                  labelText: 'WebSocket signaling URL',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add_circle),
              label: const Text('Create Admin Room'),
              onPressed: () => controller.createRoom(
                roomName: _roomName.text,
                mode: _mode,
                cloudUrl: _mode == NetworkMode.cloud ? _cloudUrl.text : null,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Crew Invite'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScannerScreen(),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (room.discoveredRooms.isNotEmpty)
              Text(
                'Local Rooms',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            for (final discovered in room.discoveredRooms)
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.wifi_tethering, color: AppTheme.green),
                  title: Text(discovered.invite.roomName),
                  subtitle: Text(
                      '${discovered.address}  ${discovered.invite.roomId}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.joinFromInvite(discovered.invite),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.green.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/branding/crewcomm-logo-3d.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Live Production Radio',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Offline-first PTT for directors, camera, audio, and stage crew.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
