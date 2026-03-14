CREATE TABLE IF NOT EXISTS scrape_history (
  id UUID PRIMARY KEY,
  site_name TEXT NOT NULL,
  url TEXT NOT NULL,
  acquired_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'skipped')),
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  error_message TEXT NULL,
  downloaded_file_path TEXT NULL
);

CREATE INDEX IF NOT EXISTS idx_scrape_history_url_acquired_at
  ON scrape_history (url, acquired_at);
