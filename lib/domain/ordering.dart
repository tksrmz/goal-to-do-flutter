import 'calendar_date.dart';
import 'items.dart';

/// 並び順（REQ-001 7.3）。

/// 期限切れ: 予定日が今日より前で、未完了のタスク（REQ-001 5章）。
bool isOverdue(Task task, CalendarDate today) =>
    !task.isDone &&
    task.scheduledDate != null &&
    task.scheduledDate!.isBefore(today);

/// 作成日時の古い順。同期待ち（`null`）は最も新しいものとして扱う（DES-001 3.4）。
/// 同じなら ID で決め、並び順が揺れないようにする。
int compareByCreatedAt(Item a, Item b) {
  final byCreatedAt = switch ((a.createdAt, b.createdAt)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final x?, final y?) => x.compareTo(y),
  };
  return byCreatedAt != 0 ? byCreatedAt : a.id.compareTo(b.id);
}

/// 目的・目標の並び順（作成日時の古い順）。
List<T> sortByCreatedAt<T extends Item>(Iterable<T> items) =>
    [...items]..sort(compareByCreatedAt);

/// 重要・緊急による区分。小さいほど先に並ぶ。
int _priorityClass(Task task) => switch ((task.important, task.urgent)) {
  (true, true) => 0,
  (true, false) => 1,
  (false, true) => 2,
  (false, false) => 3,
};

/// 目標ごとのタスク一覧の中での並び順。
///
/// 1. 未完了が先、済みが後（済みは「済みも表示」が ON のときなどに末尾にまとめる）
/// 2. 期限切れが先
/// 3. 重要かつ緊急 → 重要のみ → 緊急のみ → どちらでもない
/// 4. 予定日の古い順（予定日のないものは後）
/// 5. 作成日時の古い順
int compareTasks(Task a, Task b, CalendarDate today) {
  int byBool(bool x, bool y) => x == y ? 0 : (x ? -1 : 1);

  var result = byBool(!a.isDone, !b.isDone);
  if (result != 0) return result;

  result = byBool(isOverdue(a, today), isOverdue(b, today));
  if (result != 0) return result;

  result = _priorityClass(a).compareTo(_priorityClass(b));
  if (result != 0) return result;

  result = switch ((a.scheduledDate, b.scheduledDate)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final x?, final y?) => x.compareTo(y),
  };
  if (result != 0) return result;

  return compareByCreatedAt(a, b);
}

List<Task> sortTasks(Iterable<Task> tasks, CalendarDate today) =>
    [...tasks]..sort((a, b) => compareTasks(a, b, today));
