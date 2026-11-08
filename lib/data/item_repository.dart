import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/item_tree.dart';
import '../domain/items.dart';
import '../domain/mutation.dart';
import 'firestore_codec.dart';

/// ログイン中のユーザーの目的・目標・タスクを読み書きする。
abstract interface class ItemRepository {
  /// 3つのコレクションの全体を購読し、ツリーにして流す（DES-001 4.1）。
  /// 3つすべての最初の結果が揃ってから流し始める。
  Stream<ItemTree> watchTree();

  /// 新しい項目の ID。オフラインでも採番できる（DES-001 3.1）。
  String newId(ItemKind kind);

  /// [mutation] を1つのバッチでコミットする（6.3.7）。
  ///
  /// ローカルのキャッシュとリスナーには即座に反映される。返り値の Future はサーバーに届いたときに
  /// 完了するので、オフラインの間は完了しない。画面はこれを待たずに進める。
  Future<void> commit(Mutation mutation);
}

/// Cloud Firestore の `users/{uid}/{purposes,goals,tasks}` を使う実装。
final class FirestoreItemRepository implements ItemRepository {
  FirestoreItemRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> _collection(ItemKind kind) =>
      _db.collection('users').doc(_uid).collection(collectionName(kind));

  DocumentReference<Map<String, dynamic>> _doc(ItemRef ref) =>
      _collection(ref.kind).doc(ref.id);

  Stream<List<T>> _watch<T extends Item>(ItemKind kind) =>
      _collection(kind).snapshots().map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            if (_decode(kind, doc) case final T item) item,
        ],
      );

  /// 形の正しくないドキュメントは、画面全体を止めないように読み飛ばす。
  /// セキュリティルールで形を検証しているので、通常は起きない。
  Item? _decode(
    ItemKind kind,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    try {
      return itemFromFirestore(kind, doc.id, doc.data());
    } on FormatException catch (e) {
      debugPrint('Skipped malformed ${kind.name} ${doc.id}: $e');
      return null;
    }
  }

  @override
  Stream<ItemTree> watchTree() => combineLatestTree(
    _watch<Purpose>(ItemKind.purpose),
    _watch<Goal>(ItemKind.goal),
    _watch<Task>(ItemKind.task),
  );

  @override
  String newId(ItemKind kind) => _collection(kind).doc().id;

  @override
  Future<void> commit(Mutation mutation) {
    final batch = _db.batch();
    for (final write in mutation.writes) {
      switch (write) {
        case CreateItem(:final item):
          batch.set(_doc(item.ref), createData(item));
        case UpdateItem(:final before, :final after):
          final data = updateData(before, after);
          if (data.isNotEmpty) batch.update(_doc(after.ref), data);
        case DeleteItem(:final ref):
          batch.delete(_doc(ref));
      }
    }
    return batch.commit();
  }
}

/// 3つの一覧の最新の値を組み合わせてツリーにする。すべてが一度は値を流してから流し始める。
@visibleForTesting
Stream<ItemTree> combineLatestTree(
  Stream<List<Purpose>> purposes,
  Stream<List<Goal>> goals,
  Stream<List<Task>> tasks,
) {
  late final StreamController<ItemTree> controller;
  final subscriptions = <StreamSubscription<Object?>>[];
  List<Purpose>? latestPurposes;
  List<Goal>? latestGoals;
  List<Task>? latestTasks;

  void emit() {
    if (latestPurposes case final p?) {
      if (latestGoals case final g?) {
        if (latestTasks case final t?) {
          controller.add(ItemTree(purposes: p, goals: g, tasks: t));
        }
      }
    }
  }

  controller = StreamController<ItemTree>(
    onListen: () {
      subscriptions
        ..add(
          purposes.listen((v) {
            latestPurposes = v;
            emit();
          }, onError: controller.addError),
        )
        ..add(
          goals.listen((v) {
            latestGoals = v;
            emit();
          }, onError: controller.addError),
        )
        ..add(
          tasks.listen((v) {
            latestTasks = v;
            emit();
          }, onError: controller.addError),
        );
    },
    onPause: () {
      for (final s in subscriptions) {
        s.pause();
      }
    },
    onResume: () {
      for (final s in subscriptions) {
        s.resume();
      }
    },
    onCancel: () async {
      await Future.wait([for (final s in subscriptions) s.cancel()]);
    },
  );
  return controller.stream;
}
