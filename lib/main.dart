import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'ui/components/floating_radio_button.dart';
import 'ui/screens/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CrewCommApp()));
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayRadioApp());
}

class CrewCommApp extends StatelessWidget {
  const CrewCommApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrewComm',
      theme: AppTheme.dark(),
      home: const LobbyScreen(),
    );
  }
}
