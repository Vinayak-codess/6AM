import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/formatting.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/stopwatch_controller.dart';
import '../widgets/daily_chart.dart';
import '../widgets/empty_state.dart';

enum _ChartRange { today, sevenDays, thirtyDays }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _ChartRange _range = _ChartRange.sevenDays;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final controller = context.watch<StopwatchController>();
    final theme = Theme.of(context);
    final today = studyDayFor(DateTime.now());

    Duration totalFor(DateTime day) =>
        data.totalForStudyDay(day) + controller.liveUncommittedForDay(day);

    Duration totalForLastDays(int days) {
      var sum = Duration.zero;
      for (var i = 0; i < days; i++) {
        sum += totalFor(addStudyDays(today, -i));
      }
      return sum;
    }

    List<int> todayHourBuckets() {
      final stored = data.hourlyForStudyDay(today);
      final buckets = List<int>.filled(studyDayHours, 0);
      for (var i = 0; i < studyDayHours && i < stored.length; i++) {
        buckets[i] = stored[i];
      }
      final since = controller.runningSince;
      final live = controller.liveUncommitted;
      if (since != null && live > Duration.zero) {
        forEachHourChunk(since, live, (moment, chunk) {
          if (studyDayFor(moment) == today) {
            buckets[studyHourIndex(moment)] += chunk.inMilliseconds;
          }
        });
      }
      return buckets;
    }

    final hasData = data.hasAnySavedTime || controller.isActive;
    if (!hasData) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No study time yet',
        message:
            'Start the stopwatch and your daily totals will show up '
            'here.',
      );
    }

    final spanDays = _range == _ChartRange.thirtyDays ? 30 : 7;
    final chartDays = [
      for (var i = spanDays - 1; i >= 0; i--) addStudyDays(today, -i),
    ];
    final chartTotals = [for (final day in chartDays) totalFor(day)];

    final cards = Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.today,
            label: 'Today',
            value: formatHoursMinutes(totalFor(today)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.date_range,
            label: 'This week',
            value: formatHoursMinutes(totalForLastDays(7)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_month,
            label: 'Last 30 days',
            value: formatHoursMinutes(totalForLastDays(30)),
          ),
        ),
      ],
    );

    Widget chartCard({required bool expand}) {
      final isToday = _range == _ChartRange.today;
      final chart = isToday
          ? TodayChart(hourMillis: todayHourBuckets())
          : DailyChart(
              days: chartDays,
              totals: chartTotals,
              spanDays: spanDays,
            );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? 'Today' : 'Daily total',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SegmentedButton<_ChartRange>(
                    segments: const [
                      ButtonSegment(
                        value: _ChartRange.today,
                        label: Text('Today'),
                      ),
                      ButtonSegment(
                        value: _ChartRange.sevenDays,
                        label: Text('7 days'),
                      ),
                      ButtonSegment(
                        value: _ChartRange.thirtyDays,
                        label: Text('30 days'),
                      ),
                    ],
                    selected: {_range},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _range = selection.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (expand)
                Expanded(child: chart)
              else
                SizedBox(height: 220, child: chart),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cards,
                const SizedBox(height: 16),
                Expanded(child: chartCard(expand: true)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
          children: [
            cards,
            const SizedBox(height: 12),
            chartCard(expand: false),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
