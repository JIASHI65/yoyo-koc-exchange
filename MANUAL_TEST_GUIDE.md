# 🧪 KOC 系统上线前人工测试清单

**测试目标**: 完整跑通一个月的结算周期，从投稿到发货  
**测试时间**: 预计 2-3 小时  
**测试环境**: 生产数据库 + GitHub Pages 部署  
**测试日期**: _______

---

## 📋 测试前准备（10分钟）

### 1. 创建测试账号
在 Supabase SQL Editor 执行：

```sql
-- 创建 3 个测试创作者
INSERT INTO kocs (uid, account_id, discord_name, name, status, tier, server, country, region, notes, created_at)
VALUES
  ('MANUALTEST001', '6888888801000000001', 'ManualTest-Newbie', 'Manual Test Newbie', 'active', 'certified', 'Official', 'US', 'NA', '{"newbie_month":"2026-08"}', now()),
  ('MANUALTEST002', '6888888802000000002', 'ManualTest-Regular', 'Manual Test Regular', 'active', 'certified', 'Official', 'US', 'NA', 'old_creator', now()),
  ('MANUALTEST003', '6888888803000000003', 'ManualTest-Gold', 'Manual Test Gold', 'active', 'gold', 'Official', 'US', 'NA', 'old_creator', now());

-- 验证创建成功
SELECT uid, account_id, discord_name, tier FROM kocs WHERE uid LIKE 'MANUALTEST%';
```

**预期**: 看到 3 行测试账号

---

### 2. 设置当前结算期
```sql
-- 清空所有期的 is_current_period
UPDATE campaign_config SET is_current_period = false;

-- 设置 2026-08 为当前期（改成你实际要测的月份）
UPDATE campaign_config SET is_current_period = true WHERE period = '2026-08';

-- 开启投稿和兑换开关
UPDATE campaign_config 
SET submissions_open = true, redemption_open = true 
WHERE period = '2026-08';

-- 验证
SELECT period, is_current_period, submissions_open, redemption_open 
FROM campaign_config 
WHERE is_current_period = true;
```

**预期**: 只有一行显示 `2026-08, true, true, true`

---

### 3. 清理测试账号的历史数据
```sql
DELETE FROM point_logs WHERE uid LIKE 'MANUALTEST%';
DELETE FROM submissions WHERE uid LIKE 'MANUALTEST%';
DELETE FROM redemption_orders WHERE uid LIKE 'MANUALTEST%';
```

---

## 🎨 第一阶段：创作者投稿（30分钟）

**投稿次数口径**：每期最多 2 次有效常规投稿；被拒绝投稿释放一次机会，Showcase 不占这 2 次。

### 测试 1.1: 登录与期号显示

**操作**:
1. 打开创作者端: https://jiashi65.github.io/yoyo-koc-exchange/index.html
2. 点击 "I'm already a creator"
3. 输入:
   - Game UID: `MANUALTEST001`
   - System ID: `6888888801000000001`
4. 点击 Login

**预期结果**:
- ✅ 登录成功，进入 Dashboard
- ✅ 顶部显示 "Welcome, ManualTest-Newbie"
- ✅ "Submit Works" 标签下显示 **"Aug 2026 Settlement Period"**（或你设置的月份）
- ✅ 显示余额 0 pts

**如果失败**:
- [ ] 检查是否清除浏览器缓存（Cmd+Shift+R）
- [ ] 检查 `campaign_config` 的 `is_current_period` 是否设置正确
- [ ] 打开浏览器 Console（F12），看是否有 JavaScript 错误

---

### 测试 1.2: 提交作品（第1次）

**操作**:
1. 在 "Submit Works" 标签
2. Discord Username 应该已预填 `ManualTest-Newbie`
3. 在 "Content Links" 输入:
```
https://facebook.com/test-post-1
https://instagram.com/p/test-post-2
https://tiktok.com/@user/video/test-post-3
```
4. Feedback 留空（可选）
5. 点击 "📤 Submit Works"

**预期结果**:
- ✅ 显示 "✅ Works submitted successfully"
- ✅ 提示切换到 "My Submissions" 标签查看

**验证数据库**:
```sql
SELECT id, uid, discord_name, submission_type, status, created_at
FROM submissions
WHERE uid = 'MANUALTEST001'
ORDER BY created_at DESC
LIMIT 1;
```
**预期**: 看到一行 `status='pending'`, `submission_type='work'`

