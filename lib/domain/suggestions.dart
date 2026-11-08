import 'item_tree.dart';
import 'items.dart';
import 'operations.dart';

/// 達成の提案（REQ-001 6.4）。
///
/// どちらも、操作を反映したあとのツリー（[ItemTree.apply] の結果）を渡す。

/// タスクを完了にしたあと、親の目標の配下タスクがすべて済みなら、その目標を返す。
Goal? suggestGoalAfterTaskCompleted(ItemTree tree, String taskId) {
  final task = tree.tasks[taskId];
  if (task == null || !task.isDone) return null;
  final goal = tree.goals[task.goalId];
  if (goal == null || !tree.canAchieve(goal)) return null;
  final tasks = tree.tasksOf(goal.id);
  return tasks.every((t) => t.isDone) ? goal : null;
}

/// 目標を達成にしたあと、親の目的の配下目標がすべて済みなら、その目的を返す。
Purpose? suggestPurposeAfterGoalAchieved(ItemTree tree, String goalId) {
  final goal = tree.goals[goalId];
  if (goal == null || !goal.isDone) return null;
  final purpose = tree.purposes[goal.purposeId];
  if (purpose == null || !tree.canAchieve(purpose)) return null;
  final goals = tree.goalsOf(purpose.id);
  return goals.every((g) => g.isDone) ? purpose : null;
}
