import 'package:flutter/material.dart';

import '../models/lap.dart';
import '../services/formatting.dart';

enum LapHighlight { longest, shortest }

class LapTile extends StatelessWidget {
  const LapTile({
    super.key,
    required this.number,
    required this.lap,
    this.highlight,
    this.onDelete,
  });

  final int number;
  final Lap lap;
  final LapHighlight? highlight;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = switch (highlight) {
      LapHighlight.longest => scheme.primary,
      LapHighlight.shortest => scheme.error,
      null => null,
    };
    final accentForeground = switch (highlight) {
      LapHighlight.longest => scheme.onPrimary,
      LapHighlight.shortest => scheme.onError,
      null => scheme.onSurface,
    };
    final label = switch (highlight) {
      LapHighlight.longest => 'Longest',
      LapHighlight.shortest => 'Shortest',
      null => null,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        color: accent == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: accent == null
            ? null
            : Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor:
              accent?.withValues(alpha: 0.25) ?? scheme.surfaceContainerHighest,
          child: Text('$number', style: theme.textTheme.labelMedium),
        ),
        title: Text(
          formatStopwatch(lap.duration),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Text(
          '${formatClockTime(lap.start)} \u2192 ${formatClockTime(lap.end)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: label == null && onDelete == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentForeground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (onDelete != null) ...[
                    if (label != null) const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Delete session',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
