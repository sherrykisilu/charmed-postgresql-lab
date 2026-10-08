#!/usr/bin/env bash
# Insert rows into a test table through the primary and show the row count.
# Usage: pg-write.sh [label]
set -euo pipefail
label="${1:-write}"
psql "$(cat ~/.pglab)" -v ON_ERROR_STOP=1 -q <<SQL
CREATE TABLE IF NOT EXISTS events (
  id         serial PRIMARY KEY,
  label      text NOT NULL,
  served_by  inet DEFAULT inet_server_addr(),
  created_at timestamptz DEFAULT now()
);
INSERT INTO events (label) SELECT '${label}' FROM generate_series(1, 100);
SELECT label, count(*) AS rows, max(served_by) AS primary_ip
FROM events GROUP BY label ORDER BY min(id);
SQL
