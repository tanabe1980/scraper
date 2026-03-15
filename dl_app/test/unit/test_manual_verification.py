"""
名称: manual verification records test
対象クラス: RobotCheckProfile/ManualVerificationQueue
対象メソッド: load/build/append/list
概要:
  - 正常系: site profileでsite_name/backgroundを解決できる
  - 異常系: 不正statusが弾かれる
引数: pytest fixtures
期待する結果: 手動介入に必要な情報を記録できる
"""

from pathlib import Path

import pytest

from dl_app.worker.manual_verification import (
    ManualVerificationQueue,
    build_manual_verification_record,
    load_robot_check_profiles,
)


def test_build_record_resolves_site_name_and_background() -> None:
    """
    名称: profile一致時の情報解決
    概要: hostからsite_name/backgroundを解決して記録する
    input: URL, profiles
    テストの内容: recordのsite_name/background/statusを検証する
    期待する結果: site情報が埋まりneeds_manual_verificationになる
    """
    profiles = load_robot_check_profiles()
    record = build_manual_verification_record(
        url="https://sub.example.com/download/123",
        check_provider="recaptcha",
        detection_reason="selector_detected",
        matched_signals=["iframe[src*='recaptcha']"],
        status_before="running",
        profiles=profiles,
    )

    assert record.site_name == "sample_recaptcha_site"
    assert "reCAPTCHA" in record.background
    assert record.status_before == "running"
    assert record.status_after == "needs_manual_verification"


def test_build_record_rejects_unknown_status() -> None:
    """
    名称: 不正ステータス拒否
    概要: サポート外statusで例外になることを確認する
    input: status_before=unknown
    テストの内容: ValueError発生を検証する
    期待する結果: 不正入力が登録されない
    """
    profiles = load_robot_check_profiles()
    with pytest.raises(ValueError):
        build_manual_verification_record(
            url="https://example.com",
            check_provider="unknown",
            detection_reason="text_detected",
            matched_signals=["verify you are human"],
            status_before="unknown",
            profiles=profiles,
        )


def test_queue_persists_record_with_signals() -> None:
    """
    名称: キュー永続化
    概要: JSONLでsite_name/background/signalsを保存する
    input: tmp_path
    テストの内容: append後にlist_allで内容検証する
    期待する結果: 必須項目が欠落せず復元できる
    """
    profiles = load_robot_check_profiles()
    record = build_manual_verification_record(
        url="https://example.org/report",
        check_provider="cloudflare_turnstile",
        detection_reason="http_status",
        matched_signals=["403", "Verify you are human"],
        status_before="running",
        profiles=profiles,
    )

    queue = ManualVerificationQueue(log_path=Path(tmp_path) / "manual_verification.jsonl")
    queue.append(record)
    rows = queue.list_all()

    assert len(rows) == 1
    assert rows[0]["site_name"] == "sample_turnstile_site"
    assert rows[0]["check_provider"] == "cloudflare_turnstile"
    assert rows[0]["matched_signals"] == ["403", "Verify you are human"]