**如果失败**:
- [ ] 检查链接格式是否正确（每行一个链接）
- [ ] 检查 Console 是否有网络错误
- [ ] 检查 `campaign_config.submissions_open` 是否为 `true`

---

### 测试 1.3: 查看投稿历史

**操作**:
1. 切换到 "📋 My Submissions" 标签
2. 看到 "202608" 月份标签（默认显示当前期）

**预期结果**:
- ✅ 显示 "📅 202608 · Work links 3"（3条链接）
- ✅ 投稿状态显示 "⏳ Pending"
- ✅ 显示提交日期

---

### 测试 1.4: 提交作品（第2次）

**操作**:
1. 返回 "🎨 Submit Works" 标签
2. 输入不同的链接:
```
https://youtube.com/watch?v=test-video-1
https://reddit.com/r/test/comments/test-post
```
3. 点击 "📤 Submit Works"

**预期结果**:
- ✅ 提交成功

**验证**:
```sql
SELECT COUNT(*) FROM submissions 
WHERE uid = 'MANUALTEST001' AND period = '2026-08' AND submission_type = 'work';
```
**预期**: 显示 `2`

---

### 测试 1.5: 2次限额测试

**操作**:
1. 再次尝试提交第3次

**预期结果**:
- ✅ 前端拦截，显示 "You have already submitted 2 times for this period (max 2)"
- ✅ 不发送请求

---

### 测试 1.6: Showcase 投稿（不占2次名额）

**操作**:
1. 向下滚动到 "📸 Official Merch Showcase" 卡片
2. 输入链接: `https://instagram.com/p/test-merch-photo`
3. 点击 "📸 Submit Showcase"

**预期结果**:
- ✅ 提交成功
- ✅ 返回 "My Submissions"，看到 showcase 单独显示（不计入 work 的 2 次）

**验证**:
```sql
SELECT submission_type, COUNT(*) 
FROM submissions 
WHERE uid = 'MANUALTEST001' AND period = '2026-08'
GROUP BY submission_type;
```
**预期**: `work: 2`, `showcase: 1`

---

### 测试 1.7: 其他账号投稿

**操作**:
1. 登出（点左上角 "‹ Back"）
2. 用 `MANUALTEST002` / `6888888802000000002` 登录
3. 提交 1 条作品
4. 登出，用 `MANUALTEST003` / `6888888803000000003` 登录
5. 提交 2 条作品

**目的**: 准备多个账号的投稿数据供后续测试

---

## 📊 第二阶段：管理端算分导入（30分钟）

### 测试 2.1: 管理端登录

**操作**:
1. 打开管理端: https://jiashi65.github.io/yoyo-koc-exchange/admin.html
2. 输入密码: `yoyo2026`
3. 点击 Login

**预期结果**:
- ✅ 进入管理面板
- ✅ 看到 "📅 Period: 2026-08" 下拉选择器

---

### 测试 2.2: 查看待审核投稿

**操作**:
1. 切换到 "🎨 作品审核" 标签
2. 看到所有 `status='pending'` 的投稿

**预期结果**:
- ✅ 看到至少 5 条 pending 投稿（3个账号提交的）
- ✅ 每条显示 Discord 昵称、链接数量、提交时间

---

### 测试 2.3: 模拟 codex 算分输出

**准备算分 JSON**（模拟 codex 的输出）:
```json
[
  {
    "uid": "MANUALTEST001",
    "discord_name": "ManualTest-Newbie",
    "raw_points": 6,
    "final_points": 6,
    "breakdown": "TikTok 200播放=1分, FB 80互动=2分, IG 120互动=3分",
    "submission_ids": []
  },
  {
    "uid": "MANUALTEST002",
    "discord_name": "ManualTest-Regular",
    "raw_points": 15,
    "final_points": 15,
    "breakdown": "5条帖子各3分",
    "submission_ids": []
  },
  {
    "uid": "MANUALTEST003",
    "discord_name": "ManualTest-Gold",
    "raw_points": 50,
    "final_points": 40,
    "breakdown": "10条帖子各5分，触顶40分",
    "submission_ids": []
  }
]
```

---

### 测试 2.4: 导入积分

**操作**:
1. 切换到 "📊 积分计算" 标签
2. 粘贴上面的 JSON 到文本框
3. 点击 "Preview Import"

**预期结果**:
- ✅ 显示预览表格，3行数据
- ✅ 每行显示 UID, Discord Name, Raw, Final, Breakdown
- ✅ 显示匹配状态（应该都是绿色 ✓）

