# ADR-001: Reading List管理とScraper分離アーキテクチャの技術選定

## 状態
提案

## 背景
- 実行環境は `Windows 11` と `Google Chrome` が前提。
- 要件は「ChromeのReading ListをURL詳細ページの管理台帳として扱い、一覧からURLを取得してScraper実行、成功後にReading Listから削除する」ことである。
- 実処理(ページ遷移、ダウンロード)はChrome内でなくてもよい。
- 履歴として `ID, サイト名, URL, 取得日, ステータス, 開始日` を永続管理する必要がある。
- Reading Listの取得・削除を安定的に行うためには、Chromeの公式APIを利用できる構成が必要である。

## 決定内容
- 本機能は以下のハイブリッド構成を採用する。
- **Chrome Extension (Manifest V3, TypeScript)**:
  - Reading Listの取得/削除のみ担当
  - ローカルScraperとの連携(対象URL送信、完了URL受信)を担当
- **Scraper Worker (Python + Playwright)**:
  - サイト別ルールでページアクセスし、ファイルダウンロードを担当
  - 実行履歴をPostgreSQLに記録
- **履歴ストア (PostgreSQL)**:
  - `ID, サイト名, URL, 取得日, ステータス, 開始日` を必須カラムとして保持
- E2Eテストは **Playwright** を採用する。
  - Scraper側E2E: Python Playwright
  - 拡張連携E2E: Playwright(Chromium)で拡張ロードして検証

## 結果・影響
- Chrome固有APIでReading List管理を行うため、UIスクレイピング依存を回避できる。
- Scraper本体をPythonに分離することで、サイト別ロジック拡張とテストがしやすくなる。
- 障害分離(Reading List連携失敗とScraper失敗を切り分け)が可能になる。
- ローカル常駐プロセス(拡張 + Worker)の監視・再起動手順が必要になる。

## 代替案
- 代替案1: Chrome Extension単体で全処理
  - サイト別Scraperロジックと履歴管理が拡張内に集中し、保守性が低下する。
- 代替案2: Python + Playwright単体
  - Reading Listの公式操作APIを直接使えないため、管理操作の堅牢性が不足する。
- 代替案3: Electron等の単一アプリ
  - 実装/配布コストが高く、要件に対して過剰。

## 参考
- https://developer.chrome.com/docs/extensions/reference/api/readingList
- https://developer.chrome.com/docs/extensions/reference/api/runtime
- https://developer.chrome.com/docs/extensions/reference/api/storage
- https://playwright.dev/python/docs/intro
- https://playwright.dev/docs/chrome-extensions
