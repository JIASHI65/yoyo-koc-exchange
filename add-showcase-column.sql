-- ============================================================
-- 官方周边 Showcase 支持：给 submissions 表加 submission_type 列
-- 在 Supabase SQL Editor 中执行一次
-- 说明：
--   submission_type = 'work'     → 常规投稿（默认，不影响历史数据）
--   submission_type = 'showcase' → 官方周边晒单，审核通过 +1 分
-- 前端已做回退：即使本列尚未添加，常规投稿也不会失败；
--              showcase 提交则会提示 "not enabled yet"，不会污染 2 次投稿计数。
-- ============================================================

ALTER TABLE submissions
  ADD COLUMN IF NOT EXISTS submission_type TEXT NOT NULL DEFAULT 'work'
  CHECK (submission_type IN ('work','showcase'));

-- 便于管理端按类型筛选 showcase 待审核
CREATE INDEX IF NOT EXISTS idx_submissions_type ON submissions(submission_type);

-- 历史数据回填（存量记录保持为常规投稿）
UPDATE submissions SET submission_type = 'work' WHERE submission_type IS NULL;