**如果显示红色 X**:
- [ ] 检查 UID 是否存在于 `kocs` 表
- [ ] 检查 JSON 格式是否正确

---

**操作**（继续）:
4. 点击 "Confirm & Apply"
5. 等待处理完成

**预期结果**:
- ✅ 显示 "✅ Import completed: 3 creators, X submissions scored"
- ✅ 显示 "Newbie bonus applied: MANUALTEST001 (+2 pts)" （因为是新人且 raw≥5）

**验证数据库**:
```sql
-- 检查 point_logs 是否写入
SELECT uid, change, source, reason 
FROM point_logs 
WHERE uid LIKE 'MANUALTEST%'
ORDER BY created_at DESC;
```
**预期**: 看到
- `MANUALTEST001: +6 (auto_settlement) + +2 (newbie_bonus)`
- `MANUALTEST002: +15 (auto_settlement)`
- `MANUALTEST003: +40 (auto_settlement)`

```sql
-- 检查 submissions 状态是否变 scored
SELECT uid, status, points_earned 
FROM submissions 
WHERE uid LIKE 'MANUALTEST%';
```
**预期**: 所有投稿 `status='scored'`, `points_earned` 已填充

---

### 测试 2.5: 防重复导入

**操作**:
1. 再次点击 "Confirm & Apply"（用同样的 JSON）

**预期结果**:
- ✅ 显示 "Skipped duplicate for MANUALTEST001 (already scored for 2026-08)"
- ✅ 不重复写 `point_logs`

**验证**:
```sql
SELECT uid, COUNT(*) 
FROM point_logs 
WHERE uid LIKE 'MANUALTEST%' AND period = '2026-08'
GROUP BY uid;
```
**预期**: 每个 UID 的 count 没有增加

---

### 测试 2.6: Showcase 审核通过

**操作**:
1. 切换到 "🎨 作品审核" 标签
2. 找到 `MANUALTEST001` 的 showcase 投稿
3. 点击 "✅ Pass"

**预期结果**:
- ✅ 显示 "Showcase approved, +1 pt added"
- ✅ 该投稿状态变为 `scored`

**验证**:
```sql
SELECT change, source, reason 
FROM point_logs 
WHERE uid = 'MANUALTEST001' AND source = 'showcase_bonus';
```
**预期**: 看到 `+1, showcase_bonus`

**检查总余额**:
```sql
SELECT SUM(change) FROM point_logs WHERE uid = 'MANUALTEST001';
```
**预期**: `6 (settlement) + 2 (newbie) + 1 (showcase) = 9`

---

## 💬 第三阶段：CSV 解析预览测试（禁止发送，15分钟）

### 测试 3.1: 准备 CSV

创建文件 `test_broadcast.csv`:
```csv
ManualTest-Newbie,MANUALTEST001,Hi! You earned 9 points this month: 6 from submissions + 2 newbie bonus + 1 showcase. Great job!
ManualTest-Regular,MANUALTEST002,You earned 15 points! Keep up the good work.
ManualTest-Gold,MANUALTEST003,You earned 40 points (capped). You're amazing!
```

---

### 测试 3.2: CSV 上传与解析

**操作**:
1. 管理端切换到 "📢 Mochi 广播" 标签
2. 点击 "📄 Import CSV"，选择 `test_broadcast.csv`
3. 或者直接粘贴 CSV 内容到文本框
4. 点击 "Parse CSV"

**预期结果**:
- ✅ 显示 "Parsed 3 rows"
- ✅ 每行显示:
  - Discord 昵称
  - 匹配状态（绿色 ✓ "matched by UID" 或 "matched by discord name"）
  - 话术预览（前50字符）
- ✅ 三个复选框都自动勾选

**如果显示红色 X "not matched"**:
- [ ] 检查 UID 或 Discord 昵称是否正确
- [ ] 检查 CSV 格式（逗号分隔，三列）

---

### 测试 3.3: CSV 状态清除

**操作**:
1. 点击任意一个预设按钮（如 "Send Welcome"）

**预期结果**:
- ✅ CSV 解析状态被清空
- ✅ 列表恢复为空

---

## 🎁 第四阶段：创作者兑换（20分钟）

### 测试 4.1: 查看积分余额

**操作**:
1. 返回创作者端
2. 用 `MANUALTEST001` / `6888888801000000001` 登录
3. 切换到 "🎁 Redeem Rewards" 标签

