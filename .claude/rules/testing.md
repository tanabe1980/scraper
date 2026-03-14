---
paths:
  - "tests/**/*.{py,ts,tsx}"
  - "pdf-app/**/test*/**/*.{py,ts,tsx}"
---
# テスト規約

## Python(pdf-app) - pytest
- 基本的にpytestを使用する。
- テストファイルに看板を付ける。
  - テンプレート
  ```python
  """
  名称:
  対象クラス:
  対象メソッド:
  概要:
    - 正常系:
    - 異常系:
  引数:
  期待する結果:
  """
  ```
- テスト内の関数/メソッドにも看板を付ける。
  - テンプレート
  ```python
  """
  名称:
  概要:
  input:
  テストの内容:
  期待する結果:
  """
  ```

## TypeScript(accounting-app) - 将来対応
- テストフレームワーク導入時は`vitest`または`jest`を使用する。
- コンポーネントテストは`@testing-library/react`を使用する。

## 共通
- コメントは多めにつける。
- 実装詳細ではなく振る舞いをテストする。
- 意味のないアサーション(例: assert True / expect(true).toBe(true))は禁止。
- テスト間の依存関係を持たせない。
