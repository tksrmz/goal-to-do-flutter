# Goal to Do (Flutter)

目的・目標・タスクを紐付けて管理する Web アプリ。要件は [docs/spec/REQ-001.md](docs/spec/REQ-001.md) を参照。

## 開発環境

Flutter・Firebase CLI・Java（Firestore Emulator 用）のバージョンは [mise](https://mise.jdx.dev/) で管理し、[mise.toml](mise.toml) で固定している。

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

| 環境 | プロジェクト ID | `.firebaserc` のエイリアス | Flutter の設定ファイル |
|------|----------------|--------------------------|----------------------|
| 開発 | `goal-to-do-dev` | `dev`（`default` も同じ） | [lib/firebase_options_dev.dart](lib/firebase_options_dev.dart) |
| 本番 | `goal-to-do-prod`（未作成） | - | - |

- Firestore のロケーション: `asia-northeast1`（東京）
- Firestore のセキュリティルール: [firestore.rules](firestore.rules)（コレクション設計が決まるまではすべて拒否）
- `lib/firebase_options_*.dart` の値は秘密情報ではない（Web アプリのバンドルにそのまま含まれる）

設定ファイルの再生成:

```sh
flutterfire configure --project goal-to-do-dev --platforms web --out lib/firebase_options_dev.dart
```

### ローカル開発（Emulator Suite）

```sh
firebase emulators:start                                          # Auth / Firestore / Hosting / UI(http://127.0.0.1:4000)
flutter run -d edge --dart-define=USE_FIREBASE_EMULATOR=true      # Emulator に接続して起動
```

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
flutter analyze                # 静的解析
dart format .                  # フォーマット
flutter test                   # テスト
flutter build web              # リリースビルド（出力先: build/web）
```
