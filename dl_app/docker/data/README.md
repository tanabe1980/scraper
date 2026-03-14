# docker/data

Docker実行時に使用するローカルデータを配置する。

- 例: 一時ファイル、ダウンロードファイル、PostgreSQLデータ
- 本番データは配置しない。
- 機密情報をコミットしない。

サブディレクトリ:
- `history/`: 履歴DBや履歴エクスポート
- `downloads/`: 取得ファイル
- `postgres/`: PostgreSQL永続データ
