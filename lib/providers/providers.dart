import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/auth_repository.dart';
import '../data/item_repository.dart';
import '../domain/calendar_date.dart';
import '../domain/item_tree.dart';
import '../domain/items.dart';
import '../domain/mutation.dart';

part 'providers.g.dart';

// ---- Firebase ----

@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

// ---- 認証（DES-001 6.3） ----

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(ref.watch(firebaseAuthProvider));

/// ログイン中のユーザーの UID。未ログインなら `null`。
@Riverpod(keepAlive: true)
Stream<String?> userId(Ref ref) =>
    ref.watch(authRepositoryProvider).userIdChanges();

// ---- 目的・目標・タスク（DES-001 4.1） ----

/// ログイン中のユーザーのデータの読み書き。未ログインなら `null`。
@Riverpod(keepAlive: true)
ItemRepository? itemRepository(Ref ref) {
  final uid = ref.watch(userIdProvider).value;
  if (uid == null) return null;
  return FirestoreItemRepository(ref.watch(firestoreProvider), uid);
}

/// ログイン中は3つのコレクションを購読し続ける。オフラインでの一括操作に、配下の項目が
/// ローカルキャッシュにある必要があるため、画面を離れても破棄しない。ログアウトで破棄される。
@Riverpod(keepAlive: true)
Stream<ItemTree> itemTree(Ref ref) {
  final repository = ref.watch(itemRepositoryProvider);
  if (repository == null) return Stream.value(ItemTree.empty);
  return repository.watchTree();
}

/// 書き込み。[ItemWriter.commit] はサーバーへの到達を待たない（オフラインでは完了しないため）。
@Riverpod(keepAlive: true)
ItemWriter? itemWriter(Ref ref) {
  final repository = ref.watch(itemRepositoryProvider);
  if (repository == null) return null;
  return ItemWriter(
    repository,
    (error) => ref.read(writeErrorsProvider.notifier).report(error),
  );
}

final class ItemWriter(
  final ItemRepository _repository,
  final void Function(Object error) _onError,
) {
  String newId(ItemKind kind) => _repository.newId(kind);

  void commit(Mutation mutation) {
    if (mutation.isEmpty) return;
    unawaited(_repository.commit(mutation).catchError(_onError));
  }
}

/// 書き込みの失敗（ルールでの拒否など）。失敗したバッチは、ローカルの反映も取り消される。
@Riverpod(keepAlive: true)
class WriteErrors extends _$WriteErrors {
  @override
  ({int count, Object? error}) build() => (count: 0, error: null);

  void report(Object error) => state = (count: state.count + 1, error: error);
}

// ---- 今日（NFR-006） ----

/// 現在時刻。テストで差し替える。
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

/// 端末のタイムゾーンでの今日。開いたまま日付が変わったら、新しい日付になる（AC-015）。
@riverpod
class Today extends _$Today {
  @override
  CalendarDate build() {
    final now = ref.watch(clockProvider);
    final timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final current = CalendarDate.fromDateTime(now());
      if (current != state) state = current;
    });
    ref.onDispose(timer.cancel);
    return CalendarDate.fromDateTime(now());
  }
}
