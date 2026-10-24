import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/storage.dart';
import 'package:sixam/state/settings_data.dart';

void main() {
  test('uses minimal defaults', () async {
    final settings = SettingsData(InMemoryStorage());
    await settings.load();

    expect(settings.showMilliseconds, isTrue);
    expect(settings.showSeconds, isTrue);
    expect(settings.clockMode, ClockDisplayMode.digital);
    expect(settings.theme, ThemePreset.emerald);
    expect(settings.font, AppFont.jetBrainsMono);
    expect(settings.examMinutes, 60);
    expect(settings.zen, isFalse);
    expect(settings.zenShowSessionTimer, isTrue);
    expect(settings.goalsEnabled, isTrue);
    expect(settings.goalReminder, isTrue);
    expect(settings.hasGoal, isFalse);
    expect(settings.goalDone, isFalse);
  });

  test('persists every setting', () async {
    final storage = InMemoryStorage();
    final settings = SettingsData(storage);
    await settings.load();

    settings.setShowMilliseconds(false);
    settings.setShowSeconds(false);
    settings.setClockMode(ClockDisplayMode.analog);
    settings.setTheme(ThemePreset.midnight);
    settings.setFont(AppFont.serif);
    settings.setExamMinutes(25);
    settings.setZen(true);
    settings.setZenShowSessionTimer(false);
    settings.setGoalsEnabled(false);
    settings.setGoalReminder(false);
    settings.setSessionGoal('Ship the app');
    settings.setGoalDone(true);
    await settings.flush();

    final reloaded = SettingsData(storage);
    await reloaded.load();
    expect(reloaded.showMilliseconds, isFalse);
    expect(reloaded.showSeconds, isFalse);
    expect(reloaded.clockMode, ClockDisplayMode.analog);
    expect(reloaded.theme, ThemePreset.midnight);
    expect(reloaded.font, AppFont.serif);
    expect(reloaded.examMinutes, 25);
    expect(reloaded.zen, isTrue);
    expect(reloaded.zenShowSessionTimer, isFalse);
    expect(reloaded.goalsEnabled, isFalse);
    expect(reloaded.goalReminder, isFalse);
    expect(reloaded.goalText, 'Ship the app');
    expect(reloaded.goalDone, isTrue);
  });

  test('goal changes reset completion and can be cleared', () async {
    final settings = SettingsData(InMemoryStorage());
    await settings.load();

    settings.setSessionGoal('  Read chapter 4  ');
    expect(settings.goalText, 'Read chapter 4');
    expect(settings.hasGoal, isTrue);

    settings.setGoalDone(true);
    expect(settings.goalDone, isTrue);

    settings.setSessionGoal('Write notes');
    expect(settings.goalText, 'Write notes');
    expect(settings.goalDone, isFalse);

    settings.setSessionGoal('   ');
    expect(settings.hasGoal, isFalse);
    expect(settings.goalDone, isFalse);

    settings.setSessionGoal('Review');
    settings.setGoalDone(true);
    settings.clearGoal();
    expect(settings.hasGoal, isFalse);
    expect(settings.goalDone, isFalse);
  });

  test('falls back to defaults on corrupt or unknown values', () async {
    final settings = SettingsData(
      InMemoryStorage(
        '{"showMilliseconds":"yes","clockMode":"sundial",'
        '"theme":"neon","font":"comic","examMinutes":-5,"zen":1,'
        '"goalsEnabled":"yes","goalReminder":2,"goalText":5,'
        '"goalDone":"no"}',
      ),
    );
    await settings.load();

    expect(settings.showMilliseconds, isTrue);
    expect(settings.clockMode, ClockDisplayMode.digital);
    expect(settings.theme, ThemePreset.emerald);
    expect(settings.font, AppFont.jetBrainsMono);
    expect(settings.examMinutes, 60);
    expect(settings.zen, isFalse);
    expect(settings.zenShowSessionTimer, isTrue);
    expect(settings.goalsEnabled, isTrue);
    expect(settings.goalReminder, isTrue);
    expect(settings.hasGoal, isFalse);
    expect(settings.goalDone, isFalse);
  });

  test('an empty goal is never marked done', () async {
    final settings = SettingsData(
      InMemoryStorage('{"goalText":"   ","goalDone":true}'),
    );
    await settings.load();

    expect(settings.hasGoal, isFalse);
    expect(settings.goalDone, isFalse);
  });
}
