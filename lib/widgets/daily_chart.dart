import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/formatting.dart';
import '../services/study_day.dart';

({double maxY, double interval}) _axisBounds(double maxHours) {
  if (maxHours <= 0) {
    return (maxY: 1, interval: 0.25);
  }
  final padded = maxHours * 1.15;
  const steps = [0.1, 0.25, 0.5, 1.0, 2.0, 2.5, 5.0, 10.0, 20.0, 50.0, 100.0];
  var interval = steps.last;
  for (final step in steps) {
    if (step >= padded / 4) {
      interval = step;
      break;
    }
  }
  final maxY = (padded / interval).ceilToDouble() * interval;
  return (maxY: maxY, interval: interval);
}

class DailyChart extends StatelessWidget {
  const DailyChart({
    super.key,
    required this.days,
    required this.totals,
    this.spanDays = 7,
  });

  final List<DateTime> days;
  final List<Duration> totals;
  final int spanDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hours = [for (final total in totals) total.inMilliseconds / 3600000];
    final maxHours = hours.fold<double>(0, (p, h) => h > p ? h : p);
    final bounds = _axisBounds(maxHours);
    final maxY = bounds.maxY;
    final yInterval = bounds.interval;

    final spots = [
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), hours[i]),
    ];
    final showEvery = spanDays > 7 ? (spanDays / 6).ceil() : 1;

    return LineChart(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                    meta,
                    distanceFromEdge: 2,
                  ),
                  child: Text(
                    formatAxisHours(value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final isLast = index == days.length - 1;
                if (!isLast && index % showEvery != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    formatChartAxisDay(days[index], monthly: spanDays > 7),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                LineTooltipItem(
                  '${formatChartDay(days[spot.x.round()])}\n'
                  '${formatHms(totals[spot.x.round()])}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            barWidth: 2.5,
            isCurved: false,
            isStrokeCapRound: true,
            color: scheme.primary,
            dotData: FlDotData(
              show: days.length <= 14,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: scheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.25),
                  scheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TodayChart extends StatelessWidget {
  const TodayChart({super.key, required this.hourMillis});

  final List<int> hourMillis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spots = <FlSpot>[const FlSpot(0, 0)];
    var runningMs = 0;
    for (var hour = 0; hour < studyDayHours; hour++) {
      runningMs += hour < hourMillis.length ? hourMillis[hour] : 0;
      spots.add(FlSpot((hour + 1).toDouble(), runningMs / 3600000));
    }
    final maxHours = runningMs / 3600000;
    final bounds = _axisBounds(maxHours);
    final maxY = bounds.maxY;
    final yInterval = bounds.interval;

    return LineChart(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      LineChartData(
        minX: 0,
        maxX: studyDayHours.toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                    meta,
                    distanceFromEdge: 2,
                  ),
                  child: Text(
                    formatAxisHours(value),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 4,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index > studyDayHours || index % 4 != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _hourLabel((6 + index) % 24),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                _todayTooltipItem(spot, hourMillis, scheme),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            barWidth: 2.5,
            isCurved: false,
            isStrokeCapRound: true,
            color: scheme.primary,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: index % 4 == 0 ? 3 : 2,
                color: scheme.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.primary.withValues(alpha: 0.25),
                  scheme.primary.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _hourLabel(int hour) {
  final h = hour % 24;
  if (h == 0) {
    return '12 AM';
  }
  if (h == 12) {
    return '12 PM';
  }
  return h < 12 ? '$h AM' : '${h - 12} PM';
}

LineTooltipItem _todayTooltipItem(
  LineBarSpot spot,
  List<int> hourMillis,
  ColorScheme scheme,
) {
  final x = spot.x.round();
  final total = Duration(milliseconds: (spot.y * 3600000).round());
  final hourIndex = x - 1;
  final hourMillisValue = hourIndex >= 0 && hourIndex < hourMillis.length
      ? hourMillis[hourIndex]
      : 0;
  final text = StringBuffer('${_hourLabel((6 + x) % 24)}\n')
    ..write('${formatHms(total)} total');
  if (hourMillisValue > 0) {
    text.write(
      '\n+${formatHms(Duration(milliseconds: hourMillisValue))} this hour',
    );
  }
  return LineTooltipItem(
    text.toString(),
    TextStyle(
      color: scheme.onInverseSurface,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
  );
}
