# dl_app NASリリース運用手順(Windows 11)

## 目的/背景
- `main` マージ済みコードをNASの `releases` フォルダへ反映し、インストール済み端末を更新できるようにする。
- 自分専用運用を前提に、SaaS配布基盤を使わずに配布・更新を実施する。

## 変更点
- 開発端末向けに `scripts/windows/publish_release_to_nas.bat` / `.ps1` を追加した。
- 利用端末向けに `update_dl_app.bat` / `.ps1` を追加した。
- 設定サンプル `dl_app_release_config.json.example` を追加した。

## 影響範囲
- 開発端末:
  - `main` マージ後にNASへリリース反映する運用が追加される。
- 利用端末:
  - `update_dl_app.bat` クリックで更新可能になる。

## 前提
- 開発端末と利用端末がNAS共有にアクセス可能であること。
- 利用端末には `docker` / `docker compose` が利用可能であること。
- 利用端末のインストールフォルダに以下が存在すること。
  - `install_dl_app.bat`
  - `update_dl_app.bat`
  - `update_dl_app.ps1`
  - `dl_app_release_config.json`

## 1. 開発端末: リリース反映手順
1. `main` が最新であることを確認する。
2. コマンドプロンプトでリポジトリルートへ移動する。
3. 以下を実行する。

```bat
scripts\windows\publish_release_to_nas.bat -NasReleasesRoot "\\NAS\shared\dl_app\releases"
```

4. NASに以下が作成されることを確認する。
  - `releases\<version>\dl_app-<version>.zip`
  - `releases\<version>\release.json`
  - `releases\latest.json`

## 2. 利用端末: 更新手順
1. `dl_app_release_config.json.example` をコピーして `dl_app_release_config.json` を作成する。
2. `nas_releases_root` をNASの実パスに変更する。

```json
{
  "nas_releases_root": "\\\\NAS\\shared\\dl_app\\releases"
}
```

3. `update_dl_app.bat` を実行する。
4. 更新後に `docker compose -f docker-compose.yml ps` で起動状態を確認する。

## 3. 運用ルール
- `latest.json` はリリースファイル配置後に更新する。
- 不具合時の切り戻し用に1つ前のバージョンを削除しない。
- 利用端末での更新は作業前に `dl_app/docker/data` のバックアップを推奨する。

## テスト観点
- `main` 以外のブランチで publish 実行時にエラーになること。
- ワーキングツリーがdirtyな場合に publish が失敗すること。
- `latest.json` 更新後に `update_dl_app.bat` で新バージョンへ更新されること。
- 更新不要時に `.installed-version` と比較してスキップされること。
