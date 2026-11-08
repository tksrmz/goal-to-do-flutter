import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goal_to_do/app.dart';
import 'package:goal_to_do/data/auth_repository.dart';
import 'package:goal_to_do/data/item_repository.dart';
import 'package:goal_to_do/domain/item_tree.dart';
import 'package:goal_to_do/domain/items.dart';
import 'package:goal_to_do/domain/mutation.dart';
import 'package:goal_to_do/providers/providers.dart';

/// メモリ上の認証。`me@example.com` / `password` でログインできる。
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? signedInAs}) : _current = signedInAs;

  static const email = 'me@example.com';
  static const password = 'password';

  String? _current;
  final _changes = StreamController<String?>.broadcast();

  @override
  Stream<String?> userIdChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (email != FakeAuthRepository.email ||
        password != FakeAuthRepository.password) {
      throw SignInException(SignInFailure.invalidCredential);
    }
    _changes.add(_current = 'uid');
  }

  @override
  Future<void> signOut() async => _changes.add(_current = null);
}

/// メモリ上のデータ。コミットはすぐにツリーへ反映する（Firestore のローカルへの反映と同じ）。
class FakeItemRepository implements ItemRepository {
  FakeItemRepository([ItemTree? tree]) : tree = tree ?? ItemTree.empty;

  ItemTree tree;
  final commits = <Mutation>[];
  final _changes = StreamController<ItemTree>.broadcast();
  var _nextId = 0;
  var _clock = DateTime.utc(2026, 6, 1);

  @override
  Stream<ItemTree> watchTree() async* {
    yield tree;
    yield* _changes.stream;
  }

  @override
  String newId(ItemKind kind) => 'new${_nextId++}';

  @override
  Future<void> commit(Mutation mutation) {
    commits.add(mutation);
    // 作成日時はサーバー時刻の代わりに、単調に増える時刻を入れる
    tree = tree.apply(
      Mutation([
        for (final write in mutation.writes)
          if (write case CreateItem(:final item))
            CreateItem(_stamp(item))
          else
            write,
      ]),
    );
    _changes.add(tree);
    return Future.value();
  }

  /// サーバーとの同期などで、アプリの書き込みによらず項目が変わったことを再現する。
  void receive(Item item) {
    tree = tree.apply(
      Mutation([
        if (tree.find(item.ref) case final before?)
          UpdateItem(before, item)
        else
          CreateItem(item),
      ]),
    );
    _changes.add(tree);
  }

  Item _stamp(Item item) {
    _clock = _clock.add(const Duration(minutes: 1));
    return switch (item) {
      Purpose() => item.copyWith(createdAt: _clock),
      Goal() => item.copyWith(createdAt: _clock),
      Task() => item.copyWith(createdAt: _clock),
    };
  }
}

/// テスト用の時計。[now] を書き換えると現在時刻が変わる。
class FakeClock {
  FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// アプリ全体を、フェイクの認証・データ・時計で起動する。
Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeItemRepository? items,
  FakeClock? clock,
}) async {
  final repository = items ?? FakeItemRepository();
  final fakeClock = clock ?? FakeClock(DateTime(2026, 11, 6, 8));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        itemRepositoryProvider.overrideWith(
          (ref) => ref.watch(userIdProvider).value == null ? null : repository,
        ),
        clockProvider.overrideWithValue(fakeClock.call),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}
