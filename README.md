# Goal to Do (Flutter)

目的・目標・タスクを紐付けて管理する Web アプリ。要件は [docs/spec/REQ-001.md](docs/spec/REQ-001.md) を参照。

## 開発環境

Flutter・Firebase CLI・Java（Firestore Emulator 用）・Node（セキュリティルールのテスト用）のバージョンは [mise](https://mise.jdx.dev/) で管理し、[mise.toml](mise.toml) で固定している。

```sh
mise trust     # 初回のみ
mise install
flutter --version
firebase --version
```

FlutterFire CLI は mise で管理できないため、Dart のグローバルパッケージとして入れる。

```sh
dart pub global activate flutterfire_cli
```

## Firebase

開発用（`goal-to-do-dev`）と本番用（未作成）のプロジェクトの構成・現状・今後の手順は [docs/environments.md](docs/environments.md) を参照。

設定ファイルの再生成:

```sh
flutterfire configure --project goal-to-do-dev --platforms web --out lib/firebase_options_dev.dart
```

### ローカル開発（Emulator Suite）

```sh
firebase emulators:start                                          # Auth / Firestore / Hosting / UI(http://127.0.0.1:4000)
flutter run -d edge --dart-define=USE_FIREBASE_EMULATOR=true      # Emulator に接続して起動
```

### セキュリティルールのテスト

[rules_test/](rules_test/) に、Firestore Emulator 上で動かすセキュリティルールのテストがある。

```sh
npm --prefix rules_test ci   # 初回のみ
firebase emulators:exec --only firestore --project demo-goal-to-do "mise exec -- npm --prefix rules_test test"
```

- Firebase CLI（mise で入れたスタンドアロン版）は、`emulators:exec` の中で自前の古い Node を PATH の先頭に置く。テストは Node 24 以上が要るので、`mise exec --` を付けて mise の Node で実行する
- プロジェクト ID を `demo-` で始めると、Emulator だけを使い、実際のプロジェクトには接続しない

### デプロイ

```sh
firebase deploy --only auth,firestore --project dev   # 認証プロバイダとセキュリティルール
flutter build web && firebase deploy --only hosting --project dev
```

## よく使うコマンド

```sh
flutter pub get                # 依存関係の取得
flutter run -d edge            # Edge で起動（動作検証は Edge で行う）
flutter run -d web-server      # ブラウザを起動せずに開発サーバーだけ立てる
dart run build_runner watch -d # freezed・Riverpod のコード生成（変更を監視して生成し続ける）
dart analyze                   # 静的解析（riverpod_lint を含む）
dart format .                  # フォーマット
flutter test                   # テスト
flutter build web              # リリースビルド（出力先: build/web）
```
