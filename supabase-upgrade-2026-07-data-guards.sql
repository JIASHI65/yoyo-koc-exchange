-- ============================================================
-- Yoyo KOC data guards / low-cost constraints patch
-- Run manually in Supabase SQL Editor after reading the duplicate checks.
-- Date: 2026-07-23
--
-- Goals:
-- 1) backfill missing period values
-- 2) add light-format checks for period
-- 3) add audit_logs index for admin filtering
-- 4) add uniqueness guards for account_id / showcase / reward orders
--
-- IMPORTANT:
-- - This file does NOT delete business data.
-- - Read the duplicate checks first. If they return rows, clean them manually before
--   running the matching CREATE UNIQUE INDEX statements.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 0) Duplicate checks (run these first; empty result = safe to continue)
-- ------------------------------------------------------------

-- A. Duplicate non-empty account_id (excluding __config__)
SELECT account_id, COUNT(*) AS cnt, string_agg(uid, ', ' ORDER BY uid) AS uids
FROM kocs
WHERE COALESCE(account_id, '') <> '' AND uid <> '__config__'
GROUP BY account_id
HAVING COUNT(*) > 1;

-- B. Duplicate showcase rows by uid + period
SELECT uid, period, COUNT(*) AS cnt, string_agg(id::text, ', ' ORDER BY id) AS submission_ids
FROM submissions
WHERE submission_type = 'showcase' AND COALESCE(period, '') <> ''
GROUP BY uid, period
HAVING COUNT(*) > 1;

-- C. Duplicate non-cancelled reward orders by uid + period + option_type + option_name
SELECT uid, period, option_type, option_name, COUNT(*) AS cnt,
       string_agg(id::text, ', ' ORDER BY id) AS order_ids
FROM redemption_orders
WHERE COALESCE(period, '') <> '' AND status <> 'cancelled'
GROUP BY uid, period, option_type, option_name
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- 1) Backfill period values from created_at where missing
-- ------------------------------------------------------------
UPDATE submissions
SET period = TO_CHAR(created_at, 'YYYY-MM')
WHERE COALESCE(period, '') = '';

UPDATE redemption_orders
SET period = TO_CHAR(created_at, 'YYYY-MM')
WHERE COALESCE(period, '') = '';

UPDATE point_logs
SET period = TO_CHAR(created_at, 'YYYY-MM')
WHERE COALESCE(period, '') = '';

-- ------------------------------------------------------------
-- 2) Add lightweight format checks (allow historical empty string)
-- ------------------------------------------------------------
ALTER TABLE submissions
  DROP CONSTRAINT IF EXISTS submissions_period_format_check;
ALTER TABLE submissions
  ADD CONSTRAINT submissions_period_format_check
  CHECK (period = '' OR period ~ '^\d{4}-\d{2}$');

ALTER TABLE redemption_orders
  DROP CONSTRAINT IF EXISTS redemption_orders_period_format_check;
ALTER TABLE redemption_orders
  ADD CONSTRAINT redemption_orders_period_format_check
  CHECK (period = '' OR period ~ '^\d{4}-\d{2}$');

ALTER TABLE point_logs
  DROP CONSTRAINT IF EXISTS point_logs_period_format_check;
ALTER TABLE point_logs
  ADD CONSTRAINT point_logs_period_format_check
  CHECK (period = '' OR period ~ '^\d{4}-\d{2}$');

-- ------------------------------------------------------------
-- 3) Helpful audit index
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created
  ON audit_logs(action_type, created_at DESC);

-- ------------------------------------------------------------
-- 4) Uniqueness guards (safe after duplicate checks above are clean)
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_kocs_account_id_unique_nonempty
  ON kocs(account_id)
  WHERE COALESCE(account_id, '') <> '' AND uid <> '__config__';

CREATE UNIQUE INDEX IF NOT EXISTS idx_submissions_showcase_uid_period_unique
  ON submissions(uid, period)
  WHERE submission_type = 'showcase' AND COALESCE(period, '') <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_redemption_orders_uid_period_type_name_unique_active
  ON redemption_orders(uid, period, option_type, option_name)
  WHERE COALESCE(period, '') <> '' AND status <> 'cancelled';

COMMIT;
