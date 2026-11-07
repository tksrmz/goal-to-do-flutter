import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/calendar_date.dart';
import '../domain/items.dart';

/// Firestore のドキュメントとモデルの変換（DES-001 3.3、6.2）。json_serializable は使わず手書きする。
///
/// - ID はドキュメント ID だけで持ち、フィールドには入れない
/// - 値のない任意項目は、フィールドを省かず `null` を入れる
/// - `createdAt` は作成時に `FieldValue.serverTimestamp()` を入れ、更新では送らない

// ---- コレクション ----

String collectionName(ItemKind kind) => switch (kind) {
  ItemKind.purpose => 'purposes',
  ItemKind.goal => 'goals',
  ItemKind.task => 'tasks',
};

// ---- 状態の値 ----

String purposeStatusValue(PurposeStatus status) => switch (status) {
  PurposeStatus.unachieved => 'unachieved',
  PurposeStatus.achieved => 'achieved',
};

String goalStatusValue(GoalStatus status) => switch (status) {
  GoalStatus.unachieved => 'unachieved',
  GoalStatus.achieved => 'achieved',
  GoalStatus.achievedByParent => 'achieved_by_parent',
};

String taskStatusValue(TaskStatus status) => switch (status) {
  TaskStatus.incomplete => 'incomplete',
  TaskStatus.complete => 'complete',
  TaskStatus.completeByParent => 'complete_by_parent',
};

T _parseEnum<T>(List<T> values, String Function(T) toValue, Object? value) {
  for (final v in values) {
    if (toValue(v) == value) return v;
  }
  throw FormatException('Unknown status', value);
}

// ---- 読み取り ----

/// ドキュメントを読む。形が正しくなければ [FormatException]。
Item itemFromFirestore(ItemKind kind, String id, Map<String, Object?> data) =>
    switch (kind) {
      ItemKind.purpose => purposeFromFirestore(id, data),
      ItemKind.goal => goalFromFirestore(id, data),
      ItemKind.task => taskFromFirestore(id, data),
    };

Purpose purposeFromFirestore(String id, Map<String, Object?> data) => Purpose(
  id: id,
  name: _string(data, 'name'),
  description: _optString(data, 'description'),
  status: _parseEnum(PurposeStatus.values, purposeStatusValue, data['status']),
  createdAt: _createdAt(data),
);

Goal goalFromFirestore(String id, Map<String, Object?> data) => Goal(
  id: id,
  purposeId: _string(data, 'purposeId'),
  name: _string(data, 'name'),
  description: _optString(data, 'description'),
  dueDate: CalendarDate.parse(_string(data, 'dueDate')),
  achievementCriteria: _string(data, 'achievementCriteria'),
  status: _parseEnum(GoalStatus.values, goalStatusValue, data['status']),
  createdAt: _createdAt(data),
);

Task taskFromFirestore(String id, Map<String, Object?> data) => Task(
  id: id,
  goalId: _string(data, 'goalId'),
  name: _string(data, 'name'),
  scheduledDate: switch (_optString(data, 'scheduledDate')) {
    final value? => CalendarDate.parse(value),
    null => null,
  },
  important: _bool(data, 'important'),
  urgent: _bool(data, 'urgent'),
  status: _parseEnum(TaskStatus.values, taskStatusValue, data['status']),
  createdAt: _createdAt(data),
);

String _string(Map<String, Object?> data, String field) =>
    switch (data[field]) {
      final String value => value,
      final value => throw FormatException('"$field" must be a string', value),
    };

String? _optString(Map<String, Object?> data, String field) =>
    switch (data[field]) {
      null => null,
      final String value => value,
      final value => throw FormatException(
        '"$field" must be a string or null',
        value,
      ),
    };

bool _bool(Map<String, Object?> data, String field) => switch (data[field]) {
  final bool value => value,
  final value => throw FormatException('"$field" must be a bool', value),
};

/// 同期待ちの間は `null` で返ってくる（DES-001 3.4）。
DateTime? _createdAt(Map<String, Object?> data) => switch (data['createdAt']) {
  null => null,
  final Timestamp value => value.toDate(),
  final value => throw FormatException(
    '"createdAt" must be a timestamp',
    value,
  ),
};

// ---- 書き込み ----

/// 作成時に書き込む全フィールド。`createdAt` はサーバー時刻。
Map<String, Object?> createData(Item item) => {
  ..._fields(item),
  'createdAt': FieldValue.serverTimestamp(),
};

/// 更新時に書き込むフィールド。[before] から変わったものだけを返し、`createdAt` は含めない。
Map<String, Object?> updateData(Item before, Item after) {
  if (before.kind != after.kind || before.id != after.id) {
    throw ArgumentError('before and after must be the same item');
  }
  final old = _fields(before);
  return {
    for (final MapEntry(:key, :value) in _fields(after).entries)
      if (old[key] != value) key: value,
  };
}

/// `createdAt` 以外のフィールド。
Map<String, Object?> _fields(Item item) => switch (item) {
  Purpose() => {
    'name': item.name,
    'description': item.description,
    'status': purposeStatusValue(item.status),
  },
  Goal() => {
    'purposeId': item.purposeId,
    'name': item.name,
    'description': item.description,
    'dueDate': item.dueDate.toIso8601(),
    'achievementCriteria': item.achievementCriteria,
    'status': goalStatusValue(item.status),
  },
  Task() => {
    'goalId': item.goalId,
    'name': item.name,
    'scheduledDate': item.scheduledDate?.toIso8601(),
    'important': item.important,
    'urgent': item.urgent,
    'status': taskStatusValue(item.status),
  },
};
