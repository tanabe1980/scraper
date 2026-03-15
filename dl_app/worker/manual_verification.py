from __future__ import annotations

import fnmatch
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence
from urllib.parse import urlparse
from uuid import uuid4

PROCESS_STATUSES = {
    "queued",
    "running",
    "succeeded",
    "failed",
    "skipped",
    "needs_manual_verification",
}
MANUAL_VERIFICATION_STATUS = "needs_manual_verification"


@dataclass(frozen=True)
class RobotCheckProfile:
    site_name: str
    host_patterns: tuple[str, ...]
    background: str
    known_signals: tuple[str, ...]

    @classmethod
    def from_dict(cls, data: dict) -> "RobotCheckProfile":
        return cls(
            site_name=str(data["site_name"]),
            host_patterns=tuple(str(item) for item in data.get("host_patterns", [])),
            background=str(data.get("background", "")),
            known_signals=tuple(str(item) for item in data.get("known_signals", [])),
        )


@dataclass(frozen=True)
class ManualVerificationRecord:
    id: str
    site_name: str
    url: str
    check_provider: str
    detection_reason: str
    background: str
    matched_signals: tuple[str, ...]
    status_before: str
    status_after: str
    created_at: str


def default_profiles_path() -> Path:
    return Path(__file__).resolve().parent / "site_rules" / "robot_check_profiles.json"


def load_robot_check_profiles(path: Path | None = None) -> list[RobotCheckProfile]:
    profile_path = path or default_profiles_path()
    raw = json.loads(profile_path.read_text(encoding="utf-8"))
    profiles = raw.get("profiles", [])
    return [RobotCheckProfile.from_dict(item) for item in profiles]


def _resolve_site(url: str, fallback_site_name: str, profiles: Sequence[RobotCheckProfile]) -> tuple[str, str]:
    host = (urlparse(url).hostname or "").lower()
    for profile in profiles:
        for pattern in profile.host_patterns:
            if fnmatch.fnmatch(host, pattern.lower()):
                return profile.site_name, profile.background

    if fallback_site_name:
        return fallback_site_name, "No profile matched. Review robot check manually."
    if host:
        return host, "No profile matched. Review robot check manually."
    return "unknown_site", "No profile matched. Review robot check manually."


def build_manual_verification_record(
    *,
    url: str,
    check_provider: str,
    detection_reason: str,
    matched_signals: Sequence[str],
    status_before: str,
    profiles: Sequence[RobotCheckProfile],
    fallback_site_name: str = "",
) -> ManualVerificationRecord:
    if status_before not in PROCESS_STATUSES:
        raise ValueError(f"Unsupported status_before: {status_before}")

    site_name, background = _resolve_site(url=url, fallback_site_name=fallback_site_name, profiles=profiles)
    return ManualVerificationRecord(
        id=str(uuid4()),
        site_name=site_name,
        url=url,
        check_provider=check_provider,
        detection_reason=detection_reason,
        background=background,
        matched_signals=tuple(matched_signals),
        status_before=status_before,
        status_after=MANUAL_VERIFICATION_STATUS,
        created_at=datetime.now(timezone.utc).isoformat(),
    )


class ManualVerificationQueue:
    def __init__(self, log_path: Path):
        self._log_path = log_path

    def append(self, record: ManualVerificationRecord) -> None:
        self._log_path.parent.mkdir(parents=True, exist_ok=True)
        payload = asdict(record)
        payload["matched_signals"] = list(record.matched_signals)
        with self._log_path.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(payload, ensure_ascii=False))
            fp.write("\n")

    def list_all(self) -> list[dict]:
        if not self._log_path.exists():
            return []
        rows: list[dict] = []
        with self._log_path.open("r", encoding="utf-8") as fp:
            for line in fp:
                stripped = line.strip()
                if not stripped:
                    continue
                rows.append(json.loads(stripped))
        return rows

