# dl_app ロボットチェック手動介入手順(Windows 11)

## 目的/背景
- ダウンロード中にロボットチェックが発生した場合、対象サイトと発生背景を明確にしながら手動対応できるようにする。
- 自動回避は行わず、`needs_manual_verification` へ遷移して人手で再開する。

## 変更点
- 手動確認イベントを記録する設計を追加した。
- 記録項目に以下を必須化した。
  - `site_name`
  - `check_provider`
  - `background`
  - `matched_signals`

## 影響範囲
- Worker実行時にロボットチェック検知で処理が自動停止する。
- 停止時の情報確認と再開操作が運用手順に追加される。

## 確認手順
1. `scrape_history.status` が `needs_manual_verification` の対象を確認する。
2. `manual_verification_events` から対象イベントを取得する。
3. 以下項目で「何のロボットチェックか」を判定する。
  - `site_name`
  - `check_provider`
  - `background`
  - `matched_signals`
4. 該当サイトで手動対応を行う。
5. 再開可能なら `scrape_history.status` を `queued` に戻す。

## SQL確認例
```sql
select
  m.created_at,
  m.site_name,
  m.check_provider,
  m.background,
  m.matched_signals,
  m.url
from manual_verification_events m
order by m.created_at desc
limit 20;
```

## テスト観点
- ロボットチェック検知時に `manual_verification_events` へ登録されること。
- `site_name/background/matched_signals` が空でないこと。
- `needs_manual_verification` への遷移後、`queued` へ戻して再実行できること。
