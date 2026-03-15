# dl_app 技術選定・実装方針(Windows11 + Chrome Reading List)

## 目的/背景
- ChromeのReading Listを「URL詳細ページの管理リスト」として利用する。
- 実際のスクレイピングとダウンロード処理はChrome外で実行できる構成にする。
- 処理完了後に対象URLをReading Listから削除する。
- 各サイトごとの実行間隔と最大試行回数を制御する。
- 履歴として `ID, サイト名, URL, 取得日, ステータス, 開始日` を保存する。

## 変更点
- 実装をハイブリッド構成に変更する。
- Chromeの役割を「Reading List管理」に限定する。
- Scraper主処理を `Python + Playwright` で実装する。
- 履歴管理を `PostgreSQL` で永続化する。

## 採用構成

### 1. コンポーネント
- `chrome-list-agent` (Chrome Extension / TypeScript)
  - Reading List一覧取得
  - 完了URLのReading List削除
  - ローカルWorkerとの連携
- `scraper-worker` (Python + Playwright)
  - URLごとにサイトルールを判定
  - ダウンロード処理
  - 履歴記録・再試行制御
- `PostgreSQL`
  - 履歴と実行状態を永続管理

### 2. 連携方式
- 推奨: `localhost` API連携
  - 拡張 -> Worker: `POST /tasks`
  - Worker -> 拡張: `POST /results` または 拡張が `GET /results` でポーリング
- 代替: 共有JSONファイル連携
  - MVPで許容。ただし整合性管理が弱いため本番非推奨

## データモデル(PostgreSQL)

### 履歴テーブル: `scrape_history`

| カラム | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | UUID | Yes | 履歴ID(一意) |
| `site_name` | TEXT | Yes | サイト名(ルール識別名) |
| `url` | TEXT | Yes | 対象URL |
| `acquired_at` | TIMESTAMPTZ | Yes | Reading Listから取得した日時(取得日) |
| `status` | TEXT | Yes | `queued/running/succeeded/failed/skipped` |
| `started_at` | TIMESTAMPTZ | Yes | 当該処理の開始日時(開始日) |
| `finished_at` | TIMESTAMPTZ | No | 処理完了日時 |
| `attempt_count` | INTEGER | Yes | 試行回数 |
| `error_message` | TEXT | No | 失敗理由 |
| `downloaded_file_path` | TEXT | No | 保存ファイルパス |

制約:
- `id` は主キー
- `status` は列挙値制約
- `url + acquired_at` にインデックスを張る

### 手動確認イベントテーブル: `manual_verification_events`

| カラム | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | UUID | Yes | 手動確認イベントID |
| `history_id` | UUID | No | `scrape_history.id` への参照 |
| `site_name` | TEXT | Yes | 対象サイト名 |
| `url` | TEXT | Yes | 対象URL |
| `check_provider` | TEXT | Yes | `recaptcha/hcaptcha/cloudflare_turnstile/unknown` |
| `detection_reason` | TEXT | Yes | 検知理由(`selector_detected` 等) |
| `background` | TEXT | Yes | なぜ当該サイトでチェックが出るかの背景 |
| `matched_signals` | JSONB | Yes | 検知根拠(セレクタ,HTTPステータス,文言等) |
| `screenshot_path` | TEXT | No | 画面証跡 |
| `html_snapshot_path` | TEXT | No | HTML証跡 |
| `status_before` | TEXT | Yes | 変更前ステータス |
| `status_after` | TEXT | Yes | 変更後ステータス(`needs_manual_verification`) |
| `created_at` | TIMESTAMPTZ | Yes | 発生日時 |

## サイトルール設計

`sites.config.yaml` でサイト固有処理を定義する。

```yaml
sites:
  - site_name: site_a
    match:
      host: example.com
      path_prefix: /report
    schedule:
      interval_minutes: 60
      max_runs: 8
    download_rule:
      wait_selector: "#report-table"
      click_selector: "a#download-csv"
      timeout_ms: 30000
      download_dir: "downloads/site_a"
```

必須要件:
- `site_name`
- URLマッチ条件
- `interval_minutes`
- `max_runs`
- ダウンロード操作定義

## ロボットチェック判定プロファイル

- `dl_app/worker/site_rules/robot_check_profiles.json` でサイト別の判定背景を管理する。
- プロファイルに持つ情報:
  - `site_name`
  - `host_patterns`
  - `background`
  - `known_signals`
- 検知時はURLのホストと `host_patterns` を照合し、`site_name` と `background` を解決する。

## 実行フロー
1. `chrome-list-agent` がReading Listから対象URLを取得する。
2. `scraper-worker` へ対象URLを投入し、履歴を `queued` で作成する。
3. Workerはサイトルールに一致するURLのみ実行対象とする。
4. 実行開始時に履歴を `running` に更新し、`started_at` を記録する。
5. Playwrightでロボットチェックを検知した場合は、`site_name / check_provider / background / matched_signals` を `manual_verification_events` に記録する。
6. ロボットチェック検知時は履歴を `needs_manual_verification` に更新し、手動介入待ちにする。
7. 手動介入後に再実行可能と判断した対象は `queued` に戻して再実行する。
8. 成功時は、履歴を `succeeded` に更新し、拡張へ削除対象URLを通知してReading Listから削除する。
9. 失敗時は、履歴を `failed` に更新し、回数上限未満なら次回スケジュールで再試行する。
10. 失敗が `max_runs` に達した対象は `skipped` として停止管理する。

