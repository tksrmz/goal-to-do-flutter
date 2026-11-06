# Goal to Do (Flutter)

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
