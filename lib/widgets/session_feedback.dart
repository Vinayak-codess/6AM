import 'package:flutter/material.dart';

import '../services/formatting.dart';
import '../state/stopwatch_controller.dart';

void recordSessionWithFeedback(
  BuildContext context,
  StopwatchController controller,
) {
  final session = controller.lap();
  if (session == null) {
    return;
  }
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 280,
        duration: const Duration(milliseconds: 1800),
        content: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: theme.colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Session ${controller.laps.length} · '
                '${formatStopwatch(session.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
