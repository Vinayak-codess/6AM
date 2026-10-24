import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/formatting.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/settings_data.dart';
import '../state/stopwatch_controller.dart';
import 'time_display.dart';

class ZenView extends StatelessWidget {
  const ZenView({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final controller = context.watch<StopwatchController>();
    final settings = context.watch<SettingsData>();
    final theme = Theme.of(context);
    final today = studyDayFor(DateTime.now());
    final total =
        data.totalForStudyDay(today) + controller.liveUncommittedForDay(today);

    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TODAY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 6,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatHms(total),
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (settings.zenShowSessionTimer) ...[
                  if (controller.isActive) ...[
                    const SizedBox(height: 26),
                    TimeDisplay(
                      duration: controller.isExam
                          ? (controller.examRemaining ?? Duration.zero)
                          : controller.lapElapsed,
                      fontSize: 34,
                      showMilliseconds: settings.showMilliseconds,
                      showSeconds: settings.showSeconds,
                      analog: false,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.isRunning ? 'Studying' : 'Paused',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 2,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'Idle',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            tooltip: 'Exit zen mode',
            onPressed: onExit,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
