// Firestore のセキュリティルール（../firestore.rules）のテスト。
// Emulator 上で実行する: npm test（rules_test/README.md を参照）

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-goal-to-do';

/** @type {import('@firebase/rules-unit-testing').RulesTestEnvironment} */
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const alice = () => testEnv.authenticatedContext('alice').firestore();
const bob = () => testEnv.authenticatedContext('bob').firestore();
const anonymous = () => testEnv.unauthenticatedContext().firestore();

const purpose = (overrides = {}) => ({
  name: '転職するために',
  description: null,
  status: 'unachieved',
  createdAt: serverTimestamp(),
  ...overrides,
});

const goal = (overrides = {}) => ({
  purposeId: 'p1',
  name: '3月までに内定を1社得る',
  description: null,
  dueDate: '2027-03-31',
  achievementCriteria: '内定通知を1社から受け取る',
  status: 'unachieved',
  createdAt: serverTimestamp(),
  ...overrides,
});

const task = (overrides = {}) => ({
  goalId: 'g1',
  name: '職務経歴書を直す',
  scheduledDate: '2026-11-06',
  important: true,
  urgent: false,
  status: 'incomplete',
  createdAt: serverTimestamp(),
  ...overrides,
});

/** ルールを無効にした状態で、alice のデータを用意する */
async function seed(docs) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await setDoc(doc(db, path), data);
    }
  });
}

describe('本人のデータだけを読み書きできる（NFR-004, AC-059）', () => {
  beforeEach(async () => {
    await seed({ 'users/alice/purposes/p1': purpose() });
  });

  test('本人は読める', async () => {
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/purposes/p1')));
    await assertSucceeds(getDocs(collection(alice(), 'users/alice/purposes')));
  });

  test('未ログインでは読めない', async () => {
    await assertFails(getDoc(doc(anonymous(), 'users/alice/purposes/p1')));
  });

  test('他のユーザーは読めない', async () => {
    await assertFails(getDoc(doc(bob(), 'users/alice/purposes/p1')));
    await assertFails(getDocs(collection(bob(), 'users/alice/purposes')));
  });

  test('他のユーザーは作成・更新・削除できない', async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice/purposes/p2'), purpose()));
    await assertFails(updateDoc(doc(bob(), 'users/alice/purposes/p1'), { name: '乗っ取り' }));
    await assertFails(deleteDoc(doc(bob(), 'users/alice/purposes/p1')));
  });

  test('ユーザーのドキュメント本体や、定義していないコレクションには書けない', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), { foo: 1 }));
    await assertFails(setDoc(doc(alice(), 'users/alice/others/x'), { foo: 1 }));
  });
});

describe('purposes', () => {
  const path = 'users/alice/purposes/p1';

  test('正しい形なら作成できる', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), purpose()));
    await assertSucceeds(
      setDoc(doc(alice(), 'users/alice/purposes/p2'), purpose({ description: '説明' })),
    );
  });

  test('フィールドの過不足があると作成できない', async () => {
    const { description: _, ...missing } = purpose();
    await assertFails(setDoc(doc(alice(), path), missing));
    await assertFails(setDoc(doc(alice(), path), purpose({ extra: 1 })));
  });

  // ルールの trim() は全角空白（U+3000）を取り除かないので、全角空白のみの名前はアプリ側で防ぐ
  test('名前が空・空白のみ・長すぎると作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), purpose({ name: '' })));
    await assertFails(setDoc(doc(alice(), path), purpose({ name: ' \t\n ' })));
    await assertFails(setDoc(doc(alice(), path), purpose({ name: 'あ'.repeat(401) })));
    await assertSucceeds(setDoc(doc(alice(), path), purpose({ name: 'あ'.repeat(400) })));
  });

  test('説明文が長すぎると作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), purpose({ description: 'あ'.repeat(8001) })));
    await assertFails(setDoc(doc(alice(), path), purpose({ description: 1 })));
  });

  test('目的にない状態は保存できない', async () => {
    await assertFails(setDoc(doc(alice(), path), purpose({ status: 'achieved_by_parent' })));
    await assertSucceeds(setDoc(doc(alice(), path), purpose({ status: 'achieved' })));
  });

  test('作成日時はサーバー時刻でなければならない', async () => {
    await assertFails(setDoc(doc(alice(), path), purpose({ createdAt: Timestamp.now() })));
    await assertFails(setDoc(doc(alice(), path), purpose({ createdAt: null })));
  });

  test('更新では作成日時を変えられない', async () => {
    await seed({ [path]: purpose() });
    await assertSucceeds(updateDoc(doc(alice(), path), { name: '新しい名前', status: 'achieved' }));
    await assertFails(updateDoc(doc(alice(), path), { createdAt: Timestamp.now() }));
    await assertFails(updateDoc(doc(alice(), path), { createdAt: serverTimestamp() }));
  });

  test('本人は削除できる', async () => {
    await seed({ [path]: purpose() });
    await assertSucceeds(deleteDoc(doc(alice(), path)));
  });
});

