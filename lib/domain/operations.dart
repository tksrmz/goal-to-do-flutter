import 'item_tree.dart';
import 'items.dart';
import 'mutation.dart';

/// 操作ルール（REQ-001 6.3）。ツリーから書き換え先を決め、一括で反映する [Mutation] を組み立てる。

/// ルール上できない操作をしようとした。画面では操作を出さないので、通常は起きない。
final class OperationNotAllowed(final String message) implements Exception {
  @override
  String toString() => 'OperationNotAllowed: $message';
}

/// 一緒に書き換わる配下の件数（確認ダイアログに出す）。
typedef DescendantCounts = ({int goals, int tasks});

extension DescendantCountsX on DescendantCounts {
  bool get isEmpty => goals == 0 && tasks == 0;
}

DescendantCounts _count(Iterable<Item> items) => (
  goals: items.whereType<Goal>().length,
  tasks: items.whereType<Task>().length,
);

/// 確認が必要な操作の内容。[counts] が空でなければ、実行前に確認ダイアログを出す。
typedef OperationPlan = ({Mutation mutation, DescendantCounts counts});

extension ItemOperations on ItemTree {
  // ---- 何ができるか（6.3.6 済みの親の配下は読み取り専用） ----

  /// 編集・削除・状態の変更ができるか。親が済みなら読み取り専用。
  bool canModify(Item item) => !(parentOf(item)?.isDone ?? false);

  /// 子を追加できるか（6.3.1 新しい親として選べるのは未済みの項目のみ）。
  bool canAddChild(Item item) =>
      item is! Task && canModify(item) && !item.isDone;

  /// 目的・目標を達成にできるか。
  bool canAchieve(Item item) => switch (item) {
    Purpose(:final status) => status == PurposeStatus.unachieved,
    Goal(:final status) => status == GoalStatus.unachieved && canModify(item),
    Task() => false,
  };

  /// 目的・目標の達成を取り消せるか。自分で達成したもの（`achieved`）だけが対象（6.3.4）。
  bool canUnachieve(Item item) => switch (item) {
    Purpose(:final status) => status == PurposeStatus.achieved,
    Goal(:final status) => status == GoalStatus.achieved && canModify(item),
    Task() => false,
  };

  /// タスクの完了を切り替えられるか（6.3.5）。
  bool canToggleTask(Task task) =>
      canModify(task) && task.status != TaskStatus.completeByParent;

  /// 親として選べる目的（未達成のもの、作成日時の古い順）。
  List<Purpose> get selectablePurposes => [
    for (final purpose in sortedPurposes)
      if (!purpose.isDone) purpose,
  ];

  /// 親として選べる目標（未達成のもの。目的ごとに、作成日時の古い順）。
  List<Goal> get selectableGoals => [
    for (final purpose in selectablePurposes)
      for (final goal in goalsOf(purpose.id))
        if (!goal.isDone) goal,
  ];

  // ---- 作成・編集（6.3.1） ----

  /// 項目を作成する。親は存在し、未済みでなければならない。
  Mutation create(Item item) {
    if (find(item.ref) != null) {
      throw OperationNotAllowed('${item.ref} already exists');
    }
    _checkNewParent(item);
    return Mutation([CreateItem(item)]);
  }

  /// 項目を編集する（親の付け替えを含む）。状態は [achieve] などで変えるので、ここでは変えない。
  Mutation update(Item after) {
    final before = _require(after.ref);
    if (!canModify(before)) {
      throw OperationNotAllowed('${before.ref} is read-only');
    }
    if (_statusOf(before) != _statusOf(after) ||
        before.createdAt != after.createdAt) {
      throw OperationNotAllowed('update() cannot change status or createdAt');
    }
    if (before.parentId != after.parentId) {
      _checkNewParent(after);
    }
    if (before == after) return Mutation(const []);
    return Mutation([UpdateItem(before, after)]);
  }

  // ---- 削除（6.3.2） ----

