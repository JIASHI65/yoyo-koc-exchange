-- ============================================================
-- Migration 2026-07-16: Fix submissions + RLS + period fields
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Add missing columns to submissions
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS link TEXT DEFAULT '';
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS period TEXT DEFAULT '';

-- 2. Add period to redemption_orders
ALTER TABLE redemption_orders ADD COLUMN IF NOT EXISTS period TEXT DEFAULT '';

-- 3. Update existing redemption_orders with period from created_at
UPDATE redemption_orders SET period = TO_CHAR(created_at, 'YYYY-MM') WHERE period IS NULL OR period = '';

-- 4. Disable RLS on submissions (and any other tables missing it)
ALTER TABLE submissions DISABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_config DISABLE ROW LEVEL SECURITY;
ALTER TABLE score_imports DISABLE ROW LEVEL SECURITY;

-- 5. Create indices
CREATE INDEX IF NOT EXISTS idx_submissions_period ON submissions(period);
CREATE INDEX IF NOT EXISTS idx_redemption_orders_period ON redemption_orders(period);
CREATE INDEX IF NOT EXISTS idx_point_logs_period ON point_logs(period);
