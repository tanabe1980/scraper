---
paths:
  - "docker-compose.yml"
  - "dl_app/docker/**/*"
  - "dl_app/test/**/*"
---
# Docker運用ルール

## 基本方針
- `docker-compose.yml` はリポジトリ直下に配置する。
- `Dockerfile` は `dl_app/docker/` 配下に配置する。
- Docker用コードはオーバーライド用途に限定し、基幹システムは `dl_app/` 直下の実装を参照する。

## ディレクトリ構成
- `dl_app/docker/src/`:
  - ローカルDocker実行向けのオーバーライドソース
  - 共通ロジックの重複実装は禁止
  - `overrides/` と `bootstrap/` に用途分離する
- `dl_app/docker/data/`:
  - Docker実行時に必要なデータ
  - 一時ファイル/PostgreSQLデータ/ダウンロード結果を格納
  - `history/` と `downloads/` と `postgres/` に用途分離する
- `dl_app/test/`:
  - 単体テスト
  - テストデータ
  - `unit/` と `fixtures/` に用途分離する

## 実装ルール
- Docker向け実装は薄く保ち、業務ロジックは `dl_app/` 側に置く。
- 環境差分は設定ファイルで吸収し、分岐コードを最小化する。
- 機密情報をイメージやリポジトリに含めない。
