-- ============================================================
-- KOC 系统修复：补上按月份(period)字段
-- 用法：Supabase 后台 → SQL Editor → 粘贴全文 → Run
-- 作用：让创作者投稿、兑换、后台发奖能按月份正常工作
-- 幂等：可重复执行，不会产生重复数据
-- ============================================================

-- 1. submissions 补 period 列
ALTER TABLE submissions ADD COLUMN IF NOT EXISTS period TEXT DEFAULT '';

-- 2. redemption_orders 补 period 列
ALTER TABLE redemption_orders ADD COLUMN IF NOT EXISTS period TEXT DEFAULT '';

-- 3. 回填历史数据（按创建时间补上月份）
UPDATE submissions SET period = TO_CHAR(created_at, 'YYYY-MM') WHERE period IS NULL OR period = '';
UPDATE redemption_orders SET period = TO_CHAR(created_at, 'YYYY-MM') WHERE period IS NULL OR period = '';

-- 4. 建索引（按月份查询更快）
CREATE INDEX IF NOT EXISTS idx_submissions_period ON submissions(period);
CREATE INDEX IF NOT EXISTS idx_redemption_orders_period ON redemption_orders(period);
