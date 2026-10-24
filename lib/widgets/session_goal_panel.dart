import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/settings_data.dart';

class SessionGoalPanel extends StatefulWidget {
  const SessionGoalPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<SessionGoalPanel> createState() => _SessionGoalPanelState();
}

class _SessionGoalPanelState extends State<SessionGoalPanel> {
  final TextEditingController _goalController = TextEditingController();
  final FocusNode _goalFocus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsData>();
    _goalController.text = settings.goalText;
    if (!settings.hasGoal) {
      _focusGoal();
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    _goalFocus.dispose();
    super.dispose();
  }

  void _focusGoal({bool selectAll = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _goalFocus.requestFocus();
      if (selectAll) {
        _goalController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _goalController.text.length,
        );
      }
    });
  }

  void _save(SettingsData settings) {
    final text = _goalController.text.trim();
    if (text.isEmpty) {
      return;
    }
    settings.setSessionGoal(text);
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _beginEdit(SettingsData settings) {
    _goalController.text = settings.goalText;
    setState(() => _editing = true);
    _focusGoal(selectAll: true);
  }

  void _cancelEdit(SettingsData settings) {
    _goalController.text = settings.goalText;
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _delete(SettingsData settings) {
    settings.clearGoal();
    _goalController.clear();
    setState(() => _editing = false);
    _focusGoal();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsData>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final editing = _editing || !settings.hasGoal;
    return SizedBox(
      width: 300,
      child: Material(
        elevation: 16,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.task_alt, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Session goal',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close goal',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                        reverseCurve: Curves.easeInCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SizeTransition(
                          sizeFactor: curved,
                          alignment: Alignment.topCenter,
                          child: child,
                        ),
                      );
                    },
                    child: editing
                        ? _buildEditor(settings, theme)
                        : _buildGoal(settings, theme),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(SettingsData settings, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Column(
      key: const ValueKey<String>('goal-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _goalController,
          focusNode: _goalFocus,
          autofocus: false,
          minLines: 1,
          maxLines: 3,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(settings),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'What do you want to finish?',
            isDense: true,
            counterText: '',
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _goalController,
          builder: (context, value, _) {
            final canSave = value.text.trim().isNotEmpty;
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (settings.hasGoal)
                  TextButton(
                    onPressed: () => _cancelEdit(settings),
                    child: const Text('Cancel'),
                  ),
                if (settings.hasGoal) const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: canSave ? () => _save(settings) : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(settings.hasGoal ? 'Save' : 'Set goal'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoal(SettingsData settings, ThemeData theme) {
    final scheme = theme.colorScheme;
    final done = settings.goalDone;
    return Row(
      key: const ValueKey<String>('goal-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.9,
          child: Checkbox(
            value: done,
            onChanged: (value) => settings.setGoalDone(value ?? false),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => settings.setGoalDone(!done),
            child: Padding(
              padding: const EdgeInsets.only(top: 11, bottom: 8),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                  decoration: done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
                child: Text(settings.goalText),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Edit goal',
          visualDensity: VisualDensity.compact,
          onPressed: () => _beginEdit(settings),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Delete goal',
          visualDensity: VisualDensity.compact,
          onPressed: () => _delete(settings),
          icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
        ),
      ],
    );
  }
}
