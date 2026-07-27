import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AudioMeter extends StatelessWidget {
  const AudioMeter(
      {super.key, required this.level, this.color = AppTheme.green});

  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = level.clamp(0.05, 1).toDouble();
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List<Widget>.generate(9, (index) {
          final barLevel = (index + 1) / 9;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: FractionallySizedBox(
                heightFactor: clamped >= barLevel ? barLevel : 0.18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: clamped >= barLevel
                        ? color
                        : AppTheme.muted.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
