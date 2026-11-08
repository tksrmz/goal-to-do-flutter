import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/calendar_date.dart';
import '../domain/item_tree.dart';
import '../domain/items.dart';
import '../domain/mutation.dart';
import '../domain/operations.dart';
import '../domain/views.dart';
import '../providers/providers.dart';
import 'app_shell.dart';
import 'common.dart';
import 'item_flows.dart';
import 'item_forms.dart';
import 'task_row.dart';

/// すべて（FR-003〜FR-010、REQ-001 7.2）。目的と目標の2段のアコーディオンで、全項目を出す。
///
/// 開閉と「済みも表示」の状態は保存しない。画面を開き直すと、すべて開いて済みを隠した状態に戻る。
class AllPage extends ConsumerStatefulWidget {
  const AllPage({super.key});

  @override
  ConsumerState<AllPage> createState() => _AllPageState();
}

class _AllPageState extends ConsumerState<AllPage> {
  bool _showDone = false;

  /// 閉じている目的・目標。ここにないものは開いている（追加した項目も開いた状態で出る）。
  final _collapsed = <ItemRef>{};

  /// この画面を開いている間に済みにした項目。画面を開き直すまで残す。
  final _retained = <ItemRef>{};

  void _retain(Mutation mutation) {
    final refs = mutation.newlyDone;
    if (refs.isNotEmpty && mounted) setState(() => _retained.addAll(refs));
  }

  void _toggleExpanded(ItemRef ref) => setState(
    () =>
        _collapsed.contains(ref) ? _collapsed.remove(ref) : _collapsed.add(ref),
  );

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final treeAsync = ref.watch(itemTreeProvider);

    final Widget content;
    if (treeAsync.value case final tree?) {
      final nodes = buildAllView(
        tree,
        today,
        showDone: _showDone,
        retained: _retained,
      );
      content = nodes.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('目的がありません。「新規目的」から作成してください')),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final node in nodes) _purposeSection(tree, node, today),
              ],
            );
    } else if (treeAsync.hasError) {
      content = const Center(child: Text('データを読み込めませんでした'));
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return AppShell(
      title: 'すべて',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: treeAsync.hasValue
                      ? () => showPurposeForm(context)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('新規目的'),
                ),
                const Spacer(),
                const Text('済みも表示'),
                Switch(
                  value: _showDone,
                  onChanged: (value) => setState(() => _showDone = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _purposeSection(
    ItemTree tree,
    AllPurposeNode node,
    CalendarDate today,
  ) {
    final purpose = node.purpose;
    final expanded = !_collapsed.contains(purpose.ref);
    final theme = Theme.of(context);
    return Card(
      key: ValueKey(purpose.ref),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ItemHeader(
              item: purpose,
              expanded: expanded,
              onToggleExpanded: () => _toggleExpanded(purpose.ref),
              titleStyle: theme.textTheme.titleMedium,
              details: const [],
              actions: _actionsFor(tree, purpose),
            ),
            if (expanded) ...[
              if (purpose.description case final description?)
                _Note(text: description),
              for (final goal in node.goals) _goalSection(tree, goal, today),
            ],
          ],
        ),
      ),
    );
  }

  Widget _goalSection(ItemTree tree, AllGoalNode node, CalendarDate today) {
    final goal = node.goal;
    final expanded = !_collapsed.contains(goal.ref);
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey(goal.ref),
      padding: const EdgeInsets.only(left: 24, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemHeader(
            item: goal,
            expanded: expanded,
            onToggleExpanded: () => _toggleExpanded(goal.ref),
            titleStyle: theme.textTheme.titleSmall,
            details: [
              Text('期日 ${formatDate(goal.dueDate, today)}'),
              Text(
                '${node.completedTaskCount}/${node.totalTaskCount}',
                key: ValueKey('progress-${goal.id}'),
              ),
            ],
            actions: _actionsFor(tree, goal),
          ),
          if (expanded) ...[
            _Note(label: '達成基準', text: goal.achievementCriteria),
            if (goal.description case final description?)
              _Note(text: description),
            for (final task in node.tasks)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: TaskRow(
                  key: ValueKey(task.ref),
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
                  trailing: _ActionBar(actions: _actionsFor(tree, task)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 各行の操作（REQ-001 7.2）。済みの親の配下では出さない（6.3.6）。
  List<_Action> _actionsFor(ItemTree tree, Item item) {
    if (!tree.canModify(item)) return const [];
    return [
      if (tree.canAddChild(item))
        switch (item) {
          Purpose() => _Action(
            '目標を追加',
            Icons.add,
            () => showGoalForm(context, purposeId: item.id),
          ),
          _ => _Action(
            'タスクを追加',
            Icons.add,
            () => showTaskForm(context, goalId: item.id),
          ),
        },
      _Action('編集', Icons.edit_outlined, () {
        switch (item) {
          case Purpose():
            showPurposeForm(context, initial: item);
          case Goal():
            showGoalForm(context, initial: item);
          case Task():
            showTaskForm(context, initial: item);
        }
      }),
      _Action('削除', Icons.delete_outline, () => deleteFlow(context, ref, item)),
      if (tree.canAchieve(item))
        _Action(
          '達成',
          Icons.flag_outlined,
          () => achieveFlow(context, ref, item, onCommitted: _retain),
        ),
      if (tree.canUnachieve(item))
        _Action(
          '達成を取り消す',
          Icons.undo,
          () => unachieveFlow(ref, item, onCommitted: _retain),
        ),
    ];
  }
}

final class _Action(
  final String label,
  final IconData icon,
  final VoidCallback onPressed,
);

/// 目的・目標の見出しの行。
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.item,
    required this.expanded,
    required this.onToggleExpanded,
    required this.titleStyle,
    required this.details,
    required this.actions,
  });

  final Item item;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final TextStyle? titleStyle;
  final List<Widget> details;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = item.isDone;
    return Row(
      children: [
        IconButton(
          tooltip: expanded ? '閉じる' : '開く',
          icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
          onPressed: onToggleExpanded,
        ),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.name,
                style: titleStyle?.copyWith(
                  color: done ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
              if (done)
                Chip(
                  label: const Text('達成'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: theme.textTheme.labelSmall,
                ),
              ...details.map(
                (d) => DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall,
                  child: d,
                ),
              ),
            ],
          ),
        ),
        _ActionBar(actions: actions),
      ],
    );
  }
}

/// 行の操作。広い画面ではボタンを並べ、狭い画面ではメニューにまとめる。
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.actions});

  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    if (MediaQuery.sizeOf(context).width >= 720) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            IconButton(
              tooltip: action.label,
              icon: Icon(action.icon),
              onPressed: action.onPressed,
            ),
        ],
      );
    }
    return PopupMenuButton<_Action>(
      tooltip: '操作',
      onSelected: (action) => action.onPressed(),
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(
            value: action,
            child: ListTile(
              leading: Icon(action.icon),
              title: Text(action.label),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.label});

  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 8, 4),
      child: Text.rich(
        TextSpan(
          children: [
            if (label case final label?)
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            TextSpan(text: text),
          ],
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
