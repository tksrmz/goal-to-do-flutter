import 'package:freezed_annotation/freezed_annotation.dart';

import 'calendar_date.dart';

part 'items.freezed.dart';

/// 項目の種類。目的 → 目標 → タスクの3層のツリーになる（REQ-001 原理1）。
enum ItemKind { purpose, goal, task }

/// 項目の参照。種類とドキュメント ID の組。
typedef ItemRef = ({ItemKind kind, String id});

/// 目的・目標の状態（REQ-001 6.2）。
enum PurposeStatus {
  unachieved,
  achieved;

  bool get isDone => this != unachieved;
}

enum GoalStatus {
  unachieved,
  achieved,

  /// 親の達成で達成。達成の取り消し（6.3.4）でのみ `achieved` と区別する。
  achievedByParent;

  bool get isDone => this != unachieved;
}

enum TaskStatus {
  incomplete,
  complete,

  /// 親の達成で完了。達成の取り消し（6.3.4）でのみ `complete` と区別する。
  completeByParent;

  bool get isDone => this != incomplete;
}

/// 目的・目標・タスクの共通部分。
sealed class Item {
  String get id;
  String get name;

  /// 作成日時（サーバー時刻）。サーバーに届くまでの同期待ちの間は `null`（DES-001 3.4）。
  DateTime? get createdAt;

  ItemKind get kind;

  /// 親の ID。目的は親を持たないので `null`。
  String? get parentId;

  /// 済み（達成・親の達成で達成・完了・親の達成で完了）か。
  bool get isDone;
}

extension ItemRefExtension on Item {
  ItemRef get ref => (kind: kind, id: id);
}

/// 目的（Purpose）。
@freezed
class Purpose({
  @override required final String id,
  @override required final String name,
  final String? description,
  final PurposeStatus status = PurposeStatus.unachieved,
  @override final DateTime? createdAt,
}) with _$Purpose implements Item {
  @override
  ItemKind get kind => ItemKind.purpose;

  @override
  String? get parentId => null;

  @override
  bool get isDone => status.isDone;
}

/// 目標（Goal）。
@freezed
class Goal({
  @override required final String id,
  required final String purposeId,
  @override required final String name,
  final String? description,
  required final CalendarDate dueDate,
  required final String achievementCriteria,
  final GoalStatus status = GoalStatus.unachieved,
  @override final DateTime? createdAt,
}) with _$Goal implements Item {
  @override
  ItemKind get kind => ItemKind.goal;

  @override
  String get parentId => purposeId;

  @override
  bool get isDone => status.isDone;
}

/// タスク（Task）。
@freezed
class Task({
  @override required final String id,
  required final String goalId,
  @override required final String name,
  final CalendarDate? scheduledDate,
  final bool important = false,
  final bool urgent = false,
  final TaskStatus status = TaskStatus.incomplete,
  @override final DateTime? createdAt,
}) with _$Task implements Item {
  @override
  ItemKind get kind => ItemKind.task;

  @override
  String get parentId => goalId;

  @override
  bool get isDone => status.isDone;
}
