# dl_app インストールバッチ手順(Windows 11)

## 目的/背景
- Windows 11 環境で `dl_app` の初期セットアップを 1 コマンドで実行できるようにする。
- Docker Compose の build / 起動までを自動化し、手動手順の抜け漏れを防ぐ。

## 変更点
- リポジトリ直下に `install_dl_app.bat` を追加した。
- バッチ内で以下を実行する。
  - `docker` / `docker compose` の事前チェック
  - 実行に必要なディレクトリの作成
  - `dl-app-worker` の build
  - `dl-app-postgres` と `dl-app-worker` の起動

## 影響範囲
- 追加ファイル:
  - `install_dl_app.bat`
- 運用手順:
  - 初期セットアップ時は `install_dl_app.bat` を実行する。

## 実行前提
- OS: Windows 11
- Docker Desktop がインストール済みで起動していること
- 実行ユーザーが `docker` コマンドを実行できること

## 実行手順
1. コマンドプロンプトを開く。
2. リポジトリルートへ移動する。
3. 以下を実行する。

```bat
install_dl_app.bat
```

4. 起動確認を行う。

```bat
docker compose -f docker-compose.yml ps
```

## 更新設定(任意)
- NAS運用で更新する場合は、`dl_app_release_config.json.example` をコピーして `dl_app_release_config.json` を作成する。
- `nas_releases_root` にNASの `releases` パスを設定する。
- 更新時は `update_dl_app.bat` を実行する。

## テスト観点
- `docker` 未インストール時にエラー終了すること
- `docker compose` 未対応時にエラー終了すること
- 初回実行で必要ディレクトリが作成されること
- 再実行時に既存ディレクトリで異常終了しないこと
- `dl-app-postgres` / `dl-app-worker` が `up` 状態になること
