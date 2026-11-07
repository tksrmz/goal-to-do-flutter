import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/domain/ordering.dart';
import 'package:goal_to_do/domain/items.dart';

import '../helpers/fixtures.dart';

void main() {
  final today = date('2026-11-06');
  List<String> ids(Iterable<Item> items) => [for (final i in items) i.id];

  group('isOverdue', () {
    test('予定日が今日より前の未完了タスクだけが期限切れ', () {
      expect(
        isOverdue(task('a', 'g', scheduledDate: date('2026-11-05')), today),
        isTrue,
      );
      expect(isOverdue(task('b', 'g', scheduledDate: today), today), isFalse);
      expect(isOverdue(task('c', 'g'), today), isFalse);
      expect(
        isOverdue(
          task(
            'd',
            'g',
            scheduledDate: date('2026-11-05'),
            status: TaskStatus.complete,
          ),
          today,
        ),
        isFalse,
      );
    });
  });

  group('sortTasks', () {
    test('AC-055: 期限切れ → 重要かつ緊急 → 重要のみ → 緊急のみ → どちらでもない', () {
      final tasks = [
        task('T1', 'g', scheduledDate: today),
        task('T2', 'g', scheduledDate: today, urgent: true),
        task('T3', 'g', scheduledDate: today, important: true),
        task('T4', 'g', scheduledDate: today, important: true, urgent: true),
        task('T5', 'g', scheduledDate: date('2026-11-04')),
        task(
          'T6',
          'g',
          scheduledDate: date('2026-11-05'),
          important: true,
          urgent: true,
        ),
      ];
      expect(ids(sortTasks(tasks, today)), [
        'T6',
        'T5',
        'T4',
        'T3',
        'T2',
        'T1',
      ]);
    });

    test('AC-056: 同じ区分では予定日の古い順（予定日なしは後）、次に作成日時の古い順', () {
      final tasks = [
        task(
          'U1',
          'g',
          important: true,
          scheduledDate: date('2026-11-20'),
          createdOrder: 1,
        ),
        task('U2', 'g', important: true, createdOrder: 2),
        task(
          'U3',
          'g',
          important: true,
          scheduledDate: date('2026-11-10'),
          createdOrder: 3,
        ),
        task(
          'U4',
          'g',
          important: true,
          scheduledDate: date('2026-11-10'),
          createdOrder: 4,
        ),
      ];
      expect(ids(sortTasks(tasks, today)), ['U3', 'U4', 'U1', 'U2']);
    });

    test('期限切れ同士は、区分・予定日・作成日時の順', () {
      final tasks = [
        task('a', 'g', scheduledDate: date('2026-11-01')),
        task('b', 'g', scheduledDate: date('2026-11-03'), important: true),
        task('c', 'g', scheduledDate: date('2026-11-02'), important: true),
      ];
      expect(ids(sortTasks(tasks, today)), ['c', 'b', 'a']);
    });

    test('AC-057: 済みのタスクは末尾にまとめ、その中も同じ順で並ぶ', () {
      final tasks = [
        task('done1', 'g', status: TaskStatus.complete),
        task(
          'done2',
          'g',
          status: TaskStatus.completeByParent,
          important: true,
        ),
        task('open1', 'g'),
        task('open2', 'g', urgent: true),
      ];
      expect(ids(sortTasks(tasks, today)), [
        'open2',
        'open1',
        'done2',
        'done1',
      ]);
    });

    test('同期待ち（作成日時が null）は最も新しいものとして扱う', () {
      final tasks = [
        task('pending', 'g', pending: true),
        task('new', 'g', createdOrder: 2),
        task('old', 'g', createdOrder: 1),
      ];
      expect(ids(sortTasks(tasks, today)), ['old', 'new', 'pending']);
    });
  });

  group('sortByCreatedAt', () {
    test('AC-058: 作成日時の古い順。同期待ちは末尾', () {
      final purposes = [
        purpose('C', pending: true),
        purpose('B', createdOrder: 2),
        purpose('A', createdOrder: 1),
      ];
      expect(ids(sortByCreatedAt(purposes)), ['A', 'B', 'C']);
    });
  });
}
