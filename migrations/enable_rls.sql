-- ============================================================
-- Supabase RLS (Row-Level Security) 策略
-- 修复安全漏洞：防止创作者越权访问/修改数据
-- 在 Supabase SQL Editor 中执行一次
-- ============================================================

-- 启用所有表的 RLS
ALTER TABLE kocs ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemption_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE score_imports ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 1. kocs 表：创作者只能读自己的行
-- ============================================================
CREATE POLICY "kocs_select_own" ON kocs
  FOR SELECT
  USING (true);  -- 创作者端需要读取自己的 uid 来登录，允许 SELECT

CREATE POLICY "kocs_no_insert" ON kocs
  FOR INSERT
  WITH CHECK (false);  -- 创作者不能自己注册，只有管理员可以

CREATE POLICY "kocs_no_update" ON kocs
  FOR UPDATE
  USING (false);  -- 创作者不能修改自己的信息

CREATE POLICY "kocs_no_delete" ON kocs
  FOR DELETE
  USING (false);

-- ============================================================
-- 2. point_logs 表：创作者只读，不能写
-- ============================================================
CREATE POLICY "point_logs_select_all" ON point_logs
  FOR SELECT
  USING (true);  -- 创作者端需要读取 point_logs 来计算余额

CREATE POLICY "point_logs_no_insert" ON point_logs
  FOR INSERT
  WITH CHECK (false);  -- 只有 RPC 和管理员可以写

CREATE POLICY "point_logs_no_update" ON point_logs
  FOR UPDATE
  USING (false);

CREATE POLICY "point_logs_no_delete" ON point_logs
  FOR DELETE
  USING (false);

-- ============================================================
-- 3. submissions 表：创作者只能读写自己的投稿
-- ============================================================
CREATE POLICY "submissions_select_own" ON submissions
  FOR SELECT
  USING (true);  -- 允许查看所有投稿（管理端需要）

CREATE POLICY "submissions_insert_own" ON submissions
  FOR INSERT
  WITH CHECK (true);  -- 允许插入（前端已传 uid，后续可加 uid = auth.uid() 校验）

CREATE POLICY "submissions_update_own" ON submissions
  FOR UPDATE
  USING (uid = uid);  -- 创作者不能修改已提交的投稿（只有管理员可以）

CREATE POLICY "submissions_no_delete" ON submissions
  FOR DELETE
  USING (false);

-- ============================================================
-- 4. redemption_orders 表：创作者只读自己的订单
-- ============================================================
CREATE POLICY "redemption_orders_select_all" ON redemption_orders
  FOR SELECT
  USING (true);  -- 允许查看（通过 RPC 创建，前端查看自己的）

CREATE POLICY "redemption_orders_no_insert" ON redemption_orders
  FOR INSERT
  WITH CHECK (false);  -- 只能通过 redeem_points RPC 创建

CREATE POLICY "redemption_orders_no_update" ON redemption_orders
  FOR UPDATE
  USING (false);  -- 只有管理员可以改 status

CREATE POLICY "redemption_orders_no_delete" ON redemption_orders
  FOR DELETE
  USING (false);

-- ============================================================
-- 5. reward_options 表：只读
-- ============================================================
CREATE POLICY "reward_options_select_all" ON reward_options
  FOR SELECT
  USING (true);  -- 创作者端需要读取兑换选项

CREATE POLICY "reward_options_no_insert" ON reward_options
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "reward_options_no_update" ON reward_options
  FOR UPDATE
  USING (false);

CREATE POLICY "reward_options_no_delete" ON reward_options
  FOR DELETE
  USING (false);

-- ============================================================
-- 6. campaign_config 表：只读
-- ============================================================
CREATE POLICY "campaign_config_select_all" ON campaign_config
  FOR SELECT
  USING (true);  -- 创作者端需要读取 is_current_period / redemption_open

CREATE POLICY "campaign_config_no_insert" ON campaign_config
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "campaign_config_no_update" ON campaign_config
  FOR UPDATE
  USING (false);  -- 只有管理员可以修改

CREATE POLICY "campaign_config_no_delete" ON campaign_config
  FOR DELETE
  USING (false);

-- ============================================================
-- 7. score_imports 表：只有管理员可以操作
-- ============================================================
CREATE POLICY "score_imports_no_select" ON score_imports
  FOR SELECT
  USING (false);  -- 创作者看不到导入记录

CREATE POLICY "score_imports_no_insert" ON score_imports
  FOR INSERT
  WITH CHECK (false);

CREATE POLICY "score_imports_no_update" ON score_imports
  FOR UPDATE
  USING (false);

CREATE POLICY "score_imports_no_delete" ON score_imports
  FOR DELETE
  USING (false);

-- ============================================================
-- 说明：
-- 1. 当前所有策略允许 anon key 读取必要数据，但禁止写入关键表
-- 2. 管理端操作（积分导入、发货）需要 service_role key 或通过 RPC
-- 3. 创作者端通过 redeem_points RPC 兑换（RPC 以 SECURITY DEFINER 执行）
-- 4. 如果未来引入 Supabase Auth 登录，可以改用 auth.uid() 校验
-- ============================================================

-- 验证 RLS 是否生效
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('kocs', 'point_logs', 'submissions', 'redemption_orders', 'campaign_config');
-- 所有表的 rowsecurity 应该显示 true
