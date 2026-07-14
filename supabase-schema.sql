-- ============================================================
-- KOC 兑换系统 · Supabase Schema
-- 在 Supabase SQL Editor 中执行一次
-- 设计原则：现在全手动，以后自动算分无缝接入
-- ============================================================

-- 1. KOC 表（手动维护，以后主系统可接管）
CREATE TABLE kocs (
  uid TEXT PRIMARY KEY,              -- "YOYO-001" 格式
  discord_name TEXT NOT NULL,         -- Discord 昵称，KOC 登录时验证
  name TEXT DEFAULT '',               -- 真实姓名/游戏名
  channel_tag TEXT DEFAULT '',        -- TT/Ins/FB/Reddit
  status TEXT DEFAULT 'active' CHECK(status IN ('active','inactive')),
  region TEXT DEFAULT '',             -- 地区
  address TEXT DEFAULT '',            -- 收货地址
  account_id TEXT DEFAULT '',         -- 游戏 Account ID
  server TEXT DEFAULT '',             -- 正式服/灯塔服
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 积分流水表（唯一积分真相源）
--    source=manual      → 你现在手动录入
--    source=auto_settlement → 以后主系统自动写入
--    source=redemption   → KOC 兑换扣除（系统自动）
CREATE TABLE point_logs (
  id BIGSERIAL PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES kocs(uid),
  change INTEGER NOT NULL,           -- 正数加分，负数扣分
  balance_after INTEGER NOT NULL,    -- 变动后余额
  source TEXT NOT NULL DEFAULT 'manual' CHECK(source IN ('manual','auto_settlement','redemption')),
  reason TEXT NOT NULL,              -- "6月投稿结算" / "兑换钻石"
  period TEXT DEFAULT '',            -- "2026-06" 自动结算月份
  created_by TEXT DEFAULT '',        -- 操作人
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 兑换订单表
CREATE TABLE redemption_orders (
  id BIGSERIAL PRIMARY KEY,
  uid TEXT NOT NULL REFERENCES kocs(uid),
  discord_name TEXT NOT NULL,         -- 下单时 KOC 输入的 Discord 名
  koc_name TEXT DEFAULT '',
  option_type TEXT NOT NULL CHECK(option_type IN ('diamonds','gplay','merch')),
  option_name TEXT DEFAULT '',
  points_spent INTEGER NOT NULL,
  reward_amount TEXT DEFAULT '',
  contact_info TEXT DEFAULT '',       -- JSON 收货信息
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending','shipped','cancelled')),
  admin_notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by TEXT DEFAULT ''
);

-- 4. 兑换选项表（后台可配）
CREATE TABLE reward_options (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  points_cost INTEGER NOT NULL,
  description TEXT DEFAULT '',
  amount_text TEXT DEFAULT '',
  is_active BOOLEAN DEFAULT true
);

-- 初始兑换选项
INSERT INTO reward_options (name, points_cost, description, amount_text) VALUES
  ('💎 钻石', 1, '1 积分 = 450 钻石', '450 钻石'),
  ('🎮 Google Play $10', 2, '2 积分 = $10 礼品卡', '$10 Google Play 礼品卡'),
  ('📦 周边福袋', 3, '3 积分 = 随机 3 件周边', '随机周边 × 3');

-- 索引
CREATE INDEX idx_point_logs_uid ON point_logs(uid);
CREATE INDEX idx_point_logs_created ON point_logs(created_at DESC);
CREATE INDEX idx_redemption_orders_uid ON redemption_orders(uid);
CREATE INDEX idx_redemption_orders_status ON redemption_orders(status);
CREATE INDEX idx_redemption_orders_created ON redemption_orders(created_at DESC);

-- 当前积分视图
CREATE VIEW koc_balances AS
SELECT 
  k.uid, k.discord_name, k.name, k.channel_tag, k.status,
  COALESCE((
    SELECT balance_after FROM point_logs 
    WHERE uid = k.uid 
    ORDER BY created_at DESC, id DESC 
    LIMIT 1
  ), 0) AS current_points
FROM kocs k
WHERE k.status = 'active';

-- 获取当前积分
CREATE OR REPLACE FUNCTION get_balance(p_uid TEXT)
RETURNS INTEGER AS $$
  SELECT COALESCE(balance_after, 0) FROM point_logs
  WHERE uid = p_uid
  ORDER BY created_at DESC, id DESC
  LIMIT 1;
$$ LANGUAGE SQL;