**预期结果**:
- ✅ 显示 "Available Points: 9"（或你计算的总分）
- ✅ 显示 tier badge（如 "✅ Certified Creator"）

**如果余额不对**:
```sql
-- 手动检查余额
SELECT SUM(change) FROM point_logs WHERE uid = 'MANUALTEST001';

-- 检查是否有 pending 订单
SELECT SUM(points_spent) FROM redemption_orders 
WHERE uid = 'MANUALTEST001' AND status = 'pending';
```

---

### 测试 4.2: 选择兑换奖励

**操作**:
1. 在钻石卡片，点击 "+ Add" 按钮
2. 数量选择器选 `5`（需要 5 分）
3. 在谷歌卡卡片，点击 "+ Add"
4. 数量选择器选 `2`（需要 4 分）
5. 总计：5 + 4 = 9 分

**预期结果**:
- ✅ 显示 "💎 钻石 × 5 = 5 pts"
- ✅ 显示 "🎁 谷歌卡 × 2 = 4 pts"
- ✅ 总计显示 "9 pts"
- ✅ "Confirm Redemption" 按钮可点击

---

### 测试 4.3: 尝试选择第3种奖励（应被拦截）

**操作**:
1. 尝试点击周边卡片的 "+ Add"

**预期结果**:
- ✅ 弹出提示 "You can only select up to 2 reward types"
- ✅ 不添加第3种

---

### 测试 4.4: 提交兑换

**操作**:
1. Shipping Info 输入: `Test Address, City, 12345, US, +1234567890`（可选，看你的规则）
2. 点击 "Confirm Redemption"

**预期结果**:
- ✅ 显示 "✅ Redemption successful!"
- ✅ 可用余额更新为 `0`（9 - 9）
- ✅ 页面刷新，"My Orders" 区域显示 2 条 pending 订单

**验证数据库**:
```sql
SELECT option_name, points_spent, reward_amount, status 
FROM redemption_orders 
WHERE uid = 'MANUALTEST001'
ORDER BY created_at DESC;
```
**预期**: 看到 2 条 `status='pending'` 订单

---

### 测试 4.5: 余额预留测试

**操作**:
1. 再次尝试兑换（此时余额应该是 0）

**预期结果**:
- ✅ 选择任何奖励后，点击 "Confirm Redemption"
- ✅ 显示 "Insufficient points"
- ✅ 不创建订单

---

### 测试 4.6: 兑换开关关闭测试

**操作**:
1. 在 Supabase SQL Editor 执行:
```sql
UPDATE campaign_config SET redemption_open = false WHERE period = '2026-08';
```
2. 刷新创作者端页面

**预期结果**:
- ✅ "Confirm Redemption" 按钮变为禁用（灰色）
- ✅ 显示 "🔒 Redemption is not open yet"

**恢复开关**:
```sql
UPDATE campaign_config SET redemption_open = true WHERE period = '2026-08';
```

---

## 📦 第五阶段：管理端发货（20分钟）

### 测试 5.1: 查看待发货订单

**操作**:
1. 管理端切换到 "📦 订单管理" 标签
2. 看到所有 `status='pending'` 的订单

**预期结果**:
- ✅ 看到至少 2 条订单（MANUALTEST001 的）
- ✅ 每条显示 Discord 昵称、奖励类型、积分、状态

---

### 测试 5.2: 标记订单为 shipped

**操作**:
1. 找到 `MANUALTEST001` 的第一条订单（钻石）
2. 点击 "Mark as Shipped" 按钮
3. 确认弹窗

**预期结果**:
- ✅ 订单状态变为 "shipped"
- ✅ 显示 "Shipped!" 按钮（灰色，不可再点）

**验证扣分**:
```sql
-- 检查是否写入负流水
SELECT change, source, reason 
FROM point_logs 
WHERE uid = 'MANUALTEST001' AND change < 0
ORDER BY created_at DESC
LIMIT 1;
```
**预期**: 看到 `-5, redemption, Order #XX`

**检查总余额**:
```sql
SELECT SUM(change) FROM point_logs WHERE uid = 'MANUALTEST001';
```
**预期**: `9 - 5 = 4`

---

### 测试 5.3: 防重复扣分

**操作**:
1. 刷新页面
2. 再次点击同一订单的 "Shipped!" 按钮（已变灰）

**预期结果**:
- ✅ 按钮不可点击，或显示 "Already shipped"

---

### 测试 5.4: 发货第二条订单

**操作**:
1. 标记 `MANUALTEST001` 的第二条订单（谷歌卡）为 shipped

