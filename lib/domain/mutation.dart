import 'items.dart';

/// 1件のドキュメントへの書き込み。
sealed class ItemWrite {
  ItemRef get ref;
}

/// 項目の作成。ID は呼び出し側で採番済み（オフラインでも作れるよう、クライアントで決める）。
final class CreateItem(final Item item) implements ItemWrite {
  @override
  ItemRef get ref => item.ref;
}

/// 項目の更新。[before] と [after] の差分のフィールドだけを書き込む（DES-001 4.2）。
final class UpdateItem(final Item before, final Item after)
    implements ItemWrite {
  this : assert(before.kind == after.kind && before.id == after.id);

  @override
  ItemRef get ref => after.ref;
}

/// 項目の削除。
final class DeleteItem(@override final ItemRef ref) implements ItemWrite;

/// 一括で反映する書き込みの集まり。データ層で1つの `WriteBatch` にしてコミットする（6.3.7）。
final class Mutation {
  Mutation(Iterable<ItemWrite> writes) : writes = List.unmodifiable(writes);

  final List<ItemWrite> writes;

  bool get isEmpty => writes.isEmpty;

  /// この書き込みで未済みから済みになる項目。画面を開き直すまで表示に残すのに使う（REQ-001 7.1、7.2）。
  Set<ItemRef> get newlyDone => {
    for (final write in writes)
      if (write case UpdateItem(:final before, :final after)
          when !before.isDone && after.isDone)
        write.ref,
  };
}
