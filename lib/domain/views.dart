import 'calendar_date.dart';
import 'item_tree.dart';
import 'items.dart';
import 'ordering.dart';

/// 画面に出す範囲の絞り込みと並べ替え（REQ-001 7.1〜7.3）。表示の状態は保存せず、
/// 済みかどうかから導出する（原理3）。

// ---- 今日の画面（7.1） ----

final class TodayGoalGroup(final Goal goal, final List<Task> tasks);

final class TodaySection(
  final Purpose purpose,
  final List<TodayGoalGroup> goals,
);

/// 今日の画面に出す範囲: 予定日が今日以前の未完了タスクと、その親の目標・祖先の目的。
///
/// [retainedTaskIds] は、この画面を開いている間に完了にしたタスク。画面を開き直すまで、
/// 済みでも表示に残す。
List<TodaySection> buildTodayView(
  ItemTree tree,
  CalendarDate today, {
  Set<String> retainedTaskIds = const {},
}) {
  bool isTarget(Task task) =>
      retainedTaskIds.contains(task.id) ||
      (!task.isDone &&
          task.scheduledDate != null &&
          !task.scheduledDate!.isAfter(today));

  return [
    for (final purpose in tree.sortedPurposes)
      if (_todayGoals(tree, purpose, today, isTarget) case final goals
          when goals.isNotEmpty)
        TodaySection(purpose, goals),
  ];
}

List<TodayGoalGroup> _todayGoals(
  ItemTree tree,
  Purpose purpose,
  CalendarDate today,
  bool Function(Task) isTarget,
) => [
  for (final goal in tree.goalsOf(purpose.id))
    if (sortTasks(tree.tasksOf(goal.id).where(isTarget), today) case final tasks
        when tasks.isNotEmpty)
      TodayGoalGroup(goal, tasks),
];

// ---- すべての画面（7.2） ----

final class AllGoalNode(
  final Goal goal,
  final List<Task> tasks, {
  required final int completedTaskCount,
  required final int totalTaskCount,
});

final class AllPurposeNode(
  final Purpose purpose,
  final List<AllGoalNode> goals,
);

/// すべての画面に出すツリー。
///
/// [showDone] が OFF のときは済みの項目を出さない。ただし [retained]（この画面を開いている間に
/// 済みにした項目）は、画面を開き直すまで表示に残す。
List<AllPurposeNode> buildAllView(
  ItemTree tree,
  CalendarDate today, {
  required bool showDone,
  Set<ItemRef> retained = const {},
}) {
  bool isVisible(Item item) =>
      showDone || !item.isDone || retained.contains(item.ref);

  AllGoalNode goalNode(Goal goal) {
    final tasks = tree.tasksOf(goal.id);
    return AllGoalNode(
      goal,
      sortTasks(tasks.where(isVisible), today),
      // 完了したタスク数には「親の達成で完了」も含む
      completedTaskCount: tasks.where((t) => t.isDone).length,
      totalTaskCount: tasks.length,
    );
  }

  return [
    for (final purpose in tree.sortedPurposes)
      if (isVisible(purpose))
        AllPurposeNode(purpose, [
          for (final goal in tree.goalsOf(purpose.id))
            if (isVisible(goal)) goalNode(goal),
        ]),
  ];
}