**预期结果**:
- ✅ 扣除 4 分
- ✅ 总余额变为 `0`（4 - 4）

**验证**:
```sql
SELECT SUM(change) FROM point_logs WHERE uid = 'MANUALTEST001';
```
**预期**: `0`

---

### 测试 5.5: CC 持续创作奖测试（如果有）

**CC 口径**：只统计当前期未被拒绝的去重链接；达到 15 条即符合，不要求连续发布 5 天。

**如果你的系统有 CC 奖励自动生成**:

**验证**:
```sql
SELECT * FROM redemption_orders 
WHERE option_name LIKE 'CC:%' AND status = 'pending';
```

**操作**:
1. 标记 CC 订单为 shipped

**预期结果**:
- ✅ 状态变为 shipped
- ✅ 不扣分（`points_spent = 0`）

---

## 🔄 第六阶段：切换结算期（15分钟）

### 测试 6.1: 管理端切换到下个月

**操作**:
1. 管理端顶部选择期号下拉框
2. 选择 `2026-09`（如果没有这个期，先创建）
3. 切换到 "⚙️ 规则配置" 标签
4. 不修改任何规则，直接点击 "💾 保存配置"

**预期结果**:
- ✅ 显示 "✅ Campaign config saved! This period is now active for creators."

**验证**:
```sql
SELECT period, is_current_period FROM campaign_config ORDER BY period DESC;
```
**预期**: 
- `2026-09: true`
- `2026-08: false`（旧的被自动清除）

---

### 测试 6.2: 创作者端自动同步

**操作**:
1. 返回创作者端
2. 刷新页面（Cmd+Shift+R 清除缓存）
3. 重新登录

**预期结果**:
- ✅ "Submit Works" 标签显示 **"Sep 2026 Settlement Period"**
- ✅ 新投稿会写入 `period='2026-09'`

---

### 测试 6.3: 历史投稿翻月查看

**操作**:
1. 切换到 "📋 My Submissions" 标签
2. 看到月份选择器（默认显示 `2026-09`，应该是空的）
3. 点击左箭头，切换到 `2026-08`

**预期结果**:
- ✅ 显示 8 月的历史投稿（2条 work + 1条 showcase）
- ✅ 状态都是 "✅ Scored"

---

## 🔒 第七阶段：安全测试（15分钟）

### 测试 7.1: 尝试越权修改积分

**操作**:
1. 打开浏览器 Console（F12）
2. 粘贴以下代码尝试修改积分:
```javascript
fetch('https://rryzofimrehmkijkckrm.supabase.co/rest/v1/point_logs?uid=eq.MANUALTEST001', {
  method: 'PATCH',
  headers: {
    'apikey': 'sb_publishable_oyewqnQ8AnitAOD94Qg0nA_v6Zqkr7r',
    'Authorization': 'Bearer sb_publishable_oyewqnQ8AnitAOD94Qg0nA_v6Zqkr7r',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ change: 9999 })
}).then(r => r.json()).then(console.log);
```

**预期结果**:
- ✅ 返回空数组 `[]`（没有行被修改）
- ✅ 查询余额，仍然是原值（0）

---

### 测试 7.2: 尝试修改 campaign_config

**操作**:
```javascript
fetch('https://rryzofimrehmkijkckrm.supabase.co/rest/v1/campaign_config?period=eq.2026-09', {
  method: 'PATCH',
  headers: {
    'apikey': 'sb_publishable_oyewqnQ8AnitAOD94Qg0nA_v6Zqkr7r',
    'Authorization': 'Bearer sb_publishable_oyewqnQ8AnitAOD94Qg0nA_v6Zqkr7r',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ is_current_period: false })
}).then(r => r.json()).then(console.log);
```

**预期结果**:
- ✅ 返回空数组 `[]`
- ✅ `is_current_period` 没有被修改

---

## 📱 第八阶段：移动端测试（10分钟）

### 测试 8.1: 手机浏览器测试

**操作**:
1. 用手机（iPhone / Android）打开创作者端
2. 登录
3. 测试投稿、兑换

**预期结果**:
- ✅ 布局不错位
- ✅ 按钮可点击
- ✅ 输入框正常

---

## ✅ 测试完成检查清单

测试完成后，打勾确认：

