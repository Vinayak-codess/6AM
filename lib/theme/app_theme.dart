import 'package:flutter/material.dart';

import '../state/settings_data.dart';

class ThemeSpec {
  const ThemeSpec({
    required this.label,
    required this.seed,
    required this.gradient,
  });

  final String label;
  final Color seed;
  final List<Color> gradient;
}

const Map<ThemePreset, ThemeSpec> themePresets = {
  ThemePreset.emerald: ThemeSpec(
    label: 'Emerald',
    seed: Color(0xFF3BC99B),
    gradient: [Color(0xFF050806), Color(0xFF0B1911), Color(0xFF0F2419)],
  ),
  ThemePreset.midnight: ThemeSpec(
    label: 'Midnight',
    seed: Color(0xFF5B8DEF),
    gradient: [Color(0xFF04060C), Color(0xFF0A1220), Color(0xFF0E1B30)],
  ),
  ThemePreset.graphite: ThemeSpec(
    label: 'Graphite',
    seed: Color(0xFF9AA4B2),
    gradient: [Color(0xFF08090A), Color(0xFF111316), Color(0xFF191C20)],
  ),
  ThemePreset.amethyst: ThemeSpec(
    label: 'Amethyst',
    seed: Color(0xFFB388FF),
    gradient: [Color(0xFF09060D), Color(0xFF140D20), Color(0xFF1D1230)],
  ),
  ThemePreset.monochrome: ThemeSpec(
    label: 'Monochrome',
    seed: Color(0xFFFFFFFF),
    gradient: [Color(0xFF000000), Color(0xFF000000), Color(0xFF000000)],
  ),
  ThemePreset.lavender: ThemeSpec(
    label: 'Lavender',
    seed: Color(0xFF6750A4),
    gradient: [Color(0xFF141414), Color(0xFF161616), Color(0xFF191919)],
  ),
};

const Map<AppFont, String?> fontFamilies = {
  AppFont.jetBrainsMono: 'JetBrains Mono',
  AppFont.systemSans: null,
  AppFont.systemMono: 'Consolas',
  AppFont.serif: 'Georgia',
};

ThemeData buildAppTheme(SettingsData settings) {
  final scheme = _schemeFor(settings);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: settings.fontFamily,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
  );
}

ColorScheme _schemeFor(SettingsData settings) {
  if (settings.theme == ThemePreset.monochrome) {
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF808080),
      brightness: Brightness.dark,
    ).copyWith(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF1F1F1F),
      onPrimaryContainer: Colors.white,
      secondary: const Color(0xFFE5E5E5),
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF2A2A2A),
      onSecondaryContainer: Colors.white,
      tertiary: const Color(0xFFCCCCCC),
      onTertiary: Colors.black,
      error: const Color(0xFFA8A8A8),
      onError: Colors.black,
      errorContainer: const Color(0xFF333333),
      onErrorContainer: Colors.white,
      surface: Colors.black,
      onSurface: Colors.white,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0C0C0C),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1C1C1C),
      surfaceContainerHighest: const Color(0xFF242424),
      onSurfaceVariant: const Color(0xFFBDBDBD),
      outline: const Color(0xFF6B6B6B),
      outlineVariant: const Color(0xFF3A3A3A),
      inverseSurface: Colors.white,
      onInverseSurface: Colors.black,
      inversePrimary: Colors.black,
    );
  }
  return ColorScheme.fromSeed(
    seedColor: settings.themeSpec.seed,
    brightness: Brightness.dark,
  );
}

extension SettingsVisuals on SettingsData {
  ThemeSpec get themeSpec =>
      themePresets[theme] ?? themePresets[ThemePreset.emerald]!;

  String? get fontFamily => fontFamilies[font];
}
