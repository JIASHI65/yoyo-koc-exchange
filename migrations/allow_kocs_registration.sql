-- 允许创作者端注册新账号
-- 修复 RLS 策略：kocs 表的 INSERT 应该允许

-- 删除过严的策略
DROP POLICY IF EXISTS "kocs_no_insert" ON kocs;

-- 创建新策略：允许 INSERT（创作者注册）
CREATE POLICY "kocs_allow_insert" ON kocs
  FOR INSERT
  WITH CHECK (true);  -- 允许所有人注册

-- 注意：虽然允许 INSERT，但仍然防止 UPDATE/DELETE
-- 如果担心恶意注册，可以改为：
-- WITH CHECK (account_id IS NOT NULL AND uid IS NOT NULL);

-- 验证策略
SELECT policyname, cmd, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'kocs'
ORDER BY cmd, policyname;
