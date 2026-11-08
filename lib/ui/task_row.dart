import 'package:material_ui/material_ui.dart';

import '../domain/calendar_date.dart';
import '../domain/items.dart';
import '../domain/ordering.dart';
import 'common.dart';

/// タスクの行。チェックボックス・名前・重要タグ・緊急タグ・予定日を出す（REQ-001 7.1、7.2）。
/// 済みのタスクは打ち消し線で出す。期限切れは予定日を赤で強調する（AC-008）。
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.today,
    required this.onToggle,
    this.trailing,
  });

  final Task task;
  final CalendarDate today;

  /// `null` なら完了を切り替えられない（済みの親の配下、AC-043）。
  final VoidCallback? onToggle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isDone;
    final overdue = isOverdue(task, today);
    final nameStyle = theme.textTheme.bodyLarge?.copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? theme.colorScheme.onSurfaceVariant : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: done,
            onChanged: onToggle == null ? null : (_) => onToggle!(),
            semanticLabel: '${task.name}を${done ? '未完了に戻す' : '完了にする'}',
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(task.name, style: nameStyle),
                if (task.important) const PriorityTag.important(),
                if (task.urgent) const PriorityTag.urgent(),
                if (task.scheduledDate case final date?)
                  Text(
                    formatDate(date, today),
                    key: ValueKey('scheduledDate-${task.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: overdue ? theme.colorScheme.error : null,
                      fontWeight: overdue ? FontWeight.bold : null,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
