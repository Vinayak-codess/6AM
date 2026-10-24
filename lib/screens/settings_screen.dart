import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_data.dart';
import '../theme/app_theme.dart';

const Map<AppFont, String> _fontLabels = {
  AppFont.jetBrainsMono: 'JetBrains Mono',
  AppFont.systemSans: 'System sans',
  AppFont.systemMono: 'System mono',
  AppFont.serif: 'Serif',
};

const List<int> _examChoices = [15, 25, 45, 60, 90, 120];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsData>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle('Display'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Show seconds'),
                  subtitle: const Text('HH:MM:SS'),
                  value: settings.showSeconds,
                  onChanged: settings.setShowSeconds,
                ),
                SwitchListTile(
                  title: const Text('Show milliseconds'),
                  subtitle: const Text('HH:MM:SS.hh'),
                  value: settings.showMilliseconds,
                  onChanged: settings.showSeconds
                      ? settings.setShowMilliseconds
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Clock style'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SegmentedButton<ClockDisplayMode>(
                      segments: const [
                        ButtonSegment(
                          value: ClockDisplayMode.digital,
                          label: Text('Digital'),
                          icon: Icon(Icons.numbers),
                        ),
                        ButtonSegment(
                          value: ClockDisplayMode.analog,
                          label: Text('Analog'),
                          icon: Icon(Icons.access_time),
                        ),
                      ],
                      selected: {settings.clockMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          settings.setClockMode(selection.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SectionTitle('Exam'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Countdown length', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _examChoices)
                        ChoiceChip(
                          label: Text('${minutes}m'),
                          selected: settings.examMinutes == minutes,
                          onSelected: (_) => settings.setExamMinutes(minutes),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _SectionTitle('Session goal'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Session goals'),
                  subtitle: const Text(
                    'Add a goal from the top menu and check it off',
                  ),
                  value: settings.goalsEnabled,
                  onChanged: settings.setGoalsEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Goal reminder'),
                  subtitle: const Text(
                    'Remind me after 30 seconds when no goal is set',
                  ),
                  value: settings.goalReminder,
                  onChanged: settings.goalsEnabled
                      ? settings.setGoalReminder
                      : null,
                ),
              ],
            ),
          ),
          _SectionTitle('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in themePresets.entries)
                        ChoiceChip(
                          label: Text(entry.value.label),
                          selected: settings.theme == entry.key,
                          onSelected: (_) => settings.setTheme(entry.key),
                          avatar: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: entry.value.gradient,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Font', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _fontLabels.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: settings.font == entry.key,
                          onSelected: (_) => settings.setFont(entry.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _SectionTitle('Widget'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Zen mode'),
                  subtitle: const Text(
                    'Hide controls and show today\'s total full screen',
                  ),
                  value: settings.zen,
                  onChanged: settings.setZen,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Show session timer in zen mode'),
                  subtitle: const Text(
                    'Show the running timer below today\'s total',
                  ),
                  value: settings.zenShowSessionTimer,
                  onChanged: settings.setZenShowSessionTimer,
                ),
              ],
            ),
          ),
          _SectionTitle('Data'),
          Card(
            child: const ListTile(
              leading: Icon(Icons.shield_outlined),
              title: Text('Automatic backup'),
              subtitle: Text(
                'study_data_backup.json is created next to study_data.json '
                'the first time the app starts.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