describe('goals', () => {
  const path = 'users/alice/goals/g1';

  beforeEach(async () => {
    await seed({
      'users/alice/purposes/p1': purpose(),
      'users/alice/purposes/done': purpose({ status: 'achieved' }),
    });
  });

  test('未達成の目的の下に作成できる', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), goal()));
  });

  test('達成済みの目的や、存在しない目的の下には作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), goal({ purposeId: 'done' })));
    await assertFails(setDoc(doc(alice(), path), goal({ purposeId: 'missing' })));
  });

  test('他のユーザーの目的は親にできない', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users/bob/purposes/bp'), purpose());
    });
    await assertFails(setDoc(doc(alice(), path), goal({ purposeId: 'bp' })));
  });

  test('同じバッチで作った目的の下に作成できる', async () => {
    const db = alice();
    const batch = writeBatch(db);
    batch.set(doc(db, 'users/alice/purposes/p2'), purpose());
    batch.set(doc(db, path), goal({ purposeId: 'p2' }));
    await assertSucceeds(batch.commit());
  });

  test('期日・達成基準が正しくないと作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), goal({ dueDate: null })));
    await assertFails(setDoc(doc(alice(), path), goal({ dueDate: '2027/03/31' })));
    await assertFails(setDoc(doc(alice(), path), goal({ achievementCriteria: ' ' })));
    await assertFails(setDoc(doc(alice(), path), goal({ achievementCriteria: null })));
    await assertFails(
      setDoc(doc(alice(), path), goal({ achievementCriteria: 'あ'.repeat(8001) })),
    );
  });

  test('目標にない状態は保存できない', async () => {
    await assertFails(setDoc(doc(alice(), path), goal({ status: 'complete' })));
  });

  test('付け替え先は未達成の目的でなければならない', async () => {
    await seed({
      'users/alice/purposes/p2': purpose(),
      [path]: goal(),
    });
    await assertSucceeds(updateDoc(doc(alice(), path), { purposeId: 'p2' }));
    await assertFails(updateDoc(doc(alice(), path), { purposeId: 'done' }));
    await assertFails(updateDoc(doc(alice(), path), { purposeId: 'missing' }));
  });

  test('親を変えない更新では、親を確認しない（目的の達成と同時の更新）', async () => {
    await seed({ [path]: goal() });
    const db = alice();
    const batch = writeBatch(db);
    batch.update(doc(db, 'users/alice/purposes/p1'), { status: 'achieved' });
    batch.update(doc(db, path), { status: 'achieved_by_parent' });
    await assertSucceeds(batch.commit());
  });
});

