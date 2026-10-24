import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

class BatteryIndicator extends StatefulWidget {
  const BatteryIndicator({
    super.key,
    this.refreshInterval = const Duration(seconds: 30),
  });

  final Duration refreshInterval;

  @override
  State<BatteryIndicator> createState() => _BatteryIndicatorState();
}

class _BatteryIndicatorState extends State<BatteryIndicator> {
  static const List<IconData> _levelIcons = [
    Icons.battery_0_bar,
    Icons.battery_1_bar,
    Icons.battery_2_bar,
    Icons.battery_3_bar,
    Icons.battery_4_bar,
    Icons.battery_5_bar,
    Icons.battery_6_bar,
  ];

  final Battery _battery = Battery();
  Timer? _timer;
  int _level = -1;
  bool _pluggedIn = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    int level;
    bool pluggedIn;
    try {
      level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      pluggedIn =
          state == BatteryState.charging ||
          state == BatteryState.full ||
          state == BatteryState.connectedNotCharging;
    } catch (_) {
      level = -1;
      pluggedIn = false;
    }
    if (!mounted || (level == _level && pluggedIn == _pluggedIn)) {
      return;
    }
    setState(() {
      _level = level;
      _pluggedIn = pluggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_level < 0) {
      return const SizedBox.shrink();
    }
    final index = (_level * 7 / 100).floor();
    final low = _level <= 15 && !_pluggedIn;
    final color = low ? scheme.error : scheme.onSurfaceVariant;
    final icon = _pluggedIn
        ? Icons.battery_charging_full
        : (index >= _levelIcons.length
              ? Icons.battery_full
              : _levelIcons[index]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$_level%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
