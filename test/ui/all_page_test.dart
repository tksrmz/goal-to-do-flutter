import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  Future<FakeItemRepository> openAll(WidgetTester tester, ItemTree tree) async {
    final items = FakeItemRepository(tree);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(signedInAs: 'uid'),
      items: items,
    );
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();
    return items;
  }

  /// [name] の行にある、[tooltip] の操作ボタン。
  Finder actionOf(String name, String tooltip) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
    matching: find.byTooltip(tooltip),
  );

  testWidgets('AC-051: 初期状態ですべて開いており、開閉できる。開き直すと開いた状態に戻る', (tester) async {
    await openAll(
      tester,
      ItemTree(
        purposes: [purpose('A', name: '目的A')],
        goals: [goal('X', 'A', name: '目標X')],
        tasks: [task('T', 'X', name: 'タスクT')],
      ),
    );
    expect(find.text('目標X'), findsOneWidget);
    expect(find.text('タスクT'), findsOneWidget);

    await tester.tap(actionOf('目的A', '閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('目標X'), findsNothing);
    expect(find.text('タスクT'), findsNothing);

    await tester.tap(actionOf('目的A', '開く'));
    await tester.pumpAndSettle();
    expect(find.text('タスクT'), findsOneWidget);

    await tester.tap(actionOf('目的A', '閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();
    expect(find.text('タスクT'), findsOneWidget);
  });

  testWidgets('AC-052: 目標の行に期日と進捗を出す', (tester) async {
    await openAll(
      tester,
      ItemTree(
        purposes: [purpose('A')],
        goals: [goal('X', 'A', name: '目標X')],
        tasks: [
          for (var i = 0; i < 5; i++)
            task(
              't$i',
              'X',
              status: i < 2 ? TaskStatus.complete : TaskStatus.incomplete,
            ),
        ],
      ),
    );
    expect(find.text('期日 2027/3/31'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets('AC-053, AC-054: 済みの項目は初期状態で隠れ、「済みも表示」で出る', (tester) async {
    await openAll(
      tester,
      ItemTree(
        purposes: [
          purpose('A', name: '目的A'),
          purpose('D', name: '達成した目的', status: PurposeStatus.achieved),
        ],
        goals: [
          goal('X', 'A', name: '目標X'),
          goal('G', 'A', name: '達成した目標', status: GoalStatus.achieved),
        ],
        tasks: [task('T', 'X', name: '完了したタスク', status: TaskStatus.complete)],
      ),
    );
    expect(find.text('達成した目的'), findsNothing);
    expect(find.text('達成した目標'), findsNothing);
    expect(find.text('完了したタスク'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('達成した目的'), findsOneWidget);
    expect(find.text('達成した目標'), findsOneWidget);
    expect(find.text('完了したタスク'), findsOneWidget);
  });

  testWidgets('AC-016, AC-017: 名前を入れて目的を作成でき、空では作れない', (tester) async {
    final items = await openAll(tester, ItemTree.empty);
    await tester.tap(find.text('新規目的'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(items.commits, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '健康のために');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(items.tree.purposes.values.single.name, '健康のために');
    expect(find.text('健康のために'), findsOneWidget);
  });

  testWidgets('編集中に同期で作成日時が入っても保存でき、作成日時は保たれる', (tester) async {
    final pending = task('T', 'X', name: 'タスクT', pending: true);
    final items = await openAll(
      tester,
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [pending],
      ),
    );
    await tester.tap(actionOf('タスクT', '編集'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'タスクT'), '新しい名前');

    // フォームを開いている間に、サーバーの作成日時が届く
    final synced = pending.copyWith(createdAt: createdAt(5));
    items.receive(synced);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(items.tree.tasks['T'], synced.copyWith(name: '新しい名前'));
  });

  testWidgets('AC-023: 目標は名前・期日・達成基準が必須', (tester) async {
    final items = await openAll(
      tester,
      ItemTree(purposes: [purpose('A', name: '目的A')]),
    );
    await tester.tap(actionOf('目的A', '目標を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(find.text('期日を入力してください'), findsOneWidget);
    expect(find.text('達成基準を入力してください'), findsOneWidget);
    // 「目標を追加」から開いたので、親の目的は選ばれている
    expect(find.text('目的を選択してください'), findsNothing);
    expect(items.commits, isEmpty);
  });

  testWidgets('AC-019, AC-020: 目的の削除は配下の件数を示して確認し、キャンセルなら何もしない', (
    tester,
  ) async {
    final items = await openAll(
      tester,
      ItemTree(
        purposes: [purpose('A', name: '目的A')],
        goals: [goal('X', 'A'), goal('Y', 'A')],
        tasks: [task('x1', 'X'), task('y1', 'Y'), task('y2', 'Y')],
      ),
    );
    await tester.tap(actionOf('目的A', '削除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('配下の目標 2 件とタスク 3 件も一緒に削除されます'), findsOneWidget);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(items.commits, isEmpty);

    await tester.tap(actionOf('目的A', '削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(items.tree.purposes, isEmpty);
    expect(items.tree.goals, isEmpty);
    expect(items.tree.tasks, isEmpty);
    expect(find.text('目的A'), findsNothing);
  });

  testWidgets('AC-038, AC-041: 目標の達成は件数を確認し、取り消すと元に戻る', (tester) async {
    final items = await openAll(
      tester,
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P', name: '目標X')],
        tasks: [
          task('T1', 'X', name: 'T1', status: TaskStatus.complete),
          task('T2', 'X', name: 'T2'),
        ],
      ),
    );
    await tester.tap(actionOf('目標X', '達成'));
    await tester.pumpAndSettle();
    expect(find.textContaining('配下の未済みのタスク 1 件も一緒に済みになります'), findsOneWidget);
    await tester.tap(find.text('達成にする'));
    await tester.pumpAndSettle();
    expect(items.tree.goals['X']!.status, GoalStatus.achieved);
    expect(items.tree.tasks['T2']!.status, TaskStatus.completeByParent);
    // 目的の配下の目標がすべて達成になったので、目的の達成の提案が出る（ここでは後で）
    expect(find.textContaining('この目的を達成にしますか？'), findsOneWidget);
    await tester.tap(find.text('後で'));
    await tester.pumpAndSettle();
    // 操作中に済みにした項目は、開き直すまで残る
    expect(find.text('目標X'), findsOneWidget);

    await tester.tap(actionOf('目標X', '達成を取り消す'));
    await tester.pumpAndSettle();
    expect(items.tree.goals['X']!.status, GoalStatus.unachieved);
    expect(items.tree.tasks['T1']!.status, TaskStatus.complete);
    expect(items.tree.tasks['T2']!.status, TaskStatus.incomplete);
  });

  testWidgets('AC-040: 配下がすべて済みなら確認なしで達成になる', (tester) async {
    final items = await openAll(
      tester,
      ItemTree(
        purposes: [purpose('P'), purpose('Q', createdOrder: 1)],
        goals: [
          goal('X', 'P', name: '目標X'),
          goal('Y', 'P'),
        ],
        tasks: [task('T1', 'X', status: TaskStatus.complete)],
      ),
    );
    await tester.tap(actionOf('目標X', '達成'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(items.tree.goals['X']!.status, GoalStatus.achieved);
  });

  testWidgets('AC-043: 済みの親の配下は変更できず、済みの目標にタスクを追加できない', (tester) async {
    await openAll(
      tester,
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P', name: '目標X', status: GoalStatus.achieved)],
        tasks: [
          task('T', 'X', name: 'タスクT', status: TaskStatus.completeByParent),
        ],
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('タスクT'), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find
            .ancestor(of: find.text('タスクT'), matching: find.byType(Row))
            .first,
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.onChanged, isNull);
    expect(actionOf('タスクT', '編集'), findsNothing);
    expect(actionOf('タスクT', '削除'), findsNothing);
    expect(actionOf('目標X', 'タスクを追加'), findsNothing);
    expect(actionOf('目標X', '達成を取り消す'), findsOneWidget);
  });
}
