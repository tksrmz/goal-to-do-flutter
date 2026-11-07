# 環境構成（Firebase）

- 最終更新: 2026-11-08

開発用と本番用で Firebase プロジェクトを分ける。各プロジェクトの現状と、本番用を作るときの手順をまとめる。コマンドの使い方は [README](../README.md) を参照。

## 1. プロジェクト一覧

| 環境 | プロジェクト ID | 状態 | `.firebaserc` のエイリアス | Flutter の設定ファイル |
|------|----------------|------|--------------------------|----------------------|
| 開発 | `goal-to-do-dev` | 作成済み | `dev`（`default` も同じ） | [lib/firebase_options_dev.dart](../lib/firebase_options_dev.dart) |
| 本番 | `goal-to-do-prod` | 未作成（公開時に作る） | - | - |

`lib/firebase_options_*.dart` の値は秘密情報ではない（Web アプリのバンドルにそのまま含まれる）ので、リポジトリにコミットする。

## 2. 開発用（goal-to-do-dev）の現状

| 項目 | 状態 | 設定の場所 |
|------|------|-----------|
| Web アプリ | 登録済み（`1:540815118968:web:e829311b321ef5f392d38d`） | FlutterFire CLI |
| Firestore | `(default)` データベースを `asia-northeast1`（東京）に作成済み | Firebase CLI |
| Firestore のセキュリティルール | 暫定ですべての読み書きを拒否。リポジトリには設計書のルール（DES-001 5.2）を反映済みで、デプロイは未実施 | [firestore.rules](../firestore.rules)（`firebase deploy --only firestore`） |
| 認証プロバイダ | メールアドレス＋パスワードが有効 | [firebase.json](../firebase.json) の `auth`（`firebase deploy --only auth`） |
| ユーザーによるアカウント作成 | 無効（NFR-003）。`accounts:signUp` が `ADMIN_ONLY_OPERATION` で拒否されることを確認済み | コンソール（Authentication > Settings > User actions） |
| ログイン確認用のアカウント | 作成済み | コンソール（Authentication > Users） |
| Hosting | 未デプロイ | `firebase deploy --only hosting` |
| プラン | Identity Platform へのアップグレードなし（`subtype: FIREBASE_AUTH`） | - |

## 3. 本番用（goal-to-do-prod）を作るときの手順

開発用と同じ構成にする。コンソールでしか設定できない項目（★）があるので、漏れのないようにこの順で進める。

1. プロジェクトを作る: `firebase projects:create goal-to-do-prod`
2. Firestore を作る: Firestore API を有効にし、`firebase firestore:databases:create "(default)" --location asia-northeast1 --project goal-to-do-prod`
3. Web アプリを登録し、設定ファイルを作る: `flutterfire configure --project goal-to-do-prod --platforms web --out lib/firebase_options_prod.dart`
4. `.firebaserc` にエイリアス `prod` を追加する
5. 認証プロバイダとセキュリティルールを反映する: `firebase deploy --only auth,firestore --project prod`
6. ★ ユーザーによるアカウント作成を無効にする（Authentication > Settings > User actions の「Enable create (sign-up)」）
7. ★ 利用するアカウントを作る（Authentication > Users）
8. アプリをビルドしてデプロイする: `flutter build web` → `firebase deploy --only hosting --project prod`

### 本番用を作る前に決めること

| 事項 | 現時点の扱い |
|------|------------|
| ビルド時に開発用・本番用の設定ファイルを切り替える方法（`--dart-define` で選ぶなど） | 未決。現在の `lib/main.dart` は開発用の設定ファイルを直接読み込んでいる |
| 本番用のデプロイを誰がどう実行するか（手動 / CI） | 未決 |
