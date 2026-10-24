import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixam/services/storage.dart';
import 'package:sixam/state/settings_data.dart';
import 'package:sixam/theme/app_theme.dart';

void main() {
  test('monochrome theme is black and white', () {
    final settings = SettingsData(InMemoryStorage());
    settings.setTheme(ThemePreset.monochrome);

    final theme = buildAppTheme(settings);

    expect(theme.colorScheme.surface, Colors.black);
    expect(theme.colorScheme.primary, Colors.white);
    expect(theme.colorScheme.onPrimary, Colors.black);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });
}
