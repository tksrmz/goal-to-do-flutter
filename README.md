# Goal to Do (Flutter)

目的・目標・タスクを紐付けて管理する Web アプリ。要件は [docs/spec/REQ-001.md](docs/spec/REQ-001.md) を参照。

## 開発環境

Flutter のバージョンは [mise](https://mise.jdx.dev/) で管理し、[mise.toml](mise.toml) で固定している。

```sh
mise trust     # 初回のみ
mise install
flutter --version
```

## よく使うコマンド

```sh
flutter pub get                # 依存関係の取得
flutter run -d chrome          # Chrome で起動（Edge の場合は -d edge）
flutter run -d web-server      # ブラウザを起動せずに開発サーバーだけ立てる
flutter analyze                # 静的解析
dart format .                  # フォーマット
flutter test                   # テスト
flutter build web              # リリースビルド（出力先: build/web）
```
