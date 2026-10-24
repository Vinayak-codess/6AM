import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/status_export.dart';
import '../services/study_day.dart';
import '../state/app_data.dart';
import '../state/stopwatch_controller.dart';

class StatusSync extends StatefulWidget {
  const StatusSync({super.key, required this.child, this.exporter});

  final Widget child;
  final StudyStatusExporter? exporter;

  @override
  State<StatusSync> createState() => _StatusSyncState();
}

class _StatusSyncState extends State<StatusSync> {
  late final StudyStatusExporter _exporter =
      widget.exporter ?? StudyStatusExporter();
  String? _lastPayload;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final controller = context.watch<StopwatchController>();
    final now = DateTime.now();
    final today = studyDayFor(now);
    final total =
        data.totalForStudyDay(today) + controller.liveUncommittedForDay(today);
    final payload =
        '${total.inSeconds}|${controller.isRunning}|${studyDayKey(today)}';
    if (payload != _lastPayload) {
      _lastPayload = payload;
      _exporter.write(
        now: now,
        total: total,
        studyDay: today,
        running: controller.isRunning,
      );
    }
    return widget.child;
  }
}
