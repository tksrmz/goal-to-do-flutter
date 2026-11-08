import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/calendar_date.dart';
import '../domain/item_tree.dart';
import '../domain/items.dart';
import '../domain/mutation.dart';
import '../domain/operations.dart';
import '../providers/providers.dart';
import 'common.dart';

/// 目的・目標・タスクの入力フォーム（REQ-001 7.4）。ダイアログで開き、保存したら閉じる。
/// キャンセルすると変更を破棄して閉じる。
///
/// [onSaved] には反映した書き込みを渡す（画面側で、作った項目を開いた状態にするなどに使う）。

Future<void> showPurposeForm(
  BuildContext context, {
  Purpose? initial,
  void Function(Mutation mutation)? onSaved,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PurposeForm(initial: initial, onSaved: onSaved),
);

Future<void> showGoalForm(
  BuildContext context, {
  Goal? initial,
  String? purposeId,
  void Function(Mutation mutation)? onSaved,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _GoalForm(initial: initial, purposeId: purposeId, onSaved: onSaved),
);

Future<void> showTaskForm(
  BuildContext context, {
  Task? initial,
  String? goalId,
  CalendarDate? scheduledDate,
  void Function(Mutation mutation)? onSaved,
}) => showDialog<void>(
  context: context,
  builder: (_) => _TaskForm(
    initial: initial,
    goalId: goalId,
    scheduledDate: scheduledDate,
    onSaved: onSaved,
  ),
);

// ---- 共通 ----

String? _requiredName(String? value) =>
    (value ?? '').trim().isEmpty ? '名前を入力してください' : null;

String? _optionalText(String text) => text.trim().isEmpty ? null : text;

/// 入力を保存する。作成・編集の可否はツリーで確かめ、できなければメッセージを出す。
void _save(
  BuildContext context,
  WidgetRef ref,
  Mutation Function(ItemTree tree) build,
  void Function(Mutation mutation)? onSaved,
) {
  final writer = ref.read(itemWriterProvider);
  final tree = ref.read(itemTreeProvider).value;
  if (writer == null || tree == null) return;
  final Mutation mutation;
  try {
    mutation = build(tree);
  } on OperationNotAllowed {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この項目は変更できません。画面の表示を確認してください')),
    );
    return;
  }
  writer.commit(mutation);
  onSaved?.call(mutation);
  Navigator.of(context).pop();
}

class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.formKey,
    required this.onSubmit,
    required this.children,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: onSubmit, child: const Text('保存')),
      ],
    );
  }
}

// ---- 目的 ----

class _PurposeForm extends ConsumerStatefulWidget {
  const _PurposeForm({this.initial, this.onSaved});

  final Purpose? initial;
  final void Function(Mutation mutation)? onSaved;

  @override
  ConsumerState<_PurposeForm> createState() => _PurposeFormState();
}

class _PurposeFormState extends ConsumerState<_PurposeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final description = _optionalText(_description.text);
    _save(context, ref, (tree) {
      if (widget.initial case final initial?) {
        return tree.update(
          initial.copyWith(name: name, description: description),
        );
      }
      final writer = ref.read(itemWriterProvider)!;
      return tree.create(
        Purpose(
          id: writer.newId(ItemKind.purpose),
          name: name,
          description: description,
        ),
      );
    }, widget.onSaved);
  }

  @override
  Widget build(BuildContext context) {
    return _FormDialog(
      title: widget.initial == null ? '目的を作成' : '目的を編集',
      formKey: _formKey,
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: nameMaxLength,
          decoration: const InputDecoration(
            labelText: '名前',
            hintText: '〇〇のために',
          ),
          validator: _requiredName,
        ),
        TextFormField(
          controller: _description,
          maxLength: longTextMaxLength,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '説明文'),
        ),
      ],
    );
  }
}

