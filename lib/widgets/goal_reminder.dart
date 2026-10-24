import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_data.dart';
import '../state/stopwatch_controller.dart';

class GoalReminderWatcher extends StatefulWidget {
  const GoalReminderWatcher({super.key, this.onSetGoal});

  final VoidCallback? onSetGoal;

  @override
  State<GoalReminderWatcher> createState() => _GoalReminderWatcherState();
}

class _GoalReminderWatcherState extends State<GoalReminderWatcher> {
  static const Duration _delay = Duration(seconds: 30);

  StopwatchController? _controller;
  SettingsData? _settings;
  Timer? _timer;
  bool _notified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<StopwatchController>();
    final settings = context.read<SettingsData>();
    if (identical(controller, _controller) && identical(settings, _settings)) {
      return;
    }
    _controller?.removeListener(_evaluate);
    _settings?.removeListener(_evaluate);
    _controller = controller;
    _settings = settings;
    controller.addListener(_evaluate);
    settings.addListener(_evaluate);
    _evaluate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.removeListener(_evaluate);
    _settings?.removeListener(_evaluate);
    super.dispose();
  }

  void _evaluate() {
    final controller = _controller;
    final settings = _settings;
    if (!mounted || controller == null || settings == null) {
      return;
    }
    if (!controller.isRunning) {
      _notified = false;
    }
    final shouldRemind =
        controller.isRunning &&
        settings.goalsEnabled &&
        settings.goalReminder &&
        !settings.hasGoal &&
        !_notified;
    if (!shouldRemind) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer(_delay, _remind);
  }

  void _remind() {
    _timer = null;
    final controller = _controller;
    final settings = _settings;
    if (!mounted || controller == null || settings == null) {
      return;
    }
    if (!controller.isRunning ||
        !settings.goalsEnabled ||
        !settings.goalReminder ||
        settings.hasGoal ||
        _notified) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    _notified = true;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text('30 seconds in. Set your session goal.'),
              ),
            ],
          ),
          action: widget.onSetGoal == null
              ? null
              : SnackBarAction(label: 'Set goal', onPressed: widget.onSetGoal!),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
