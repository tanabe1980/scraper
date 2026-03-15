CREATE TABLE IF NOT EXISTS scrape_history (
  id UUID PRIMARY KEY,
  site_name TEXT NOT NULL,
  url TEXT NOT NULL,
  acquired_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'skipped', 'needs_manual_verification')),
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  error_message TEXT NULL,
  downloaded_file_path TEXT NULL
);

CREATE INDEX IF NOT EXISTS idx_scrape_history_url_acquired_at
  ON scrape_history (url, acquired_at);

CREATE TABLE IF NOT EXISTS manual_verification_events (
  id UUID PRIMARY KEY,
  history_id UUID NULL REFERENCES scrape_history (id),
  site_name TEXT NOT NULL,
  url TEXT NOT NULL,
  check_provider TEXT NOT NULL,
  detection_reason TEXT NOT NULL,
  background TEXT NOT NULL,
  matched_signals JSONB NOT NULL DEFAULT '[]'::jsonb,
  screenshot_path TEXT NULL,
  html_snapshot_path TEXT NULL,
  status_before TEXT NOT NULL,
  status_after TEXT NOT NULL CHECK (status_after = 'needs_manual_verification'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_manual_verification_events_site_name
  ON manual_verification_events (site_name);
