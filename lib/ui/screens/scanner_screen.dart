import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../features/room/room_controller.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(roomControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Invite')),
      body: MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes
              .map((barcode) => barcode.rawValue)
              .whereType<String>()
              .firstOrNull;
          if (value == null) {
            return;
          }
          final uri = Uri.tryParse(value);
          if (uri == null) {
            return;
          }
          controller.joinFromUri(uri);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
