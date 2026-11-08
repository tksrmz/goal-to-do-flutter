import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:goal_to_do/domain/mutation.dart';
import 'package:goal_to_do/domain/operations.dart';

import '../helpers/fixtures.dart';

/// 書き込みの対象を「種類:ID」で並べる。
List<String> refsOf(Mutation mutation) => [
  for (final write in mutation.writes) '${write.ref.kind.name}:${write.ref.id}',
];

/// 更新後の状態を「ID → 状態」で返す。
Map<String, Object> statusesOf(Mutation mutation) => {
  for (final write in mutation.writes)
    if (write case UpdateItem(:final after))
      after.id: switch (after) {
        Purpose(:final status) => status,
        Goal(:final status) => status,
        Task(:final status) => status,
      },
};

ItemRef purposeRef(String id) => (kind: ItemKind.purpose, id: id);
ItemRef goalRef(String id) => (kind: ItemKind.goal, id: id);
ItemRef taskRef(String id) => (kind: ItemKind.task, id: id);

void main() {
  group('削除（6.3.2）', () {
    final tree = ItemTree(
      purposes: [purpose('A'), purpose('B')],
      goals: [goal('X', 'A'), goal('Y', 'A'), goal('Z', 'B')],
      tasks: [
        task('x1', 'X'),
        task('x2', 'X'),
        task('y1', 'Y', status: TaskStatus.complete),
        task('z1', 'Z'),
      ],
    );

    test('AC-019: 目的を削除すると、配下の目標・タスクもすべて削除する', () {
      final plan = tree.delete(purposeRef('A'));
      expect(
        refsOf(plan.mutation),
        unorderedEquals([
          'purpose:A',
          'goal:X',
          'goal:Y',
          'task:x1',
          'task:x2',
          'task:y1',
        ]),
      );
      expect(plan.mutation.writes, everyElement(isA<DeleteItem>()));
      expect(plan.counts, (goals: 2, tasks: 3));
    });

    test('AC-027: 目標を削除すると、配下のタスクも削除する', () {
      final plan = tree.delete(goalRef('X'));
      expect(
        refsOf(plan.mutation),
        unorderedEquals(['goal:X', 'task:x1', 'task:x2']),
      );
      expect(plan.counts, (goals: 0, tasks: 2));
    });

    test('AC-035: タスクの削除はそのタスクのみ', () {
      final plan = tree.delete(taskRef('z1'));
      expect(refsOf(plan.mutation), ['task:z1']);
      expect(plan.counts.isEmpty, isTrue);
    });
  });

  group('達成（6.3.3）', () {
    test('AC-038: 目標を達成にすると、未完了のタスクだけが親の達成で完了になる', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T1', 'X', status: TaskStatus.complete),
          task('T2', 'X'),
        ],
      );
      final plan = tree.achieve(goalRef('X'));
      expect(statusesOf(plan.mutation), {
        'X': GoalStatus.achieved,
        'T2': TaskStatus.completeByParent,
      });
      expect(plan.counts, (goals: 0, tasks: 1));
    });

    test('AC-039: 目的を達成にすると、未済みの目標・タスクが親の達成で済みになる', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [
          goal('G1', 'P', status: GoalStatus.achieved),
          goal('G2', 'P'),
        ],
        tasks: [
          task('T0', 'G1', status: TaskStatus.complete),
          task('T', 'G2'),
        ],
      );
      final plan = tree.achieve(purposeRef('P'));
      expect(statusesOf(plan.mutation), {
        'P': PurposeStatus.achieved,
        'G2': GoalStatus.achievedByParent,
        'T': TaskStatus.completeByParent,
      });
      expect(plan.counts, (goals: 1, tasks: 1));
    });

    test('AC-040: 配下がすべて済みなら、一緒に済みになる件数は0', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [task('T1', 'X', status: TaskStatus.complete)],
      );
      final plan = tree.achieve(goalRef('X'));
      expect(plan.counts.isEmpty, isTrue);
      expect(statusesOf(plan.mutation), {'X': GoalStatus.achieved});
    });

    test('達成済みの項目やタスクは達成にできない', () {
      final tree = ItemTree(
        purposes: [purpose('P', status: PurposeStatus.achieved)],
        goals: [goal('X', 'P', status: GoalStatus.achievedByParent)],
        tasks: [task('T', 'X', status: TaskStatus.completeByParent)],
      );
      expect(
        () => tree.achieve(purposeRef('P')),
        throwsA(isA<OperationNotAllowed>()),
      );
      expect(
        () => tree.achieve(goalRef('X')),
        throwsA(isA<OperationNotAllowed>()),
      );
      expect(
        () => tree.achieve(taskRef('T')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });
  });

  group('達成の取り消し（6.3.4）', () {
    test('REQ-001 6.3.4 の例: 目的を達成し、取り消すと元に戻る', () {
      final before = ItemTree(
        purposes: [purpose('P')],
        goals: [
          goal('G1', 'P', status: GoalStatus.achieved),
          goal('G2', 'P'),
        ],
        tasks: [
          task('T1', 'G2', status: TaskStatus.complete),
          task('T2', 'G2'),
        ],
      );
      final achieved = before.apply(before.achieve(purposeRef('P')).mutation);
      expect(achieved.goals['G1']!.status, GoalStatus.achieved);
      expect(achieved.goals['G2']!.status, GoalStatus.achievedByParent);
      expect(achieved.tasks['T1']!.status, TaskStatus.complete);
      expect(achieved.tasks['T2']!.status, TaskStatus.completeByParent);

      final reverted = achieved.apply(achieved.unachieve(purposeRef('P')));
      expect(reverted.purposes['P']!.status, PurposeStatus.unachieved);
      expect(reverted.goals['G1']!.status, GoalStatus.achieved);
      expect(reverted.goals['G2']!.status, GoalStatus.unachieved);
      expect(reverted.tasks['T1']!.status, TaskStatus.complete);
      expect(reverted.tasks['T2']!.status, TaskStatus.incomplete);
    });

    test('AC-041: 目標の達成を取り消すと、親の達成で完了のタスクだけが未完了に戻る', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P', status: GoalStatus.achieved)],
        tasks: [
          task('T1', 'X', status: TaskStatus.complete),
          task('T2', 'X', status: TaskStatus.completeByParent),
        ],
      );
      expect(statusesOf(tree.unachieve(goalRef('X'))), {
        'X': GoalStatus.unachieved,
        'T2': TaskStatus.incomplete,
      });
    });

    test('AC-042: 自分で達成した目標の配下はたどらない', () {
      final tree = ItemTree(
        purposes: [purpose('P', status: PurposeStatus.achieved)],
        goals: [
          goal('G1', 'P', status: GoalStatus.achieved),
          goal('G2', 'P', status: GoalStatus.achievedByParent),
        ],
        tasks: [
          // G1 の配下は、G1 の達成で完了になったもの
          task('G1t', 'G1', status: TaskStatus.completeByParent),
          task('T', 'G2', status: TaskStatus.completeByParent),
        ],
      );
      expect(statusesOf(tree.unachieve(purposeRef('P'))), {
        'P': PurposeStatus.unachieved,
        'G2': GoalStatus.unachieved,
        'T': TaskStatus.incomplete,
      });
    });

    test('親の達成で達成した目標は、単独では取り消せない', () {
      final tree = ItemTree(
        purposes: [purpose('P', status: PurposeStatus.achieved)],
        goals: [goal('G', 'P', status: GoalStatus.achievedByParent)],
      );
      expect(tree.canUnachieve(tree.goals['G']!), isFalse);
      expect(
        () => tree.unachieve(goalRef('G')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });
  });

  group('タスクの完了（6.3.5）', () {
    final tree = ItemTree(
      purposes: [purpose('P')],
      goals: [goal('X', 'P')],
      tasks: [
        task('T', 'X'),
        task('U', 'X', status: TaskStatus.complete),
      ],
    );

    test('AC-036, AC-037: 完了と未完了を切り替えられ、親や兄弟には波及しない', () {
      expect(statusesOf(tree.toggleTask('T')), {'T': TaskStatus.complete});
      expect(statusesOf(tree.toggleTask('U')), {'U': TaskStatus.incomplete});
    });
  });

  group('済みの親の配下は読み取り専用（6.3.6、AC-043）', () {
    final tree = ItemTree(
      purposes: [purpose('P')],
      goals: [goal('X', 'P', status: GoalStatus.achieved)],
      tasks: [task('T', 'X', status: TaskStatus.completeByParent)],
    );
    final x = tree.goals['X']!;
    final t = tree.tasks['T']!;

    test('配下のタスクは完了切り替え・編集・削除ができない', () {
      expect(tree.canModify(t), isFalse);
      expect(tree.canToggleTask(t), isFalse);
      expect(() => tree.toggleTask('T'), throwsA(isA<OperationNotAllowed>()));
      expect(() => tree.delete(t.ref), throwsA(isA<OperationNotAllowed>()));
      expect(
        () => tree.update(t.copyWith(name: 'changed')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });

    test('済みの目標にはタスクを追加できない', () {
      expect(tree.canAddChild(x), isFalse);
      expect(
        () => tree.create(task('new', 'X')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });

    test('済みの項目そのもの（親は未済み）は編集できる（REQ-001 12章 #6）', () {
      expect(tree.canModify(x), isTrue);
      final mutation = tree.update(x.copyWith(name: '新しい名前'));
      expect(refsOf(mutation), ['goal:X']);
    });
  });

  group('作成・編集・親の付け替え（6.3.1）', () {
    final tree = ItemTree(
      purposes: [
        purpose('A', createdOrder: 1),
        purpose('B', createdOrder: 2),
        purpose('done', status: PurposeStatus.achieved, createdOrder: 3),
      ],
      goals: [
        goal('X', 'A', createdOrder: 1),
        goal('Y', 'B', createdOrder: 2),
        goal('doneGoal', 'A', status: GoalStatus.achieved, createdOrder: 3),
        goal('underDone', 'done', status: GoalStatus.achievedByParent),
      ],
      tasks: [task('T', 'X')],
    );

    test('AC-021, AC-028: 未済みの親の下に作成できる', () {
      expect(refsOf(tree.create(goal('new', 'A'))), ['goal:new']);
      expect(refsOf(tree.create(task('new', 'X'))), ['task:new']);
    });

    test('済みの親や、存在しない親の下には作成できない', () {
      expect(
        () => tree.create(goal('new', 'done')),
        throwsA(isA<OperationNotAllowed>()),
      );
      expect(
        () => tree.create(goal('new', 'missing')),
        throwsA(isA<OperationNotAllowed>()),
      );
      expect(
        () => tree.create(task('new', 'doneGoal')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });

    test('AC-024, AC-031: 親として選べるのは未済みの項目のみ', () {
      expect([for (final p in tree.selectablePurposes) p.id], ['A', 'B']);
      expect([for (final g in tree.selectableGoals) g.id], ['X', 'Y']);
    });

    test('AC-026, AC-034: 未済みの親へ付け替えられる', () {
      final moved = tree.update(tree.goals['X']!.copyWith(purposeId: 'B'));
      expect(refsOf(moved), ['goal:X']);
      expect(refsOf(tree.update(tree.tasks['T']!.copyWith(goalId: 'Y'))), [
        'task:T',
      ]);
    });

    test('済みの親へは付け替えられない', () {
      expect(
        () => tree.update(tree.goals['X']!.copyWith(purposeId: 'done')),
        throwsA(isA<OperationNotAllowed>()),
      );
      expect(
        () => tree.update(tree.tasks['T']!.copyWith(goalId: 'doneGoal')),
        throwsA(isA<OperationNotAllowed>()),
      );
    });

    test('編集では状態を変えられない', () {
      expect(
        () =>
            tree.update(tree.tasks['T']!.copyWith(status: TaskStatus.complete)),
        throwsA(isA<OperationNotAllowed>()),
      );
    });

    test('変更がなければ何も書き込まない', () {
      expect(tree.update(tree.tasks['T']!).isEmpty, isTrue);
    });
  });

  group('Mutation.newlyDone', () {
    test('未済みから済みになった項目だけを返す', () {
      final tree = ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T1', 'X', status: TaskStatus.complete),
          task('T2', 'X'),
        ],
      );
      final plan = tree.achieve(goalRef('X'));
      expect(plan.mutation.newlyDone, {goalRef('X'), taskRef('T2')});
    });
  });
}
