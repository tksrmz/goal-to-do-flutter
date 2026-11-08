import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/items.dart';
import '../domain/mutation.dart';
import '../domain/operations.dart';
import '../domain/views.dart';
import '../providers/providers.dart';
import 'app_shell.dart';
import 'item_flows.dart';
import 'item_forms.dart';
import 'task_row.dart';

/// 今日（FR-002、REQ-001 7.1）。予定日が今日以前の未完了タスクを、目的・目標のまとまりで出す。
/// 行える操作は、タスクの完了切り替えと新規作成のみ。
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// この画面を開いている間に完了にしたタスク。画面を開き直すまで残す（AC-012）。
  final _retainedTaskIds = <String>{};

  void _retain(Mutation mutation) {
    final ids = [
      for (final ref in mutation.newlyDone)
        if (ref.kind == ItemKind.task) ref.id,
    ];
    if (ids.isNotEmpty && mounted) {
      setState(() => _retainedTaskIds.addAll(ids));
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final treeAsync = ref.watch(itemTreeProvider);
    final theme = Theme.of(context);

    final Widget body;
    if (treeAsync.value case final tree?) {
      final sections = buildTodayView(
        tree,
        today,
        retainedTaskIds: _retainedTaskIds,
      );
      body = sections.isEmpty
          ? const Center(child: Text('今日やるべきタスクはありません'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final section in sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      section.purpose.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  for (final group in section.goals) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8),
                      child: Text(
                        group.goal.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    for (final task in group.tasks)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TaskRow(
                          key: ValueKey(task.id),
                          task: task,
                          today: today,
                          onToggle: tree.canToggleTask(task)
                              ? () => toggleTaskFlow(
                                  context,
                                  ref,
                                  task,
                                  onCommitted: _retain,
                                )
                              : null,
                        ),
                      ),
                  ],
                ],
              ],
            );
    } else if (treeAsync.hasError) {
      body = const Center(child: Text('データを読み込めませんでした'));
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return AppShell(
      title: '今日',
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: treeAsync.hasValue
            ? () => showTaskForm(context, scheduledDate: today)
            : null,
        icon: const Icon(Icons.add),
        label: const Text('タスク'),
      ),
    );
  }
}
