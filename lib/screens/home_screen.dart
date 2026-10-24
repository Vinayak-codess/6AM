import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/fullscreen.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/settings_data.dart';
import '../state/stopwatch_controller.dart';
import '../widgets/battery_indicator.dart';
import '../widgets/current_time_label.dart';
import '../widgets/goal_reminder.dart';
import '../widgets/session_feedback.dart';
import '../widgets/session_goal_panel.dart';
import '../widgets/zen_view.dart';
import 'days_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'stopwatch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _sessionsOpen = false;
  bool _menuOpen = false;
  bool _goalOpen = false;

  bool get _onHistory => _index == 1;
  bool get _overlayOpen => _menuOpen || _goalOpen;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _closeOverlays() {
    if (_menuOpen || _goalOpen) {
      setState(() {
        _menuOpen = false;
        _goalOpen = false;
      });
    }
  }

  void _openGoal() {
    setState(() {
      _menuOpen = false;
      _goalOpen = true;
    });
  }

  void _openGoalFromReminder() {
    final settings = context.read<SettingsData>();
    if (settings.zen) {
      settings.setZen(false);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    _openGoal();
  }

  void _openSettings() {
    _closeOverlays();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
    );
  }

  void _openDays() {
    _closeOverlays();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const DaysScreen()));
  }

  Future<void> _resetCurrentSession() async {
    _closeOverlays();
    final controller = context.read<StopwatchController>();
    if (!controller.isActive) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset current session?'),
        content: const Text(
          'The timer will restart. Completed sessions stay in today\'s total.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.resetCurrentSession();
    }
  }

  Future<void> _resetAllToday() async {
    _closeOverlays();
    final controller = context.read<StopwatchController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset all sessions today?'),
        content: const Text(
          'This erases all of today\'s study time and sessions. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.resetAllSessionsToday();
    }
  }

  void _toggleSessions() {
    setState(() {
      _sessionsOpen = !_sessionsOpen;
      _menuOpen = false;
      _goalOpen = false;
    });
  }

  void _toggleExam() {
    final settings = context.read<SettingsData>();
    final controller = context.read<StopwatchController>();
    if (controller.isExam) {
      controller.endExam();
    } else if (!controller.isRunning) {
      controller.setMode(
        TimerMode.exam,
        examTarget: Duration(minutes: settings.examMinutes),
      );
      if (_onHistory) {
        setState(() => _index = 0);
      }
    }
    _closeOverlays();
  }

  void _enterZen() {
    context.read<SettingsData>().setZen(true);
    _closeOverlays();
  }

  void _switchPage() {
    setState(() {
      _index = _onHistory ? 0 : 1;
      _sessionsOpen = false;
      _menuOpen = false;
      _goalOpen = false;
    });
  }

  bool get _isTyping {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    return focusContext != null &&
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed ||
        _isTyping) {
      return false;
    }
    final key = event.logicalKey;
    final controller = context.read<StopwatchController>();
    final settings = context.read<SettingsData>();
    if (key == LogicalKeyboardKey.space) {
      controller.toggle();
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      if (settings.zen) {
        controller.lap();
      } else {
        recordSessionWithFeedback(context, controller);
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyR) {
      controller.resetCurrentSession();
      return true;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      if (settings.zen) {
        settings.setZen(false);
      } else {
        _enterZen();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.keyF) {
      toggleFullscreen();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      exitFullscreen();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsData>();
    final controller = context.watch<StopwatchController>();
    final data = context.watch<AppData>();
    final onHistory = _onHistory;
    final today = studyDayFor(DateTime.now());
    final hasTodayData =
        data.totalForStudyDay(today) > Duration.zero ||
        data.lapsForStudyDay(today).isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        settings.zen
            ? Scaffold(body: ZenView(onExit: () => settings.setZen(false)))
            : Scaffold(
                appBar: AppBar(
                  title: const Text('6AM'),
                  actions: [
                    IconButton(
                      tooltip: _overlayOpen ? 'Close menu' : 'Menu',
                      onPressed: () {
                        setState(() {
                          if (_goalOpen) {
                            _goalOpen = false;
                          } else {
                            _menuOpen = !_menuOpen;
                          }
                        });
                      },
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            RotationTransition(
                              turns: Tween<double>(
                                begin: 0.75,
                                end: 1,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Icon(
                          _overlayOpen ? Icons.close : Icons.menu,
                          key: ValueKey(_overlayOpen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                body: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.98,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: onHistory
                            ? const HistoryScreen()
                            : StopwatchScreen(
                                sessionsOpen: _sessionsOpen,
                                onToggleSessions: () => setState(
                                  () => _sessionsOpen = !_sessionsOpen,
                                ),
                              ),
                      ),
                    ),
                    const Positioned(
                      right: 16,
                      bottom: 14,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BatteryIndicator(),
                            SizedBox(width: 8),
                            CurrentTimeLabel(),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_overlayOpen,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _overlayOpen ? 1 : 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeOverlays,
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 12,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          );
                          return FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.08),
                                end: Offset.zero,
                              ).animate(curved),
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.96,
                                  end: 1,
                                ).animate(curved),
                                alignment: Alignment.topRight,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _goalOpen
                            ? SessionGoalPanel(
                                key: const ValueKey<String>('goal-panel'),
                                onClose: _closeOverlays,
                              )
                            : _menuOpen
                            ? _AppMenu(
                                key: const ValueKey<String>('app-menu'),
                                onHistory: onHistory,
                                sessionsOpen: _sessionsOpen,
                                isExam: controller.isExam,
                                examEnabled:
                                    controller.isExam || !controller.isRunning,
                                showGoal: settings.goalsEnabled,
                                hasGoal: settings.hasGoal,
                                goalDone: settings.goalDone,
                                onSessions: _toggleSessions,
                                onExam: _toggleExam,
                                onGoal: _openGoal,
                                onZen: _enterZen,
                                onDays: _openDays,
                                onSettings: _openSettings,
                                onSwitchPage: _switchPage,
                                canResetSession: controller.isActive,
                                canResetAll:
                                    controller.isActive || hasTodayData,
                                onResetSession: _resetCurrentSession,
                                onResetAll: _resetAllToday,
                              )
                            : const SizedBox.shrink(
                                key: ValueKey<String>('app-menu-hidden'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
        Positioned.fill(
          child: IgnorePointer(
            child: GoalReminderWatcher(onSetGoal: _openGoalFromReminder),
          ),
        ),
      ],
    );
  }
}

class _AppMenu extends StatelessWidget {
  const _AppMenu({
    super.key,
    required this.onHistory,
    required this.sessionsOpen,
    required this.isExam,
    required this.examEnabled,
    required this.showGoal,
    required this.hasGoal,
    required this.goalDone,
    required this.onSessions,
    required this.onExam,
    required this.onGoal,
    required this.onZen,
    required this.onDays,
    required this.onSettings,
    required this.onSwitchPage,
    required this.canResetSession,
    required this.canResetAll,
    required this.onResetSession,
    required this.onResetAll,
  });

  final bool onHistory;
  final bool sessionsOpen;
  final bool isExam;
  final bool examEnabled;
  final bool showGoal;
  final bool hasGoal;
  final bool goalDone;
  final VoidCallback onSessions;
  final VoidCallback onExam;
  final VoidCallback onGoal;
  final VoidCallback onZen;
  final VoidCallback onDays;
  final VoidCallback onSettings;
  final VoidCallback onSwitchPage;
  final bool canResetSession;
  final bool canResetAll;
  final VoidCallback onResetSession;
  final VoidCallback onResetAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Material(
        elevation: 16,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!onHistory)
                _MenuItem(
                  icon: Icons.flag_outlined,
                  label: sessionsOpen ? 'Hide sessions' : 'Show sessions',
                  onTap: onSessions,
                ),
              _MenuItem(
                icon: Icons.school_outlined,
                label: isExam ? 'End exam' : 'Exam',
                onTap: examEnabled ? onExam : null,
              ),
              if (showGoal)
                _MenuItem(
                  icon: goalDone ? Icons.task_alt : Icons.flag_outlined,
                  label: !hasGoal
                      ? 'Session goal'
                      : goalDone
                      ? 'Session goal · Done'
                      : 'Session goal · Set',
                  onTap: onGoal,
                ),
              Divider(
                height: 9,
                indent: 12,
                endIndent: 12,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _MenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'Days',
                onTap: onDays,
              ),
              _MenuItem(
                icon: Icons.fullscreen,
                label: 'Zen mode',
                onTap: onZen,
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: onSettings,
              ),
              _MenuItem(
                icon: onHistory
                    ? Icons.timer_outlined
                    : Icons.insights_outlined,
                label: onHistory ? 'Stopwatch' : 'History',
                onTap: onSwitchPage,
              ),
              Divider(
                height: 9,
                indent: 12,
                endIndent: 12,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              _MenuItem(
                icon: Icons.restart_alt,
                label: 'Reset current session',
                onTap: canResetSession ? onResetSession : null,
                destructive: true,
              ),
              _MenuItem(
                icon: Icons.delete_sweep_outlined,
                label: 'Reset all sessions today',
                onTap: canResetAll ? onResetAll : null,
                destructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;
    final color = enabled
        ? (destructive ? scheme.error : scheme.onSurface)
        : scheme.onSurface.withValues(alpha: 0.35);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: enabled
                  ? (destructive ? scheme.error : scheme.primary)
                  : color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
