import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/storage.dart';

enum ClockDisplayMode { digital, analog }

enum ThemePreset { emerald, midnight, graphite, amethyst, monochrome, lavender }

enum AppFont { jetBrainsMono, systemSans, systemMono, serif }

class SettingsData extends ChangeNotifier {
  SettingsData(this._storage);

  final Storage _storage;
  Future<void> _writes = Future<void>.value();

  bool _showMilliseconds = true;
  bool _showSeconds = true;
  ClockDisplayMode _clockMode = ClockDisplayMode.digital;
  ThemePreset _theme = ThemePreset.emerald;
  AppFont _font = AppFont.jetBrainsMono;
  int _examMinutes = 60;
  bool _zen = false;
  bool _zenShowSessionTimer = true;
  bool _goalsEnabled = true;
  bool _goalReminder = true;
  String _goalText = '';
  bool _goalDone = false;

  bool get showMilliseconds => _showMilliseconds;
  bool get showSeconds => _showSeconds;
  ClockDisplayMode get clockMode => _clockMode;
  ThemePreset get theme => _theme;
  AppFont get font => _font;
  int get examMinutes => _examMinutes;
  bool get zen => _zen;
  bool get zenShowSessionTimer => _zenShowSessionTimer;
  bool get goalsEnabled => _goalsEnabled;
  bool get goalReminder => _goalReminder;
  String get goalText => _goalText;
  bool get goalDone => _goalDone;
  bool get hasGoal => _goalText.isNotEmpty;

  Future<void> load() async {
    try {
      final raw = await _storage.read();
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final milliseconds = decoded['showMilliseconds'];
          if (milliseconds is bool) {
            _showMilliseconds = milliseconds;
          }
          final seconds = decoded['showSeconds'];
          if (seconds is bool) {
            _showSeconds = seconds;
          }
          final clock = decoded['clockMode'];
          if (clock is String) {
            _clockMode =
                ClockDisplayMode.values.asNameMap()[clock] ?? _clockMode;
          }
          final theme = decoded['theme'];
          if (theme is String) {
            _theme = ThemePreset.values.asNameMap()[theme] ?? _theme;
          }
          final font = decoded['font'];
          if (font is String) {
            _font = AppFont.values.asNameMap()[font] ?? _font;
          }
          final exam = decoded['examMinutes'];
          if (exam is num && exam.toInt() > 0) {
            _examMinutes = exam.toInt();
          }
          final zen = decoded['zen'];
          if (zen is bool) {
            _zen = zen;
          }
          final zenTimer = decoded['zenShowSessionTimer'];
          if (zenTimer is bool) {
            _zenShowSessionTimer = zenTimer;
          }
          final goalsEnabled = decoded['goalsEnabled'];
          if (goalsEnabled is bool) {
            _goalsEnabled = goalsEnabled;
          }
          final goalReminder = decoded['goalReminder'];
          if (goalReminder is bool) {
            _goalReminder = goalReminder;
          }
          final goalText = decoded['goalText'];
          if (goalText is String) {
            _goalText = goalText.trim();
          }
          final goalDone = decoded['goalDone'];
          if (goalDone is bool) {
            _goalDone = goalDone;
          }
          if (_goalText.isEmpty) {
            _goalDone = false;
          }
        }
      }
    } catch (_) {
      // Keep defaults when the settings file is unreadable.
    }
    notifyListeners();
  }

  void setShowMilliseconds(bool value) {
    if (value == _showMilliseconds) {
      return;
    }
    _showMilliseconds = value;
    _changed();
  }

  void setShowSeconds(bool value) {
    if (value == _showSeconds) {
      return;
    }
    _showSeconds = value;
    _changed();
  }

  void setClockMode(ClockDisplayMode value) {
    if (value == _clockMode) {
      return;
    }
    _clockMode = value;
    _changed();
  }

  void setTheme(ThemePreset value) {
    if (value == _theme) {
      return;
    }
    _theme = value;
    _changed();
  }

  void setFont(AppFont value) {
    if (value == _font) {
      return;
    }
    _font = value;
    _changed();
  }

  void setExamMinutes(int value) {
    if (value <= 0 || value == _examMinutes) {
      return;
    }
    _examMinutes = value;
    _changed();
  }

  void setZen(bool value) {
    if (value == _zen) {
      return;
    }
    _zen = value;
    _changed();
  }

  void setZenShowSessionTimer(bool value) {
    if (value == _zenShowSessionTimer) {
      return;
    }
    _zenShowSessionTimer = value;
    _changed();
  }

  void setGoalsEnabled(bool value) {
    if (value == _goalsEnabled) {
      return;
    }
    _goalsEnabled = value;
    _changed();
  }

  void setGoalReminder(bool value) {
    if (value == _goalReminder) {
      return;
    }
    _goalReminder = value;
    _changed();
  }

  void setSessionGoal(String text) {
    final trimmed = text.trim();
    if (trimmed == _goalText) {
      return;
    }
    _goalText = trimmed;
    _goalDone = false;
    _changed();
  }

  void setGoalDone(bool value) {
    if (value == _goalDone) {
      return;
    }
    _goalDone = value;
    _changed();
  }

  void clearGoal() {
    if (_goalText.isEmpty && !_goalDone) {
      return;
    }
    _goalText = '';
    _goalDone = false;
    _changed();
  }

  Future<void> flush() => _writes;

  void _changed() {
    notifyListeners();
    final encoded = jsonEncode(_toJson());
    _writes = _writes
        .then((_) => _storage.write(encoded))
        .catchError((Object _) {});
  }

  Map<String, Object?> _toJson() => {
    'version': 1,
    'showMilliseconds': _showMilliseconds,
    'showSeconds': _showSeconds,
    'clockMode': _clockMode.name,
    'theme': _theme.name,
    'font': _font.name,
    'examMinutes': _examMinutes,
    'zen': _zen,
    'zenShowSessionTimer': _zenShowSessionTimer,
    'goalsEnabled': _goalsEnabled,
    'goalReminder': _goalReminder,
    'goalText': _goalText,
    'goalDone': _goalDone,
  };
}
