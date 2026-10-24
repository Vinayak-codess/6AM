import 'package:flutter/material.dart';

import '../services/formatting.dart';
import 'analog_clock.dart';

class TimeDisplay extends StatelessWidget {
  const TimeDisplay({
    super.key,
    required this.duration,
    this.fontSize = 64,
    this.showMilliseconds = true,
    this.showSeconds = true,
    this.analog = false,
  });

  final Duration duration;
  final double fontSize;
  final bool showMilliseconds;
  final bool showSeconds;
  final bool analog;

  @override
  Widget build(BuildContext context) {
    if (analog) {
      return Center(
        child: AnalogClock(duration: duration, showSeconds: showSeconds),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        formatTimer(
          duration,
          showMilliseconds: showMilliseconds,
          showSeconds: showSeconds,
        ),
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
