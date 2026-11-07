import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/data/firestore_codec.dart';
import 'package:goal_to_do/domain/calendar_date.dart';
import 'package:goal_to_do/domain/items.dart';

void main() {
  final created = DateTime.utc(2026, 11, 6, 1, 2, 3);
  final timestamp = Timestamp.fromDate(created);

  group('読み取り', () {
    test('目的', () {
      final purpose = purposeFromFirestore('p1', {
        'name': '転職するために',
        'description': null,
        'status': 'achieved',
        'createdAt': timestamp,
      });
      expect(
        purpose,
        Purpose(
          id: 'p1',
          name: '転職するために',
          status: PurposeStatus.achieved,
          createdAt: created.toLocal(),
        ),
      );
    });

    test('目標', () {
      final goal = goalFromFirestore('g1', {
        'purposeId': 'p1',
        'name': '内定',
        'description': '説明',
        'dueDate': '2027-03-31',
        'achievementCriteria': '1社',
        'status': 'achieved_by_parent',
        'createdAt': timestamp,
      });
      expect(goal.purposeId, 'p1');
      expect(goal.description, '説明');
      expect(goal.dueDate, CalendarDate(2027, 3, 31));
      expect(goal.achievementCriteria, '1社');
      expect(goal.status, GoalStatus.achievedByParent);
    });

    test('タスク', () {
      final task = taskFromFirestore('t1', {
        'goalId': 'g1',
        'name': '職務経歴書を直す',
        'scheduledDate': '2026-11-06',
        'important': true,
        'urgent': false,
        'status': 'complete_by_parent',
        'createdAt': timestamp,
      });
      expect(task.goalId, 'g1');
      expect(task.scheduledDate, CalendarDate(2026, 11, 6));
      expect((task.important, task.urgent), (true, false));
      expect(task.status, TaskStatus.completeByParent);
    });

    test('同期待ちの createdAt（null）と、予定日なしを読める', () {
      final task = taskFromFirestore('t1', {
        'goalId': 'g1',
        'name': 'x',
        'scheduledDate': null,
        'important': false,
        'urgent': false,
        'status': 'incomplete',
        'createdAt': null,
      });
      expect(task.createdAt, isNull);
      expect(task.scheduledDate, isNull);
    });

    test('形が正しくなければ FormatException', () {
      final valid = <String, Object?>{
        'name': 'x',
        'description': null,
        'status': 'unachieved',
        'createdAt': timestamp,
      };
      expect(
        () => purposeFromFirestore('p', {...valid, 'name': 1}),
        throwsFormatException,
      );
      expect(
        () => purposeFromFirestore('p', {...valid, 'status': 'complete'}),
        throwsFormatException,
      );
      expect(
        () => purposeFromFirestore('p', {...valid, 'createdAt': 'now'}),
        throwsFormatException,
      );
      expect(
        () => purposeFromFirestore('p', {...valid}..remove('name')),
        throwsFormatException,
      );
    });
  });

  group('作成', () {
    test('すべてのフィールドを書き、作成日時はサーバー時刻にする', () {
      final data = createData(
        Task(id: 't1', goalId: 'g1', name: 'x', createdAt: created),
      );
      expect(data, {
        'goalId': 'g1',
        'name': 'x',
        'scheduledDate': null,
        'important': false,
        'urgent': false,
        'status': 'incomplete',
        'createdAt': FieldValue.serverTimestamp(),
      });
      expect(data.containsKey('id'), isFalse);
    });

    test('目的・目標のフィールド名', () {
      expect(
        createData(Purpose(id: 'p', name: 'n')).keys,
        unorderedEquals(['name', 'description', 'status', 'createdAt']),
      );
      expect(
        createData(
          Goal(
            id: 'g',
            purposeId: 'p',
            name: 'n',
            dueDate: CalendarDate(2027, 3, 31),
            achievementCriteria: 'c',
          ),
        ),
        {
          'purposeId': 'p',
          'name': 'n',
          'description': null,
          'dueDate': '2027-03-31',
          'achievementCriteria': 'c',
          'status': 'unachieved',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });

    test('読み取りと往復できる', () {
      final goal = Goal(
        id: 'g',
        purposeId: 'p',
        name: 'n',
        description: 'd',
        dueDate: CalendarDate(2027, 3, 31),
        achievementCriteria: 'c',
        status: GoalStatus.achieved,
      );
      final data = {...createData(goal), 'createdAt': null};
      expect(goalFromFirestore('g', data), goal);
    });
  });

  group('更新', () {
    final before = Task(
      id: 't1',
      goalId: 'g1',
      name: 'x',
      scheduledDate: CalendarDate(2026, 11, 6),
    );

    test('変わったフィールドだけを書き、作成日時は送らない', () {
      final after = before.copyWith(
        status: TaskStatus.complete,
        scheduledDate: null,
        createdAt: created,
      );
      expect(updateData(before, after), {
        'scheduledDate': null,
        'status': 'complete',
      });
    });

    test('別の項目どうしは比べられない', () {
      expect(
        () => updateData(before, before.copyWith(id: 'other')),
        throwsArgumentError,
      );
    });
  });
}
