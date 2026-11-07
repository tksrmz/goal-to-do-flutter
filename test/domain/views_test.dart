import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:goal_to_do/domain/views.dart';

import '../helpers/fixtures.dart';

void main() {
  final today = date('2026-11-06');

  group('buildTodayView（7.1）', () {
    List<String> taskIds(List<TodaySection> sections) => [
      for (final s in sections)
        for (final g in s.goals)
          for (final t in g.tasks) t.id,
    ];

    test('AC-007, AC-008, AC-009: 予定日が今日以前の未完了タスクだけを出す', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('today', 'X', scheduledDate: today),
          task('overdue', 'X', scheduledDate: date('2026-11-01')),
          task('tomorrow', 'X', scheduledDate: date('2026-11-07')),
          task('noDate', 'X'),
          task(
            'doneToday',
            'X',
            scheduledDate: today,
            status: TaskStatus.complete,
          ),
        ],
      );
      expect(taskIds(buildTodayView(tree, today)), ['overdue', 'today']);
    });

    test('AC-010: 目的・目標のまとまりで出し、表示対象のない目的・目標は出さない', () {
      final tree = ItemTree(
        purposes: [
          purpose('A', createdOrder: 1),
          purpose('B', createdOrder: 2),
        ],
        goals: [goal('X', 'A'), goal('W', 'A'), goal('Y', 'B')],
        tasks: [
          task('T', 'X', scheduledDate: today),
          task('later', 'Y', scheduledDate: date('2026-12-01')),
        ],
      );
      final view = buildTodayView(tree, today);
      expect(view, hasLength(1));
      expect(view.single.purpose.id, 'A');
      expect([for (final g in view.single.goals) g.goal.id], ['X']);
      expect(taskIds(view), ['T']);
    });

    test('AC-011: 表示対象がなければ空', () {
      expect(buildTodayView(ItemTree.empty, today), isEmpty);
    });

    test('AC-012: 画面を開いている間に完了にしたタスクは、済みでも残す', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T', 'X', scheduledDate: today, status: TaskStatus.complete),
        ],
      );
      expect(buildTodayView(tree, today), isEmpty);
      expect(taskIds(buildTodayView(tree, today, retainedTaskIds: {'T'})), [
        'T',
      ]);
    });

    test('AC-015: 日付が変わると、新しい日付で判定する', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T', 'X', scheduledDate: date('2026-11-06')),
          task('U', 'X', scheduledDate: date('2026-11-07')),
        ],
      );
      expect(taskIds(buildTodayView(tree, date('2026-11-06'))), ['T']);
      // 11/07 には T が期限切れとして先に、U が今日のタスクとして並ぶ
      expect(taskIds(buildTodayView(tree, date('2026-11-07'))), ['T', 'U']);
    });
  });

  group('buildAllView（7.2）', () {
    final tree = ItemTree(
      purposes: [
        purpose('A', createdOrder: 1),
        purpose('done', status: PurposeStatus.achieved, createdOrder: 2),
      ],
      goals: [
        goal('X', 'A', createdOrder: 1),
        goal('doneGoal', 'A', status: GoalStatus.achieved, createdOrder: 2),
        goal('underDone', 'done', status: GoalStatus.achievedByParent),
      ],
      tasks: [
        task('t1', 'X'),
        task('t2', 'X', status: TaskStatus.complete),
        task('t3', 'X', status: TaskStatus.completeByParent),
        task('t4', 'X'),
        task('t5', 'X'),
      ],
    );

    List<String> visibleIds(List<AllPurposeNode> nodes) => [
      for (final p in nodes) ...[
        p.purpose.id,
        for (final g in p.goals) ...[g.goal.id, for (final t in g.tasks) t.id],
      ],
    ];

    test('AC-053: 済みも表示が OFF なら済みの項目を出さない', () {
      final view = buildAllView(tree, today, showDone: false);
      expect(visibleIds(view), ['A', 'X', 't1', 't4', 't5']);
    });

    test('AC-054: 済みも表示が ON なら済みの項目も出す', () {
      final view = buildAllView(tree, today, showDone: true);
      expect(visibleIds(view), [
        'A',
        'X',
        't1',
        't4',
        't5',
        't2',
        't3',
        'doneGoal',
        'done',
        'underDone',
      ]);
    });

    test('AC-052: 目標の進捗は「親の達成で完了」を含めた完了数 / 全タスク数', () {
      final x = buildAllView(tree, today, showDone: false).single.goals.single;
      expect((x.completedTaskCount, x.totalTaskCount), (2, 5));
    });

    test('画面を開いている間に済みにした項目は、OFF でも残す', () {
      final view = buildAllView(
        tree,
        today,
        showDone: false,
        retained: {(kind: ItemKind.goal, id: 'doneGoal')},
      );
      expect(visibleIds(view), ['A', 'X', 't1', 't4', 't5', 'doneGoal']);
    });
  });
}
