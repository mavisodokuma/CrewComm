import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../core/app_theme.dart';

class FloatingRadioButton extends StatefulWidget {
  const FloatingRadioButton({
    super.key,
    this.connected = true,
    this.transmitting = false,
    this.receiving = false,
    this.speaker,
    this.label = 'PTT',
    this.onPttDown,
    this.onPttUp,
    this.onBroadcast,
    this.onMute,
    this.onOpen,
  });

  final bool connected;
  final bool transmitting;
  final bool receiving;
  final String? speaker;
  final String label;
  final VoidCallback? onPttDown;
  final VoidCallback? onPttUp;
  final VoidCallback? onBroadcast;
  final VoidCallback? onMute;
  final VoidCallback? onOpen;

  @override
  State<FloatingRadioButton> createState() => _FloatingRadioButtonState();
}

class _FloatingRadioButtonState extends State<FloatingRadioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  bool _expanded = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.transmitting
        ? AppTheme.red
        : widget.receiving
            ? AppTheme.yellow
            : widget.connected
                ? AppTheme.green
                : AppTheme.muted;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            if (_expanded) ...<Widget>[
              _MiniAction(
                offset: const Offset(-58, -34),
                icon: Icons.campaign,
                onTap: widget.onBroadcast,
              ),
              _MiniAction(
                offset: const Offset(-70, 20),
                icon: Icons.mic_off,
                onTap: widget.onMute,
              ),
              _MiniAction(
                offset: const Offset(-26, 62),
                icon: Icons.open_in_full,
                onTap: widget.onOpen,
              ),
            ],
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              onLongPressStart: (_) => widget.onPttDown?.call(),
              onLongPressEnd: (_) => widget.onPttUp?.call(),
              onTapDown: (_) {
                if (!_expanded) {
                  widget.onPttDown?.call();
                }
              },
              onTapUp: (_) {
                if (!_expanded) {
                  widget.onPttUp?.call();
                }
              },
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: widget.transmitting ? 70 : 64,
                    height: widget.transmitting ? 70 : 64,
                    decoration: BoxDecoration(
                      color: AppTheme.background.withOpacity(0.82),
                      shape: BoxShape.circle,
                      border: Border.all(color: activeColor, width: 3),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: activeColor.withOpacity(
                            widget.transmitting || widget.receiving
                                ? 0.35 + (_pulse.value * 0.25)
                                : 0.24,
                          ),
                          blurRadius:
                              widget.transmitting || widget.receiving ? 22 : 10,
                          spreadRadius:
                              widget.transmitting || widget.receiving ? 5 : 1,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      widget.transmitting
                          ? Icons.graphic_eq
                          : Icons.settings_voice,
                      color: AppTheme.text,
                      size: 22,
                    ),
                    Text(
                      widget.receiving
                          ? (widget.speaker ?? 'RX')
                          : widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.offset,
    required this.icon,
    this.onTap,
  });

  final Offset offset;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.panelAlt,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.muted.withOpacity(0.45)),
          ),
          child: Icon(icon, size: 19, color: AppTheme.text),
        ),
      ),
    );
  }
}

class OverlayRadioApp extends StatelessWidget {
  const OverlayRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const OverlayRadioHost(),
    );
  }
}

class OverlayRadioHost extends StatefulWidget {
  const OverlayRadioHost({super.key});

  @override
  State<OverlayRadioHost> createState() => _OverlayRadioHostState();
}

class _OverlayRadioHostState extends State<OverlayRadioHost> {
  Map<String, dynamic> _state = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() => _state = event.cast<String, dynamic>());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: FloatingRadioButton(
          connected: _state['connected'] == true,
          transmitting: _state['transmitting'] == true,
          receiving: _state['receiving'] == true,
          speaker: _state['speaker'] as String?,
          label: '${_state['label'] ?? 'PTT'}',
          onPttDown: () => FlutterOverlayWindow.shareData(<String, String>{
            'action': 'pttDown',
          }),
          onPttUp: () => FlutterOverlayWindow.shareData(<String, String>{
            'action': 'pttUp',
          }),
          onBroadcast: () => FlutterOverlayWindow.shareData(<String, String>{
            'action': 'broadcast',
          }),
          onMute: () => FlutterOverlayWindow.shareData(<String, String>{
            'action': 'mute',
          }),
          onOpen: () => FlutterForegroundTask.launchApp(),
        ),
      ),
    );
  }
}
