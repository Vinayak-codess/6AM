import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/formatting.dart';
import '../services/fullscreen.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/stopwatch_controller.dart';
import '../widgets/empty_state.dart';

class DaysScreen extends StatelessWidget {
  const DaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final controller = context.watch<StopwatchController>();
    final theme = Theme.of(context);
    final today = studyDayFor(DateTime.now());

    final totals = <DateTime, Duration>{
      for (final entry in data.daysNewestFirst) entry.key: entry.value,
    };
    for (final day in data.sessionDays) {
      totals.putIfAbsent(day, () => Duration.zero);
    }
    final live = controller.liveUncommittedForDay(today);
    if (live > Duration.zero) {
      totals[today] = (totals[today] ?? Duration.zero) + live;
    }
    final days = totals.keys.toList()..sort((a, b) => b.compareTo(a));

    int sessionsFor(DateTime day) =>
        data.lapsForStudyDay(day).length +
        (day == today ? controller.laps.length : 0);

    return CallbackShortcuts(
      bindings: fullscreenShortcuts(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('Days')),
          body: days.isEmpty
              ? const EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No study days yet',
                  message: 'Days appear here once you start studying.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: days.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final count = sessionsFor(day);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            '${day.day}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(_dayLabel(day, today)),
                        subtitle: Text(
                          count == 1 ? '1 session' : '$count sessions',
                        ),
                        trailing: Text(
                          formatHms(totals[day] ?? Duration.zero),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

String _dayLabel(DateTime day, DateTime today) {
  if (day == today) {
    return 'Today';
  }
  if (day == addStudyDays(today, -1)) {
    return 'Yesterday';
  }
  return formatDayLabel(day);
}
