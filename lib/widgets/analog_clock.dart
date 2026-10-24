import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnalogClock extends StatelessWidget {
  const AnalogClock({
    super.key,
    required this.duration,
    this.size = 210,
    this.showSeconds = true,
  });

  final Duration duration;
  final double size;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AnalogClockPainter(
          duration: duration,
          showSeconds: showSeconds,
          faceColor: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          outlineColor: scheme.outlineVariant.withValues(alpha: 0.6),
          tickColor: scheme.onSurfaceVariant,
          handColor: scheme.onSurface,
          accentColor: scheme.primary,
        ),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  const _AnalogClockPainter({
    required this.duration,
    required this.showSeconds,
    required this.faceColor,
    required this.outlineColor,
    required this.tickColor,
    required this.handColor,
    required this.accentColor,
  });

  final Duration duration;
  final bool showSeconds;
  final Color faceColor;
  final Color outlineColor;
  final Color tickColor;
  final Color handColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    canvas.drawCircle(center, radius, Paint()..color = faceColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final angle = (i / 60) * 2 * math.pi - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final inner =
          center +
          Offset(math.cos(angle), math.sin(angle)) *
              (radius - (major ? 14 : 7));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = tickColor.withValues(alpha: major ? 0.9 : 0.35)
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    final millis = duration.inMilliseconds;
    final hours = (millis % const Duration(hours: 12).inMilliseconds) / 3600000;
    final minutes = (millis % const Duration(hours: 1).inMilliseconds) / 60000;
    final seconds = (millis % 60000) / 1000;

    _hand(
      canvas,
      center,
      -math.pi / 2 + (hours / 12) * 2 * math.pi,
      radius * 0.5,
      6,
      handColor,
    );
    _hand(
      canvas,
      center,
      -math.pi / 2 + (minutes / 60) * 2 * math.pi,
      radius * 0.72,
      4,
      handColor,
    );
    if (showSeconds) {
      _hand(
        canvas,
        center,
        -math.pi / 2 + (seconds / 60) * 2 * math.pi,
        radius * 0.84,
        1.8,
        accentColor,
      );
    }
    canvas.drawCircle(center, 4, Paint()..color = accentColor);
    canvas.drawCircle(center, 1.8, Paint()..color = handColor);
  }

  void _hand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    double width,
    Color color,
  ) {
    final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AnalogClockPainter oldDelegate) =>
      oldDelegate.duration != duration ||
      oldDelegate.showSeconds != showSeconds ||
      oldDelegate.faceColor != faceColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.handColor != handColor ||
      oldDelegate.accentColor != accentColor;
}