// ---- 目標 ----

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.initial, this.purposeId, this.onSaved});

  final Goal? initial;
  final String? purposeId;
  final void Function(Mutation mutation)? onSaved;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late final _criteria = TextEditingController(
    text: widget.initial?.achievementCriteria,
  );
  late CalendarDate? _dueDate = widget.initial?.dueDate;
  late String? _purposeId = widget.initial?.purposeId ?? widget.purposeId;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _criteria.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final name = _name.text.trim();
    final description = _optionalText(_description.text);
    final criteria = _criteria.text.trim();
    final dueDate = _dueDate!;
    final purposeId = _purposeId!;
    _save(context, ref, (tree) {
      if (widget.initial case final initial?) {
        return tree.update(
          initial.copyWith(
            name: name,
            description: description,
            achievementCriteria: criteria,
            dueDate: dueDate,
            purposeId: purposeId,
          ),
        );
      }
      final writer = ref.read(itemWriterProvider)!;
      return tree.create(
        Goal(
          id: writer.newId(ItemKind.goal),
          purposeId: purposeId,
          name: name,
          description: description,
          dueDate: dueDate,
          achievementCriteria: criteria,
        ),
      );
    }, widget.onSaved);
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(itemTreeProvider).value ?? ItemTree.empty;
    final today = ref.watch(todayProvider);
    final options = tree.selectablePurposes;
    // 選択中の親が選択肢から消えたら（別のタブで達成した等）、未選択に戻す
    final selected = options.any((p) => p.id == _purposeId) ? _purposeId : null;
    return _FormDialog(
      title: widget.initial == null ? '目標を作成' : '目標を編集',
      formKey: _formKey,
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: nameMaxLength,
          decoration: const InputDecoration(labelText: '名前'),
          validator: _requiredName,
        ),
        TextFormField(
          controller: _description,
          maxLength: longTextMaxLength,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '説明文'),
        ),
        DateFormField(
          label: '期日',
          today: today,
          initialValue: _dueDate,
          validator: (value) => value == null ? '期日を入力してください' : null,
          onSaved: (value) => _dueDate = value,
        ),
        TextFormField(
          controller: _criteria,
          maxLength: longTextMaxLength,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(labelText: '達成基準'),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? '達成基準を入力してください' : null,
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '目的'),
          items: [
            for (final purpose in options)
              DropdownMenuItem(
                value: purpose.id,
                child: Text(purpose.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _purposeId = value),
          validator: (value) => value == null ? '目的を選択してください' : null,
        ),
      ],
    );
  }
}

// ---- タスク ----

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({
    this.initial,
    this.goalId,
    this.scheduledDate,
    this.onSaved,
  });

  final Task? initial;
  final String? goalId;
  final CalendarDate? scheduledDate;
  final void Function(Mutation mutation)? onSaved;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late CalendarDate? _scheduledDate =
      widget.initial?.scheduledDate ?? widget.scheduledDate;
  late bool _important = widget.initial?.important ?? false;
  late bool _urgent = widget.initial?.urgent ?? false;
  late String? _goalId = widget.initial?.goalId ?? widget.goalId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    final name = _name.text.trim();
    final goalId = _goalId!;
    _save(context, ref, (tree) {
      if (widget.initial case final initial?) {
        return tree.update(
          initial.copyWith(
            name: name,
            scheduledDate: _scheduledDate,
            important: _important,
            urgent: _urgent,
            goalId: goalId,
          ),
        );
      }
      final writer = ref.read(itemWriterProvider)!;
      return tree.create(
        Task(
          id: writer.newId(ItemKind.task),
          goalId: goalId,
          name: name,
          scheduledDate: _scheduledDate,
          important: _important,
          urgent: _urgent,
        ),
      );
    }, widget.onSaved);
  }

  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(itemTreeProvider).value ?? ItemTree.empty;
    final today = ref.watch(todayProvider);
    final options = tree.selectableGoals;
    final selected = options.any((g) => g.id == _goalId) ? _goalId : null;
    return _FormDialog(
      title: widget.initial == null ? 'タスクを作成' : 'タスクを編集',
      formKey: _formKey,
      onSubmit: _submit,
      children: [
        TextFormField(
          controller: _name,
          autofocus: true,
          maxLength: nameMaxLength,
          decoration: const InputDecoration(labelText: '名前'),
          validator: _requiredName,
        ),
        DateFormField(
          label: '予定日',
          today: today,
          clearable: true,
          initialValue: _scheduledDate,
          onSaved: (value) => _scheduledDate = value,
        ),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('重要'),
                value: _important,
                onChanged: (value) => setState(() => _important = value!),
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('緊急'),
                value: _urgent,
                onChanged: (value) => setState(() => _urgent = value!),
              ),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '目標'),
          items: [
            for (final goal in options)
              DropdownMenuItem(
                value: goal.id,
                child: Text(
                  '${tree.purposes[goal.purposeId]?.name ?? ''} / ${goal.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _goalId = value),
          validator: (value) => value == null ? '目標を選択してください' : null,
        ),
      ],
    );
  }
}
