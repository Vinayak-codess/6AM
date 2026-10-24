# 6AM

**This is a personal project I built for myself, entirely using AI.**

A minimal, distraction-free study timer built with Flutter. Study days run from **6 AM to 6 AM**, so late-night sessions count toward the previous day.

## Features

- **Stopwatch** with start, pause, resume, and reset, plus live "today" total
- **Sessions (laps)** sidebar with per-session times, delete, and longest/shortest highlighting
- **6 AM study days** — daily totals, sessions, and charts roll over at 6 AM, not midnight
- **Exam mode** — countdown timer (15/25/45/60/90/120 min) with auto-finish
- **History** — today, this week, and last-30-days totals with interactive charts (hourly for today, 7/30-day trends)
- **Days screen** — every recorded study day with total time and session count
- **Zen mode** — fullscreen, minimal view of today's total, with an optional live session timer
- **Session goals** — set one goal, check it off, and get an optional reminder after 30 seconds of studying without a goal
- **Themes & fonts** — six color presets (Emerald, Midnight, Graphite, Amethyst, Monochrome, Lavender) and four font choices
- **Digital or analog clock** display, with toggleable seconds and milliseconds
- **Keyboard shortcuts** for hands-free control
- **Battery and clock indicators** in the corner
- **Local-first storage** — JSON files, auto-save every 5 seconds, and an automatic backup on first launch
- **Status export** — writes `today_study_status.txt` and `status.json` for external tools/widgets
- **Native Windows desktop app** with true borderless fullscreen

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Space` | Start / pause |
| `L` | Record session (lap in zen mode) |
| `R` | Reset current session |
| `Z` | Toggle zen mode |
| `F` | Toggle fullscreen |
| `Esc` | Exit fullscreen |

## Run

```bash
flutter pub get
flutter run -d windows
```

## Test

```bash
flutter test
```

## Build

```bash
flutter build windows
```

A prebuilt Windows x64 release is available at `dist/6AM-windows-x64.zip`.

## Data

All data stays on your machine in the app documents directory:

- `study_data.json` — study time, sessions, and active timer
- `settings.json` — preferences and session goal
- `study_data_backup.json` — automatic first-launch backup

## Tech

Flutter · Provider · fl_chart · path_provider · battery_plus · JetBrains Mono