describe('tasks', () => {
  const path = 'users/alice/tasks/t1';

  beforeEach(async () => {
    await seed({
      'users/alice/purposes/p1': purpose(),
      'users/alice/goals/g1': goal(),
      'users/alice/goals/done': goal({ status: 'achieved' }),
    });
  });

  test('未達成の目標の下に作成できる', async () => {
    await assertSucceeds(setDoc(doc(alice(), path), task()));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/tasks/t2'), task({ scheduledDate: null })));
  });

  test('達成済みの目標や、存在しない目標の下には作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), task({ goalId: 'done' })));
    await assertFails(setDoc(doc(alice(), path), task({ goalId: 'missing' })));
  });

  test('予定日・重要・緊急の型が正しくないと作成できない', async () => {
    await assertFails(setDoc(doc(alice(), path), task({ scheduledDate: '11/06' })));
    await assertFails(setDoc(doc(alice(), path), task({ important: 'yes' })));
    await assertFails(setDoc(doc(alice(), path), task({ urgent: null })));
  });

  test('タスクにない状態は保存できない', async () => {
    await assertFails(setDoc(doc(alice(), path), task({ status: 'achieved' })));
  });

  test('完了の切り替えと、予定日の解除ができる', async () => {
    await seed({ [path]: task() });
    await assertSucceeds(updateDoc(doc(alice(), path), { status: 'complete' }));
    await assertSucceeds(updateDoc(doc(alice(), path), { scheduledDate: null }));
  });

  test('付け替え先は未達成の目標でなければならない', async () => {
    await seed({
      'users/alice/goals/g2': goal(),
      [path]: task(),
    });
    await assertSucceeds(updateDoc(doc(alice(), path), { goalId: 'g2' }));
    await assertFails(updateDoc(doc(alice(), path), { goalId: 'done' }));
  });
});

describe('複数項目の一括操作（6.3.2〜6.3.4）', () => {
  beforeEach(async () => {
    await seed({
      'users/alice/purposes/p1': purpose(),
      'users/alice/goals/g1': goal({ status: 'achieved' }),
      'users/alice/goals/g2': goal(),
      'users/alice/tasks/t1': task({ goalId: 'g2', status: 'complete' }),
      'users/alice/tasks/t2': task({ goalId: 'g2' }),
    });
  });

  test('目的を配下ごと削除できる', async () => {
    const db = alice();
    const batch = writeBatch(db);
    for (const path of [
      'users/alice/purposes/p1',
      'users/alice/goals/g1',
      'users/alice/goals/g2',
      'users/alice/tasks/t1',
      'users/alice/tasks/t2',
    ]) {
      batch.delete(doc(db, path));
    }
    await assertSucceeds(batch.commit());
  });

  test('目的の達成と、その取り消しを配下に反映できる', async () => {
    const db = alice();
    const achieve = writeBatch(db);
    achieve.update(doc(db, 'users/alice/purposes/p1'), { status: 'achieved' });
    achieve.update(doc(db, 'users/alice/goals/g2'), { status: 'achieved_by_parent' });
    achieve.update(doc(db, 'users/alice/tasks/t2'), { status: 'complete_by_parent' });
    await assertSucceeds(achieve.commit());

    const revert = writeBatch(db);
    revert.update(doc(db, 'users/alice/purposes/p1'), { status: 'unachieved' });
    revert.update(doc(db, 'users/alice/goals/g2'), { status: 'unachieved' });
    revert.update(doc(db, 'users/alice/tasks/t2'), { status: 'incomplete' });
    await assertSucceeds(revert.commit());
  });

  test('バッチの一部が拒否されると、全体が反映されない（AC-044）', async () => {
    const db = alice();
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users/alice/tasks/t1'));
    batch.update(doc(db, 'users/alice/goals/g2'), { status: 'invalid' });
    await assertFails(batch.commit());

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const snapshot = await getDoc(doc(context.firestore(), 'users/alice/tasks/t1'));
      if (!snapshot.exists()) {
        throw new Error('t1 は削除されていないはず');
      }
    });
  });
});
