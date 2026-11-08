import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  final signedIn = FakeAuthRepository.new;

  /// [name] のタスクの行のチェックボックス。
  Finder checkboxOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
    matching: find.byType(Checkbox),
  );

  Text textOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text));

  testWidgets('AC-010: 目的・目標のまとまりで出し、対象のない目的・目標は出さない', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [
          purpose('A', name: '転職するために', createdOrder: 1),
          purpose('B', name: '生活を回すために', createdOrder: 2),
        ],
        goals: [
          goal('X', 'A', name: '内定を得る'),
          goal('Y', 'B', name: '日常'),
        ],
        tasks: [
          task('T', 'X', name: '職務経歴書を直す', scheduledDate: date('2026-11-06')),
          task('U', 'Y', name: 'ゴミ出し', scheduledDate: date('2026-11-07')),
        ],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );

    expect(find.text('転職するために'), findsOneWidget);
    expect(find.text('内定を得る'), findsOneWidget);
    expect(find.text('職務経歴書を直す'), findsOneWidget);
    expect(find.text('生活を回すために'), findsNothing);
    expect(find.text('日常'), findsNothing);
    expect(find.text('ゴミ出し'), findsNothing);
  });

  testWidgets('AC-011: 対象がなければメッセージを出す', (tester) async {
    await pumpApp(tester, auth: signedIn(signedInAs: 'uid'));
    expect(find.text('今日やるべきタスクはありません'), findsOneWidget);
  });

  testWidgets('AC-008: 期限切れの予定日は強調して出す', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('late', 'X', scheduledDate: date('2026-11-04')),
          task('now', 'X', scheduledDate: date('2026-11-06')),
        ],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );
    final errorColor = Theme.of(tester.element(find.text('11/4')))
        .colorScheme
        .error;
    expect(textOf(tester, '11/4').style?.color, errorColor);
    expect(textOf(tester, '11/6').style?.color, isNot(errorColor));
  });

  testWidgets('AC-012: 完了にしたタスクは打ち消し線で残り、開き直すと消える', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T', 'X', name: 'T', scheduledDate: date('2026-11-06')),
          task('U', 'X', name: 'U', scheduledDate: date('2026-11-06')),
        ],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );

    await tester.tap(checkboxOf('T'));
    await tester.pumpAndSettle();
    expect(items.tree.tasks['T']!.status, TaskStatus.complete);
    expect(textOf(tester, 'T').style?.decoration, TextDecoration.lineThrough);

    // その場で未完了に戻せる
    await tester.tap(checkboxOf('T'));
    await tester.pumpAndSettle();
    expect(items.tree.tasks['T']!.status, TaskStatus.incomplete);

    await tester.tap(checkboxOf('T'));
    await tester.pumpAndSettle();

    // 画面を開き直す
    await tester.tap(find.text('すべて'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日').last);
    await tester.pumpAndSettle();
    expect(find.text('T'), findsNothing);
    expect(find.text('U'), findsOneWidget);
  });

  testWidgets('AC-013: 新規タスクの予定日の初期値は今日で、目標を選ばないと作れない', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P', name: '目標X')],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );

    await tester.tap(find.widgetWithText(FloatingActionButton, 'タスク'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('11/6'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextFormField, '名前'), '新しいタスク');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('目標を選択してください'), findsOneWidget);
    expect(items.commits, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('purpose P / 目標X').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final created = items.tree.tasks.values.single;
    expect(created.name, '新しいタスク');
    expect(created.goalId, 'X');
    expect(created.scheduledDate, date('2026-11-06'));
    expect(find.text('新しいタスク'), findsOneWidget);
  });

  testWidgets('AC-015: 開いたまま日付が変わると、新しい日付で判定する', (tester) async {
    final clock = FakeClock(DateTime(2026, 11, 6, 23, 59));
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [
          task('T', 'X', name: 'T', scheduledDate: date('2026-11-06')),
          task('U', 'X', name: 'U', scheduledDate: date('2026-11-07')),
        ],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
      clock: clock,
    );
    expect(find.text('U'), findsNothing);

    clock.now = DateTime(2026, 11, 7, 0, 1);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('U'), findsOneWidget);
    final errorColor = Theme.of(tester.element(find.text('11/6')))
        .colorScheme
        .error;
    expect(textOf(tester, '11/6').style?.color, errorColor);
  });

  testWidgets('AC-045, AC-046, AC-050: 提案は連続して出て、受諾すると達成になる', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P', name: '目的P')],
        goals: [goal('X', 'P', name: '目標X')],
        tasks: [task('T', 'X', name: 'T', scheduledDate: date('2026-11-06'))],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );

    await tester.tap(checkboxOf('T'));
    await tester.pumpAndSettle();
    expect(
      find.text('目標「目標X」に紐付くすべてのタスクが完了しました。この目標を達成にしますか？'),
      findsOneWidget,
    );
    await tester.tap(find.text('達成にする'));
    await tester.pumpAndSettle();
    expect(items.tree.goals['X']!.status, GoalStatus.achieved);

    expect(
      find.text('目的「目的P」に紐付くすべての目標が達成されました。この目的を達成にしますか？'),
      findsOneWidget,
    );
    await tester.tap(find.text('達成にする'));
    await tester.pumpAndSettle();
    expect(items.tree.purposes['P']!.status, PurposeStatus.achieved);
  });

  testWidgets('AC-049: 提案を「後で」にすると何も変わらない', (tester) async {
    final items = FakeItemRepository(
      ItemTree(
        purposes: [purpose('P')],
        goals: [goal('X', 'P')],
        tasks: [task('T', 'X', name: 'T', scheduledDate: date('2026-11-06'))],
      ),
    );
    await pumpApp(
      tester,
      auth: signedIn(signedInAs: 'uid'),
      items: items,
    );

    await tester.tap(checkboxOf('T'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('後で'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(items.tree.goals['X']!.status, GoalStatus.unachieved);
    expect(items.tree.tasks['T']!.status, TaskStatus.complete);
  });
}
