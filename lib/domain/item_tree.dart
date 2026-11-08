import 'items.dart';
import 'mutation.dart';
import 'ordering.dart';

/// 目的・目標・タスクの一覧から組み立てた、読み取り専用のツリー（DES-001 4.1、6.3）。
///
/// 3つのコレクションは別々のリスナーで届くので、親が見つからない項目（削除の反映の途中など）が
/// 一時的にありうる。そうした項目はツリーの子としてはたどらない。
final class ItemTree {
  factory ItemTree({
    Iterable<Purpose> purposes = const [],
    Iterable<Goal> goals = const [],
    Iterable<Task> tasks = const [],
  }) => ItemTree._(
    {for (final p in purposes) p.id: p},
    {for (final g in goals) g.id: g},
    {for (final t in tasks) t.id: t},
  );

  ItemTree._(
    Map<String, Purpose> purposes,
    Map<String, Goal> goals,
    Map<String, Task> tasks,
  ) : purposes = Map.unmodifiable(purposes),
      goals = Map.unmodifiable(goals),
      tasks = Map.unmodifiable(tasks) {
    for (final goal in goals.values) {
      (_goalsByPurpose[goal.purposeId] ??= []).add(goal);
    }
    for (final task in tasks.values) {
      (_tasksByGoal[task.goalId] ??= []).add(task);
    }
    for (final list in _goalsByPurpose.values) {
      list.sort(compareByCreatedAt);
    }
  }

  static final empty = ItemTree();

  final Map<String, Purpose> purposes;
  final Map<String, Goal> goals;
  final Map<String, Task> tasks;

  final _goalsByPurpose = <String, List<Goal>>{};
  final _tasksByGoal = <String, List<Task>>{};

  /// すべての目的（作成日時の古い順）。
  List<Purpose> get sortedPurposes => sortByCreatedAt(purposes.values);

  /// 目的の配下の目標（作成日時の古い順）。
  List<Goal> goalsOf(String purposeId) =>
      List.unmodifiable(_goalsByPurpose[purposeId] ?? const <Goal>[]);

  /// 目標の配下のタスク（順不同。画面では [sortTasks] で並べる）。
  List<Task> tasksOf(String goalId) =>
      List.unmodifiable(_tasksByGoal[goalId] ?? const <Task>[]);

  Item? find(ItemRef ref) => switch (ref.kind) {
    ItemKind.purpose => purposes[ref.id],
    ItemKind.goal => goals[ref.id],
    ItemKind.task => tasks[ref.id],
  };

  /// 親の項目。目的、または親が見つからなければ `null`。
  Item? parentOf(Item item) => switch (item) {
    Purpose() => null,
    Goal(:final purposeId) => purposes[purposeId],
    Task(:final goalId) => goals[goalId],
  };

  /// 子の項目（目的なら目標、目標ならタスク）。
  List<Item> childrenOf(Item item) => switch (item) {
    Purpose(:final id) => goalsOf(id),
    Goal(:final id) => tasksOf(id),
    Task() => const [],
  };

  /// 配下（子と孫）の項目。
  List<Item> descendantsOf(Item item) => [
    for (final child in childrenOf(item)) ...[child, ...descendantsOf(child)],
  ];

  /// [mutation] を反映したあとのツリー。書き込みの結果がリスナーから届く前に、
  /// 達成の提案（6.4）を判定するのに使う。
  ItemTree apply(Mutation mutation) {
    final purposes = {...this.purposes};
    final goals = {...this.goals};
    final tasks = {...this.tasks};
    void put(Item item) => switch (item) {
      Purpose() => purposes[item.id] = item,
      Goal() => goals[item.id] = item,
      Task() => tasks[item.id] = item,
    };
    for (final write in mutation.writes) {
      switch (write) {
        case CreateItem(:final item):
          put(item);
        case UpdateItem(:final after):
          put(after);
        case DeleteItem(:final ref):
          switch (ref.kind) {
            case ItemKind.purpose:
              purposes.remove(ref.id);
            case ItemKind.goal:
              goals.remove(ref.id);
            case ItemKind.task:
              tasks.remove(ref.id);
          }
      }
    }
    return ItemTree._(purposes, goals, tasks);
  }
}