## ステータス遷移
- `queued` -> `running` -> `succeeded`
- `queued` -> `running` -> `failed`
- `queued` -> `running` -> `needs_manual_verification`
- `needs_manual_verification` -> `queued` (手動介入後の再開)
- `failed` -> `queued` (再試行時)
- `failed` -> `skipped` (max_runs到達時)

## 配布・更新フロー(NASリリース運用)
- 対象は自分専用のWindows端末を前提とし、SaaS配布基盤は利用しない。
- リリース媒体はNAS上の `releases` フォルダを利用する。
- 配布ポリシー:
  - `main` マージ済みのコミットのみを配布対象にする。
  - リリース作成時に `latest.json` を更新して最新バージョンを指し替える。
- 構成要素:
  - `scripts/windows/publish_release_to_nas.ps1`:
    - `main` / clean working tree / `origin/main` 同期を確認
    - リリースZIP(`dl_app-<version>.zip`)を作成
    - `releases/<version>/` 配下へZIPとハッシュを配置
    - `releases/latest.json` を更新
  - `update_dl_app.ps1`:
    - インストール端末で `latest.json` を参照
    - バージョン差分がある場合のみ更新
    - 更新時は `docker compose down` -> ファイル反映 -> `install_dl_app.bat` 再実行
- 更新判定:
  - ローカルの `.installed-version` と `latest.json.version` を比較する。
  - 同一バージョンなら更新をスキップする。
- 設定:
  - NASのリリースルートは `dl_app_release_config.json` の `nas_releases_root` で定義する。

## 影響範囲
- 新規作成:
  - `dl_app/extension/` (Reading List連携)
  - `dl_app/worker/` (Python Playwright Scraper)
  - `dl_app/storage/` (PostgreSQLスキーマ)
  - `dl_app/docker/` (Dockerローカル実行オーバーライド)
  - `docker-compose.yml` (リポジトリ直下)
  - `install_dl_app.bat` (初期インストール)
  - `update_dl_app.bat` / `update_dl_app.ps1` (端末更新)
  - `scripts/windows/publish_release_to_nas.bat` / `scripts/windows/publish_release_to_nas.ps1` (NAS反映)
  - `dl_app_release_config.json.example` (更新設定サンプル)
  - `dl_app/worker/manual_verification.py` (手動確認イベントモデル)
  - `dl_app/worker/site_rules/robot_check_profiles.json` (サイト別背景定義)
  - `dl_app/docker/src/bootstrap/001_init.sql` (manual_verification_events追加)
  - `tests/e2e/` (連携E2E)
  - `tests/unit/` (ルール判定・状態遷移)
- 既存影響:
  - 既存機能への直接影響なし

## Dockerディレクトリ方針
- `docker-compose.yml` はリポジトリ直下に置く。
- `dl_app/docker/Dockerfile` をコンテナビルド定義とする。
- `dl_app/docker/src/` はローカル向けオーバーライド専用とし、基幹処理は `dl_app/` 側を参照する。
  - `dl_app/docker/src/overrides/` と `dl_app/docker/src/bootstrap/` に用途分離する。
- `dl_app/docker/data/` はDocker実行時データを格納する。
  - `dl_app/docker/data/history/` と `dl_app/docker/data/downloads/` と `dl_app/docker/data/postgres/` に用途分離する。
- `dl_app/test/` は単体テストおよびテストデータの配置先とする。
  - `dl_app/test/unit/` と `dl_app/test/fixtures/` に用途分離する。

## テスト観点
- 正常系:
  - Reading List取得 -> Scrape成功 -> 履歴`succeeded` -> Reading List削除
  - サイト別ルールに基づくダウンロード実行
  - interval経過後のみ再試行対象化
- 異常系:
  - ルール不一致URLの`skipped`
  - 要素未検出/タイムアウトによる`failed`
  - ロボットチェック検知時の `needs_manual_verification` 遷移
  - `manual_verification_events` に `site_name/background/matched_signals` が保存されること
  - `max_runs` 到達時の再試行停止
  - 拡張側削除失敗時の再同期
- データ整合:
  - 同一URL重複投入時の履歴一意性
  - `acquired_at` と `started_at` の時刻整合

## 受け入れ基準
- Chrome Reading ListからURLを取得しScraper投入できる。
- 成功時のみReading Listから削除される。
- 履歴に `ID, サイト名, URL, 取得日, ステータス, 開始日` が必ず保存される。
- ロボットチェック検知時に、対象サイト名と背景情報を確認できる記録が保存される。
- サイトごとの間隔/上限回数が設定通り機能する。
