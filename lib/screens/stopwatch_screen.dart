import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lap.dart';
import '../services/formatting.dart';
import '../services/lap_analysis.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/settings_data.dart';
import '../state/stopwatch_controller.dart';
import '../widgets/empty_state.dart';
import '../widgets/lap_tile.dart';
import '../widgets/session_feedback.dart';
import '../widgets/time_display.dart';

class StopwatchScreen extends StatelessWidget {
  const StopwatchScreen({
    super.key,
    required this.sessionsOpen,
    required this.onToggleSessions,
  });

  final bool sessionsOpen;
  final VoidCallback onToggleSessions;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StopwatchController>();
    final data = context.watch<AppData>();
    final settings = context.watch<SettingsData>();

    final today = studyDayFor(DateTime.now());
    final live = controller.liveUncommittedForDay(today);
    final todayTotal = data.totalForStudyDay(today) + live;

    Future<void> deleteSession(Lap session) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete session?'),
          content: Text(
            '${formatStopwatch(session.duration)} will be removed from your '
            'sessions and daily total.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        controller.deleteSession(session);
      }
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _Controls(
                  controller: controller,
                  settings: settings,
                  todayTotal: todayTotal,
                  onSession: () =>
                      recordSessionWithFeedback(context, controller),
                ),
              ),
            ),
          ),
        ),
        _SessionSidebar(
          open: sessionsOpen,
          sessions: controller.laps,
          onClose: onToggleSessions,
          onDelete: deleteSession,
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.settings,
    required this.todayTotal,
    required this.onSession,
  });

  final StopwatchController controller;
  final SettingsData settings;
  final Duration todayTotal;
  final VoidCallback onSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examDone = controller.isExam && controller.examCompleted;
    final displayDuration = controller.isExam
        ? (controller.examRemaining ?? Duration.zero)
        : controller.lapElapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeDisplay(
          duration: displayDuration,
          showMilliseconds: settings.showMilliseconds,
          showSeconds: settings.showSeconds,
          analog: settings.clockMode == ClockDisplayMode.analog,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Chip(
              avatar: const Icon(Icons.today, size: 18),
              label: Text('Today: ${formatHms(todayTotal)}'),
            ),
            if (controller.isExam)
              Chip(
                avatar: Icon(
                  examDone ? Icons.check_circle_outline : Icons.school_outlined,
                  size: 18,
                ),
                label: Text(
                  examDone
                      ? 'Exam complete'
                      : 'Exam · ${controller.examTarget?.inMinutes ?? settings.examMinutes}m',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: examDone ? controller.endExam : controller.toggle,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  examDone
                      ? Icons.check
                      : (controller.isRunning ? Icons.pause : Icons.play_arrow),
                  key: ValueKey(examDone ? 'done' : controller.isRunning),
                ),
              ),
              label: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  examDone ? 'Done' : controller.primaryLabel,
                  key: ValueKey(examDone ? 'Done' : controller.primaryLabel),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: controller.canLap ? onSession : null,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Session'),
            ),
          ],
        ),
        if (controller.isExam && !controller.isRunning) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: controller.endExam,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('End exam'),
            ),
          ),
        ],
        if (settings.clockMode == ClockDisplayMode.analog)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Text(
                controller.isExam ? 'Time remaining' : 'Time since session',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionSidebar extends StatelessWidget {
  const _SessionSidebar({
    required this.open,
    required this.sessions,
    required this.onClose,
    required this.onDelete,
  });

  final bool open;
  final List<Lap> sessions;
  final VoidCallback onClose;
  final ValueChanged<Lap> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(320.0, constraints.maxWidth * 0.82);
        return Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: width,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: open
                    ? Material(
                        key: const ValueKey<String>('session-sidebar'),
                        elevation: 10,
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 6, 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Sessions (${sessions.length})',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Hide sessions',
                                    onPressed: onClose,
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: sessions.isEmpty
                                  ? const EmptyState(
                                      icon: Icons.flag_outlined,
                                      title: 'No sessions yet',
                                      message:
                                          'Press Session while the timer '
                                          'is running.',
                                    )
                                  : _SessionList(
                                      sessions: sessions,
                                      onDelete: onDelete,
                                    ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('session-sidebar-hidden'),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.onDelete});

  final List<Lap> sessions;
  final ValueChanged<Lap> onDelete;

  @override
  Widget build(BuildContext context) {
    final highlights = computeLapHighlights(sessions);
    final tiles = [
      for (var i = sessions.length - 1; i >= 0; i--)
        _SessionEntry(
          key: ValueKey<String>(
            'session-${sessions[i].start.toIso8601String()}',
          ),
          number: i + 1,
          session: sessions[i],
          highlight: i == highlights.longestIndex
              ? LapHighlight.longest
              : (i == highlights.shortestIndex ? LapHighlight.shortest : null),
          onDelete: () => onDelete(sessions[i]),
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
      children: tiles,
    );
  }
}

class _SessionEntry extends StatelessWidget {
  const _SessionEntry({
    super.key,
    required this.number,
    required this.session,
    this.highlight,
    this.onDelete,
  });

  final int number;
  final Lap session;
  final LapHighlight? highlight;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: LapTile(
        number: number,
        lap: session,
        highlight: highlight,
        onDelete: onDelete,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
    );
  }
}