  /// 項目と、その配下をすべて削除する。
  OperationPlan delete(ItemRef ref) {
    final item = _require(ref);
    if (!canModify(item)) {
      throw OperationNotAllowed('$ref is read-only');
    }
    final descendants = descendantsOf(item);
    return (
      mutation: Mutation([
        DeleteItem(ref),
        for (final d in descendants) DeleteItem(d.ref),
      ]),
      counts: _count(descendants),
    );
  }

  // ---- 達成（6.3.3） ----

  /// 目的・目標を達成にし、配下の未済みの項目を「親の達成で済み」にする。
  /// [OperationPlan.counts] は、一緒に済みになる配下の件数。
  OperationPlan achieve(ItemRef ref) {
    final item = _require(ref);
    if (!canAchieve(item)) {
      throw OperationNotAllowed('$ref cannot be achieved');
    }
    final changed = [
      for (final d in descendantsOf(item))
        if (!d.isDone) d,
    ];
    return (
      mutation: Mutation([
        UpdateItem(item, _withStatus(item, done: true, byParent: false)),
        for (final d in changed)
          UpdateItem(d, _withStatus(d, done: true, byParent: true)),
      ]),
      counts: _count(changed),
    );
  }

  // ---- 達成の取り消し（6.3.4） ----

  /// 目的・目標の達成を取り消し、「親の達成で済み」の配下を未済みに戻す。
  /// 自分で済みにした子（`achieved` / `complete`）とその配下は変えない。
  Mutation unachieve(ItemRef ref) {
    final item = _require(ref);
    if (!canUnachieve(item)) {
      throw OperationNotAllowed('$ref cannot be unachieved');
    }
    final writes = <ItemWrite>[
      UpdateItem(item, _withStatus(item, done: false, byParent: false)),
    ];
    void revertChildren(Item parent) {
      for (final child in childrenOf(parent)) {
        if (_isDoneByParent(child)) {
          writes.add(
            UpdateItem(child, _withStatus(child, done: false, byParent: false)),
          );
          revertChildren(child);
        }
      }
    }

    revertChildren(item);
    return Mutation(writes);
  }

  // ---- タスクの完了（6.3.5） ----

  /// タスクの完了・未完了を切り替える。親や兄弟には波及しない。
  Mutation toggleTask(String taskId) {
    final task = _require((kind: ItemKind.task, id: taskId)) as Task;
    if (!canToggleTask(task)) {
      throw OperationNotAllowed('${task.ref} cannot be toggled');
    }
    return Mutation([
      UpdateItem(task, _withStatus(task, done: !task.isDone, byParent: false)),
    ]);
  }

  // ---- 内部 ----

  Item _require(ItemRef ref) =>
      find(ref) ?? (throw OperationNotAllowed('$ref not found'));

  void _checkNewParent(Item item) {
    final parentId = item.parentId;
    if (parentId == null) return;
    final parent = parentOf(item);
    if (parent == null) {
      throw OperationNotAllowed('parent $parentId of ${item.ref} not found');
    }
    if (parent.isDone || !canModify(parent)) {
      throw OperationNotAllowed('parent ${parent.ref} is done');
    }
  }
}

Object _statusOf(Item item) => switch (item) {
  Purpose(:final status) => status,
  Goal(:final status) => status,
  Task(:final status) => status,
};

bool _isDoneByParent(Item item) => switch (item) {
  Purpose() => false,
  Goal(:final status) => status == GoalStatus.achievedByParent,
  Task(:final status) => status == TaskStatus.completeByParent,
};

Item _withStatus(Item item, {required bool done, required bool byParent}) =>
    switch (item) {
      Purpose() => item.copyWith(
        status: done ? PurposeStatus.achieved : PurposeStatus.unachieved,
      ),
      Goal() => item.copyWith(
        status: !done
            ? GoalStatus.unachieved
            : byParent
            ? GoalStatus.achievedByParent
            : GoalStatus.achieved,
      ),
      Task() => item.copyWith(
        status: !done
            ? TaskStatus.incomplete
            : byParent
            ? TaskStatus.completeByParent
            : TaskStatus.complete,
      ),
    };
