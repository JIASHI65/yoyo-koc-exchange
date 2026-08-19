-- 修复 RLS UPDATE/DELETE 策略漏洞
-- 在 Supabase SQL Editor 执行此脚本

-- 1. 删除旧的不完整策略
DROP POLICY IF EXISTS "point_logs_no_update" ON point_logs;
DROP POLICY IF EXISTS "point_logs_no_delete" ON point_logs;
DROP POLICY IF EXISTS "campaign_config_no_update" ON campaign_config;
DROP POLICY IF EXISTS "campaign_config_no_delete" ON campaign_config;
DROP POLICY IF EXISTS "kocs_no_update" ON kocs;
DROP POLICY IF EXISTS "kocs_no_delete" ON kocs;
DROP POLICY IF EXISTS "submissions_update_own" ON submissions;
DROP POLICY IF EXISTS "redemption_orders_no_update" ON redemption_orders;
DROP POLICY IF EXISTS "redemption_orders_no_delete" ON redemption_orders;

-- 2. 重新创建正确的策略（既检查 USING 也检查 WITH CHECK）

-- point_logs: 完全禁止 UPDATE/DELETE
CREATE POLICY "point_logs_no_update" ON point_logs
  FOR UPDATE
  USING (false)
  WITH CHECK (false);

CREATE POLICY "point_logs_no_delete" ON point_logs
  FOR DELETE
  USING (false);

-- campaign_config: 完全禁止 UPDATE/DELETE（创作者端只读）
CREATE POLICY "campaign_config_no_update" ON campaign_config
  FOR UPDATE
  USING (false)
  WITH CHECK (false);

CREATE POLICY "campaign_config_no_delete" ON campaign_config
  FOR DELETE
  USING (false);

-- kocs: 完全禁止 UPDATE/DELETE
CREATE POLICY "kocs_no_update" ON kocs
  FOR UPDATE
  USING (false)
  WITH CHECK (false);

CREATE POLICY "kocs_no_delete" ON kocs
  FOR DELETE
  USING (false);

-- submissions: 禁止修改已提交的投稿
CREATE POLICY "submissions_no_update" ON submissions
  FOR UPDATE
  USING (false)
  WITH CHECK (false);

-- redemption_orders: 完全禁止 UPDATE/DELETE（只能通过 RPC 创建，只有管理员能改状态）
CREATE POLICY "redemption_orders_no_update" ON redemption_orders
  FOR UPDATE
  USING (false)
  WITH CHECK (false);

CREATE POLICY "redemption_orders_no_delete" ON redemption_orders
  FOR DELETE
  USING (false);

-- 验证策略已生效
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('point_logs', 'campaign_config', 'kocs', 'submissions', 'redemption_orders')
  AND cmd IN ('UPDATE', 'DELETE')
ORDER BY tablename, cmd;
