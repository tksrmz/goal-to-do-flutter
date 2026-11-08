import 'package:goal_to_do/domain/calendar_date.dart';
import 'package:goal_to_do/domain/items.dart';

/// テスト用の項目を作る。作成日時は [createdOrder] の順（分単位）にする。

DateTime createdAt(int createdOrder) =>
    DateTime.utc(2026, 1, 1).add(Duration(minutes: createdOrder));

Purpose purpose(
  String id, {
  String? name,
  PurposeStatus status = PurposeStatus.unachieved,
  int? createdOrder,
  bool pending = false,
}) => Purpose(
  id: id,
  name: name ?? 'purpose $id',
  status: status,
  createdAt: pending ? null : createdAt(createdOrder ?? 0),
);

Goal goal(
  String id,
  String purposeId, {
  String? name,
  GoalStatus status = GoalStatus.unachieved,
  int? createdOrder,
  bool pending = false,
}) => Goal(
  id: id,
  purposeId: purposeId,
  name: name ?? 'goal $id',
  dueDate: CalendarDate(2027, 3, 31),
  achievementCriteria: 'criteria $id',
  status: status,
  createdAt: pending ? null : createdAt(createdOrder ?? 0),
);

Task task(
  String id,
  String goalId, {
  String? name,
  TaskStatus status = TaskStatus.incomplete,
  CalendarDate? scheduledDate,
  bool important = false,
  bool urgent = false,
  int? createdOrder,
  bool pending = false,
}) => Task(
  id: id,
  goalId: goalId,
  name: name ?? 'task $id',
  scheduledDate: scheduledDate,
  important: important,
  urgent: urgent,
  status: status,
  createdAt: pending ? null : createdAt(createdOrder ?? 0),
);

CalendarDate date(String iso) => CalendarDate.parse(iso);
