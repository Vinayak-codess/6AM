import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/main.dart';
import 'package:sixam/services/storage.dart';
import 'package:sixam/services/study_day.dart';
import 'package:sixam/state/app_data.dart';
import 'package:sixam/state/settings_data.dart';
import 'package:sixam/widgets/daily_chart.dart';
import 'package:sixam/widgets/lap_tile.dart';
import 'package:sixam/widgets/time_display.dart';

Future<AppData> buildData([Storage? storage]) async {
  final data = AppData(storage ?? InMemoryStorage());
  await data.load();
  return data;
}

Future<SettingsData> buildSettings([Storage? storage]) async {
  final settings = SettingsData(storage ?? InMemoryStorage());
  await settings.load();
  return settings;
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

Future<void> tapMenu(WidgetTester tester, String label) async {
  await openMenu(tester);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('space toggles the stopwatch', (tester) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    expect(find.text('00:00:00.00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.text('No sessions yet'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pause'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pause'), findsNothing);

    await unmount(tester);
  });

  testWidgets('session sidebar is collapsed by default and toggles', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Show sessions');
    expect(find.text('Sessions (0)'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(find.text('Sessions (1)'), findsOneWidget);
    expect(find.byType(LapTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet'), findsNothing);
    expect(find.text('Sessions (1)'), findsNothing);

    await openMenu(tester);
    expect(find.text('Show sessions'), findsOneWidget);
    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();

    await unmount(tester);
  });

  testWidgets('shows a confirmation popup when a session is recorded', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.tap(find.text('Session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Session 1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Session 2'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('fullscreen shortcuts are no-ops outside a native window', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);

    await tapMenu(tester, 'History');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await openMenu(tester);
    expect(find.text('Stopwatch'), findsOneWidget);
    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();

    await unmount(tester);
  });

  testWidgets('history shows the empty state without any data', (tester) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await openMenu(tester);
    await tester.tap(find.text('History'));
    await tester.pump();
    expect(find.text('No study time yet'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('history renders stat cards and the chart', (tester) async {
    final storage = InMemoryStorage(
      jsonEncode({
        'version': 1,
        'theme': 'dark',
        'days': {'2026-10-13': 3600000},
        'session': {'laps': [], 'accumulatedMs': 0, 'runningSince': null},
      }),
    );
    final data = await buildData(storage);
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'History');

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pump();
    expect(find.byType(TodayChart), findsOneWidget);

    await tester.tap(find.text('30 days'));
    await tester.pump();
    expect(find.byType(LineChart), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('days page lists totals and session counts', (tester) async {
    final storage = InMemoryStorage(
      jsonEncode({
        'version': 1,
        'days': {'2026-10-13': 3600000, '2026-10-14': 1800000},
        'lapsByDay': {
          '2026-10-13': [
            {
              'start': '2026-10-13T22:00:00.000',
              'end': '2026-10-13T22:10:00.000',
              'durationMs': 600000,
            },
          ],
        },
        'session': {'laps': [], 'accumulatedMs': 0, 'runningSince': null},
      }),
    );
    final data = await buildData(storage);
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Days');

    expect(find.text('Days'), findsOneWidget);
    expect(find.text('1:00:00'), findsOneWidget);
    expect(find.text('0:30:00'), findsOneWidget);
    expect(find.text('1 session'), findsOneWidget);
    expect(find.text('0 sessions'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('deleting a session removes it and its study time', (
    tester,
  ) async {
    final today = studyDayFor(DateTime.now());
    final lapStart = today.add(const Duration(hours: 10));
    final lapEnd = lapStart.add(const Duration(minutes: 10));
    final storage = InMemoryStorage(
      jsonEncode({
        'version': 1,
        'days': {studyDayKey(today): 600000},
        'session': {
          'laps': [
            {
              'start': lapStart.toIso8601String(),
              'end': lapEnd.toIso8601String(),
              'durationMs': 600000,
            },
          ],
          'accumulatedMs': 600000,
          'runningSince': null,
          'lastLapElapsedMs': 600000,
          'lastLapEnd': lapEnd.toIso8601String(),
        },
      }),
    );
    final data = await buildData(storage);
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    expect(find.text('Today: 0:10:00'), findsOneWidget);
    await tapMenu(tester, 'Show sessions');
    expect(find.byType(LapTile), findsOneWidget);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    expect(find.text('Delete session?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(LapTile), findsNothing);
    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.text('Today: 0:00:00'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('settings can hide milliseconds on the stopwatch', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    expect(find.text('00:00:00.00'), findsOneWidget);

    await tapMenu(tester, 'Settings');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Show milliseconds'), findsOneWidget);

    await tester.tap(find.text('Show milliseconds'));
    await tester.pumpAndSettle();
    expect(settings.showMilliseconds, isFalse);

    await tester.scrollUntilVisible(
      find.text('Show session timer in zen mode'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Show session timer in zen mode'), findsOneWidget);
    await tester.tap(find.text('Show session timer in zen mode'));
    await tester.pumpAndSettle();
    expect(settings.zenShowSessionTimer, isFalse);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('00:00:00.00'), findsNothing);

    await unmount(tester);
  });

  testWidgets('zen mode hides the controls and Z exits it', (tester) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Zen mode');
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Start'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Studying'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
    expect(settings.zen, isFalse);

    await unmount(tester);
  });

  testWidgets('zen mode can hide the session timer', (tester) async {
    final data = await buildData();
    final settings = await buildSettings();
    settings.setZenShowSessionTimer(false);
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Zen mode');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byType(TimeDisplay), findsNothing);
    expect(find.text('Studying'), findsNothing);
    expect(find.text('Paused'), findsNothing);

    await unmount(tester);
  });

  testWidgets('reset current session keeps today and archives sessions', (
    tester,
  ) async {
    final today = studyDayFor(DateTime.now());
    final lapStart = today.add(const Duration(hours: 10));
    final lapEnd = lapStart.add(const Duration(minutes: 10));
    final storage = InMemoryStorage(
      jsonEncode({
        'version': 1,
        'days': {studyDayKey(today): 600000},
        'session': {
          'laps': [
            {
              'start': lapStart.toIso8601String(),
              'end': lapEnd.toIso8601String(),
              'durationMs': 600000,
            },
          ],
          'accumulatedMs': 600000,
          'runningSince': null,
          'lastLapElapsedMs': 600000,
          'lastLapEnd': lapEnd.toIso8601String(),
        },
      }),
    );
    final data = await buildData(storage);
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    expect(find.text('Today: 0:10:00'), findsOneWidget);

    await tapMenu(tester, 'Reset current session');
    expect(find.text('Reset current session?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(find.text('Today: 0:10:00'), findsOneWidget);
    expect(data.totalForStudyDay(today), const Duration(minutes: 10));
    expect(data.lapsForStudyDay(today), hasLength(1));

    await tapMenu(tester, 'Reset all sessions today');
    expect(find.text('Reset all sessions today?'), findsOneWidget);
    await tester.tap(find.text('Reset all'));
    await tester.pumpAndSettle();

    expect(find.text('Today: 0:00:00'), findsOneWidget);
    expect(data.totalForStudyDay(today), Duration.zero);
    expect(data.lapsForStudyDay(today), isEmpty);

    await unmount(tester);
  });

  testWidgets('fullscreen shortcuts work in zen mode', (tester) async {
    const channel = MethodChannel('sixam/fullscreen');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return call.method == 'isFullScreen' ? false : null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Zen mode');
    expect(find.text('TODAY'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(
      calls.where(
        (call) => call.method == 'setFullScreen' && call.arguments == true,
      ),
      hasLength(1),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      calls.where(
        (call) => call.method == 'setFullScreen' && call.arguments == false,
      ),
      hasLength(1),
    );
    expect(find.text('TODAY'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('exam mode waits for start and shows a countdown', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await openMenu(tester);
    await tester.tap(find.text('Exam'));
    await tester.pumpAndSettle();

    expect(find.text('Exam · 60m'), findsOneWidget);
    expect(find.text('01:00:00.00'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('session goal can be set, checked, edited, and deleted', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Session goal');
    expect(find.text('Session goal'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Finish chapter 4');
    await tester.pump();
    await tester.tap(find.text('Set goal'));
    await tester.pumpAndSettle();

    expect(settings.hasGoal, isTrue);
    expect(settings.goalText, 'Finish chapter 4');
    expect(find.text('Finish chapter 4'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(settings.goalDone, isTrue);

    await tester.tap(find.byTooltip('Edit goal'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Review notes');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(settings.goalText, 'Review notes');
    expect(settings.goalDone, isFalse);
    expect(find.text('Review notes'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete goal'));
    await tester.pumpAndSettle();

    expect(settings.hasGoal, isFalse);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Review notes'), findsNothing);

    await tester.tap(find.byTooltip('Close goal'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await unmount(tester);
  });

  testWidgets('goal reminder appears 30 seconds into a session', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('30 seconds in. Set your session goal.'), findsOneWidget);
    expect(find.text('Set goal'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.tap(find.text('Set goal'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Session goal'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('goal reminder stays quiet when disabled or a goal exists', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    settings.setGoalReminder(false);
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('30 seconds in. Set your session goal.'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    settings.setGoalReminder(true);
    settings.setSessionGoal('Read chapter 4');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('30 seconds in. Set your session goal.'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('settings can disable session goals and the reminder', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Settings');
    await tester.scrollUntilVisible(
      find.text('Session goals'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Goal reminder'), findsOneWidget);

    await tester.tap(find.text('Session goals'));
    await tester.pumpAndSettle();
    expect(settings.goalsEnabled, isFalse);
    final reminderTile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Goal reminder'),
    );
    expect(reminderTile.onChanged, isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await openMenu(tester);
    expect(find.text('Session goal'), findsNothing);

    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();
    await unmount(tester);
  });

  testWidgets('shortcuts keep working when widget focus is lost', (
    tester,
  ) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pause'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('shortcuts stay quiet while typing a goal', (tester) async {
    final data = await buildData();
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'Session goal');
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Start'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('history y-axis uses rounded hour labels', (tester) async {
    final today = studyDayFor(DateTime.now());
    final storage = InMemoryStorage(
      jsonEncode({
        'version': 1,
        'days': {studyDayKey(today): 19080000},
      }),
    );
    final data = await buildData(storage);
    final settings = await buildSettings();
    await tester.pumpWidget(SixAmApp(data: data, settings: settings));

    await tapMenu(tester, 'History');
    await tester.pumpAndSettle();
    expect(find.text('Daily total'), findsOneWidget);
    expect(find.text('8h'), findsOneWidget);
    expect(find.text('6.1h'), findsNothing);

    await unmount(tester);
  });
}