- [ ] 登录功能正常，期号显示正确
- [ ] 投稿功能正常，2次限额生效
- [ ] Showcase 不占2次名额
- [ ] 管理端可以导入积分，防重复导入
- [ ] 新人奖 +2 自动触发
- [ ] Showcase 审核通过 +1
- [ ] CSV 可以解析并预览，未配置 Token、未点击确认发送
- [ ] 兑换功能正常，余额预留正确
- [ ] 最多选2种奖励限制生效
- [ ] 发货扣分正确，防重复扣分
- [ ] 切换结算期，创作者端自动同步
- [ ] 历史投稿可以翻月查看
- [ ] RLS 安全策略生效，无法越权
- [ ] 移动端布局正常

---

## 🐛 常见问题排查

### 问题1: 期号显示错误
**检查**:
```sql
SELECT period, is_current_period FROM campaign_config WHERE is_current_period = true;
```
**解决**: 确保只有一行为 `true`

---

### 问题2: 兑换后余额不更新
**检查**:
```sql
-- 检查总余额
SELECT SUM(change) FROM point_logs WHERE uid = 'MANUALTEST001';

-- 检查 pending 订单
SELECT SUM(points_spent) FROM redemption_orders WHERE uid = 'MANUALTEST001' AND status = 'pending';
```
**可用余额 = 总余额 - pending 订单**

---

### 问题3: CSV 解析匹配失败
**检查**:
- CSV 格式是否正确（逗号分隔，3列）
- Discord 昵称是否和 `kocs.discord_name` 一致
- UID 是否正确

---

### 问题4: 管理端无法保存配置
**检查**:
- 是否用正确密码登录
- 浏览器 Console 是否有错误
- 尝试硬刷新（Cmd+Shift+R）

---

## 🧹 测试后清理

测试完成后，删除测试数据：

```sql
DELETE FROM point_logs WHERE uid LIKE 'MANUALTEST%';
DELETE FROM submissions WHERE uid LIKE 'MANUALTEST%';
DELETE FROM redemption_orders WHERE uid LIKE 'MANUALTEST%';
DELETE FROM kocs WHERE uid LIKE 'MANUALTEST%';
```

---

## 📋 测试记录表

| 测试项 | 结果 | 备注 | 测试人 | 日期 |
|--------|------|------|--------|------|
| 1.1 登录与期号 | ✅ / ❌ |  |  |  |
| 1.2 投稿（第1次） | ✅ / ❌ |  |  |  |
| 1.3 查看历史 | ✅ / ❌ |  |  |  |
| 1.4 投稿（第2次） | ✅ / ❌ |  |  |  |
| 1.5 2次限额 | ✅ / ❌ |  |  |  |
| 1.6 Showcase | ✅ / ❌ |  |  |  |
| 2.1 管理端登录 | ✅ / ❌ |  |  |  |
| 2.2 查看投稿 | ✅ / ❌ |  |  |  |
| 2.3 算分 JSON | ✅ / ❌ |  |  |  |
| 2.4 导入积分 | ✅ / ❌ |  |  |  |
| 2.5 防重复导入 | ✅ / ❌ |  |  |  |
| 2.6 Showcase 审核 | ✅ / ❌ |  |  |  |
| 3.1 CSV 准备 | ✅ / ❌ |  |  |  |
| 3.2 CSV 解析 | ✅ / ❌ |  |  |  |
| 3.3 CSV 状态清除 | ✅ / ❌ |  |  |  |
| 4.1 查看余额 | ✅ / ❌ |  |  |  |
| 4.2 选择奖励 | ✅ / ❌ |  |  |  |
| 4.3 2种限制 | ✅ / ❌ |  |  |  |
| 4.4 提交兑换 | ✅ / ❌ |  |  |  |
| 4.5 余额预留 | ✅ / ❌ |  |  |  |
| 4.6 兑换开关 | ✅ / ❌ |  |  |  |
| 5.1 查看订单 | ✅ / ❌ |  |  |  |
| 5.2 标记发货 | ✅ / ❌ |  |  |  |
| 5.3 防重复扣分 | ✅ / ❌ |  |  |  |
| 6.1 切换期号 | ✅ / ❌ |  |  |  |
| 6.2 前端同步 | ✅ / ❌ |  |  |  |
| 6.3 历史翻月 | ✅ / ❌ |  |  |  |
| 7.1 积分安全 | ✅ / ❌ |  |  |  |
| 7.2 配置安全 | ✅ / ❌ |  |  |  |
| 8.1 移动端 | ✅ / ❌ |  |  |  |

---

**祝测试顺利！有任何问题随时联系我。** 🚀
