# Goal to Do (Flutter)

## ドキュメント

- 要件: `docs/spec/REQ-001.md`、設計: `docs/design/DES-001.md`、環境（Firebase プロジェクト）の構成と今後の計画: `docs/environments.md`
- 決定済みの要件・設計を変える場合は、ユーザーに確認したうえで、該当するドキュメントも更新すること

## 開発環境の注意点（Windows）

- Flutter・Firebase CLI・Java のバージョンは `mise.toml` で固定している。mise のシムが PATH にないシェルでは `mise exec -- flutter ...` のように実行する
- FlutterFire CLI は `dart pub global run flutterfire_cli:flutterfire ...` で実行する（Pub のキャッシュの bin が PATH にないため）
- gcloud はそのままでは Python が見つからない。使うときは `CLOUDSDK_PYTHON="$(mise where python)/python.exe"` を設定する
- ローカル開発では Firebase Emulator Suite を使う（`firebase emulators:start`、アプリは `--dart-define=USE_FIREBASE_EMULATOR=true` で起動）
- `firebase deploy` は Claude Code の自動モードで権限確認により拒否されることがある。その場合は迂回せず、実行するコマンドを示してユーザーに実行してもらう

## 作業の進め方

- main から作業ブランチを切り、PR を作ってマージコミットで main に入れる
- コード生成の出力（`*.g.dart`・`*.freezed.dart`）はコミットしない。新しいワークツリーやモデル・プロバイダの変更後は `dart run build_runner build` を実行する
- 変更後は `dart format`・`dart analyze`・`flutter test`・`flutter build web` が通ることを確認する
- `firestore.rules` を変えたら、ルールのテストも通ることを確認する（`firebase emulators:exec --only firestore --project demo-goal-to-do "mise exec -- npm --prefix rules_test test"`。README を参照）
- Material は `package:material_ui/material_ui.dart` から使う（Flutter 3.47 で SDK から分離された）

## 動作検証

- Web アプリの動作検証は Microsoft Edge で行う（`flutter run -d edge`）。Chrome は使わない
  - 開発環境に Chrome をインストールしていないため、`flutter doctor` で `Cannot find Chrome` の警告が出るが、想定どおりなので対応不要
  - `CHROME_EXECUTABLE` の設定や Chrome のインストールを提案しないこと

## Git

- コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に則って書くこと
  - 形式: `<type>(<scope>): <description>`（scope は任意）
  - type は `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore` / `revert` から選ぶ
  - 破壊的変更は type の後ろに `!` を付けるか、フッターに `BREAKING CHANGE:` を書く
  - 例: `docs(spec): add MVP requirements for Flutter + Firebase rebuild`
