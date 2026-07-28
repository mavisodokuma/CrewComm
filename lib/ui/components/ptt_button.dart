import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.label,
    required this.active,
    required this.onDown,
    required this.onUp,
    this.size = 220,
    this.icon = Icons.mic,
  });

  final String label;
  final bool active;
  final double size;
  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => widget.onDown(),
      onPointerUp: (_) => widget.onUp(),
      onPointerCancel: (_) => widget.onUp(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = widget.active ? 8 + _controller.value * 14 : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.active ? widget.size + 12 : widget.size,
            height: widget.active ? widget.size + 12 : widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.active ? AppTheme.red : AppTheme.panelAlt,
              border: Border.all(
                color: widget.active ? AppTheme.red : AppTheme.green,
                width: 4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (widget.active ? AppTheme.red : AppTheme.green)
                      .withOpacity(widget.active ? 0.7 : 0.25),
                  blurRadius: 18 + pulse,
                  spreadRadius: pulse / 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(widget.icon, size: 58, color: AppTheme.text),
            const SizedBox(height: 12),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
