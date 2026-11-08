import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/item_tree.dart';
import '../domain/items.dart';
import '../domain/mutation.dart';
import '../domain/operations.dart';
import '../domain/suggestions.dart';
import '../providers/providers.dart';
import 'common.dart';

/// 画面の操作から書き込みまでの流れ（確認ダイアログ・達成の提案を含む）。
///
/// [onCommitted] には反映した書き込みを渡す。画面はこれで、済みにした項目を開き直すまで表示に残す。

typedef CommitCallback = void Function(Mutation mutation);

/// タスクの完了を切り替える（FR-006）。完了にして目標のタスクがすべて済みになったら、
/// 目標の達成を提案する（FR-008）。
Future<void> toggleTaskFlow(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  required CommitCallback onCommitted,
}) async {
  final (tree, writer) = _read(ref);
  if (tree == null || writer == null) return;
  final mutation = tree.toggleTask(task.id);
  writer.commit(mutation);
  onCommitted(mutation);

  final after = tree.apply(mutation);
  final goal = suggestGoalAfterTaskCompleted(after, task.id);
  if (goal == null || !context.mounted) return;
  final accepted = await _showSuggestion(
    context,
    title: '目標の達成',
    message: '目標「${goal.name}」に紐付くすべてのタスクが完了しました。この目標を達成にしますか？',
  );
  if (!accepted || !context.mounted) return;
  await _achieve(context, ref, after, goal.ref, onCommitted: onCommitted);
}

/// 目的・目標を達成にする（FR-007）。配下に未済みの項目があれば確認する。
/// 目標を達成にして目的の目標がすべて済みになったら、目的の達成を提案する（FR-008）。
Future<void> achieveFlow(
  BuildContext context,
  WidgetRef ref,
  Item item, {
  required CommitCallback onCommitted,
}) async {
  final (tree, _) = _read(ref);
  if (tree == null) return;
  await _achieve(context, ref, tree, item.ref, onCommitted: onCommitted);
}

/// 目的・目標の達成を取り消す（FR-007）。
void unachieveFlow(
  WidgetRef ref,
  Item item, {
  required CommitCallback onCommitted,
}) {
  final (tree, writer) = _read(ref);
  if (tree == null || writer == null) return;
  final mutation = tree.unachieve(item.ref);
  writer.commit(mutation);
  onCommitted(mutation);
}

/// 項目を配下ごと削除する（6.3.2）。必ず確認し、一緒に削除される配下の件数を示す。
Future<void> deleteFlow(BuildContext context, WidgetRef ref, Item item) async {
  final (tree, writer) = _read(ref);
  if (tree == null || writer == null) return;
  final plan = tree.delete(item.ref);
  final message = plan.counts.isEmpty
      ? '「${item.name}」を削除しますか？'
      : '「${item.name}」を削除しますか？\n配下の${describeCounts(plan.counts)}も一緒に削除されます。';
  final confirmed = await showConfirmDialog(
    context,
    title: '${_kindLabel(item.kind)}の削除',
    message: message,
    confirmLabel: '削除する',
    destructive: true,
  );
  if (!confirmed) return;
  writer.commit(plan.mutation);
}

/// 「目標 2 件とタスク 3 件」。
String describeCounts(DescendantCounts counts) => [
  if (counts.goals > 0) '目標 ${counts.goals} 件',
  if (counts.tasks > 0) 'タスク ${counts.tasks} 件',
].join('と');

String _kindLabel(ItemKind kind) => switch (kind) {
  ItemKind.purpose => '目的',
  ItemKind.goal => '目標',
  ItemKind.task => 'タスク',
};

(ItemTree?, ItemWriter?) _read(WidgetRef ref) =>
    (ref.read(itemTreeProvider).value, ref.read(itemWriterProvider));

/// [tree] は、直前の書き込みを反映したツリー（リスナーからの反映を待たずに次へ進むため）。
Future<void> _achieve(
  BuildContext context,
  WidgetRef ref,
  ItemTree tree,
  ItemRef target, {
  required CommitCallback onCommitted,
}) async {
  final writer = ref.read(itemWriterProvider);
  final item = tree.find(target);
  if (writer == null || item == null || !tree.canAchieve(item)) return;
  final plan = tree.achieve(target);
  if (!plan.counts.isEmpty) {
    final confirmed = await showConfirmDialog(
      context,
      title: '${_kindLabel(item.kind)}の達成',
      message:
          '「${item.name}」を達成にしますか？\n配下の未済みの${describeCounts(plan.counts)}も一緒に済みになります。',
      confirmLabel: '達成にする',
    );
    if (!confirmed) return;
  }
  writer.commit(plan.mutation);
  onCommitted(plan.mutation);

  if (item is! Goal || !context.mounted) return;
  final after = tree.apply(plan.mutation);
  final purpose = suggestPurposeAfterGoalAchieved(after, item.id);
  if (purpose == null) return;
  final accepted = await _showSuggestion(
    context,
    title: '目的の達成',
    message: '目的「${purpose.name}」に紐付くすべての目標が達成されました。この目的を達成にしますか？',
  );
  if (!accepted || !context.mounted) return;
  await _achieve(context, ref, after, purpose.ref, onCommitted: onCommitted);
}

Future<bool> _showSuggestion(
  BuildContext context, {
  required String title,
  required String message,
}) => showConfirmDialog(
  context,
  title: title,
  message: message,
  confirmLabel: '達成にする',
  cancelLabel: '後で',
);
