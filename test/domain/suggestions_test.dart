import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:goal_to_do/domain/operations.dart';
import 'package:goal_to_do/domain/suggestions.dart';

import '../helpers/fixtures.dart';

void main() {
  group('目標の達成の提案', () {
    test('AC-045: 最後の未完了タスクを完了にすると、目標の達成を提案する', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T', 'X'),
          task('U', 'X', status: TaskStatus.complete),
        ],
      );
      final after = tree.apply(tree.toggleTask('T'));
      expect(suggestGoalAfterTaskCompleted(after, 'T')?.id, 'X');
    });

    test('未完了のタスクが残っていれば提案しない', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [task('T', 'X'), task('U', 'X')],
      );
      final after = tree.apply(tree.toggleTask('T'));
      expect(suggestGoalAfterTaskCompleted(after, 'T'), isNull);
    });

    test('未完了に戻したときは提案しない', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [task('T', 'X', status: TaskStatus.complete)],
      );
      final after = tree.apply(tree.toggleTask('T'));
      expect(suggestGoalAfterTaskCompleted(after, 'T'), isNull);
    });
  });

  group('目的の達成の提案', () {
    test('AC-047: 最後の未達成の目標を達成にすると、目的の達成を提案する', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [
          goal('X', 'P'),
          goal('Y', 'P', status: GoalStatus.achieved),
        ],
      );
      final after = tree.apply(
        tree.achieve((kind: ItemKind.goal, id: 'X')).mutation,
      );
      expect(suggestPurposeAfterGoalAchieved(after, 'X')?.id, 'P');
    });

    test('未達成の目標が残っていれば提案しない', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P'), goal('Y', 'P')],
      );
      final after = tree.apply(
        tree.achieve((kind: ItemKind.goal, id: 'X')).mutation,
      );
      expect(suggestPurposeAfterGoalAchieved(after, 'X'), isNull);
    });
  });

  test('AC-050: タスクの完了 → 目標の達成の受諾 → 目的の達成の提案と続く', () {
    final tree = ItemTree(
      purposes: [purpose('P')],
      goals: [goal('X', 'P')],
      tasks: [task('T', 'X')],
    );
    final afterTask = tree.apply(tree.toggleTask('T'));
    final goalSuggestion = suggestGoalAfterTaskCompleted(afterTask, 'T');
    expect(goalSuggestion?.id, 'X');

    // AC-046: 提案を受諾した達成は、自分で達成したもの（achieved）として扱う
    final plan = afterTask.achieve(goalSuggestion!.ref);
    expect(plan.counts.isEmpty, isTrue);
    final afterGoal = afterTask.apply(plan.mutation);
    expect(afterGoal.goals['X']!.status, GoalStatus.achieved);
    expect(suggestPurposeAfterGoalAchieved(afterGoal, 'X')?.id, 'P');
  });
}
