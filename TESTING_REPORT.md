# Yoyo KOC System 上线前 E2E 测试报告

**测试日期**：2026-08-27
**测试代码**：`1463f9e` + 本次修复
**测试账号**：首次全流程 `E2ETESTAUG27`；针对性复测 `E2ERETESTAUG27`
**MochiBot**：未测试、未触发；服务端 `send_dm` 仍处于紧急停用状态。

## 1. 最终结论

**结论：核心数据闭环通过；首次测试发现的 3 个 P1 问题均已修复并完成针对性复测。**

通过的核心流程：
- 注册申请、19 位 System ID 校验和重复申请拦截。
- 管理员批准、批准后登录、单份欢迎周边、新人月计算。
- 当前结算期 `2026-08` 同步。
- 两次投稿限制、15 条 CC、刷新持久化、后台数据可读取。
- Showcase 不占两次常规投稿机会。
- 被拒绝投稿不计入有效投稿和 CC。
- 作品基础分 `6 + 12 = 18`。
- 奖励分 `2 + 1 + 3 = 6`，当月总到账 `24`。
- My Submissions 四张摘要卡真实页面显示正确。
- 等级只看基础分、连续两/三月升级、只升不降公式。
- pending 兑换预留积分、超额兑换阻止、取消释放预留。
- 发货时才扣分、重复发货不重复扣分。
- 0 分欢迎周边发货不扣积分。
- 测试数据完整清理，生产配置恢复。

## 2. 已修复问题

### P1-01：YouTube `watch?v=` 链接被错误去重 — 已修复

**复现**：一次输入 5 个不同的链接：

```text
https://youtube.com/watch?v=e2e202608271
https://youtube.com/watch?v=e2e202608272
...
```

**实际结果**：系统提示移除了 4 个重复链接，只保留 1 个。

**原因**：`normalizeLinkKey()` 使用 `.replace(/[#?].*$/, '')`，把 YouTube 的 `?v=视频ID` 整段删除，导致所有 `youtube.com/watch` 链接拥有相同去重键。

**影响**：创作者一次提交多个普通 YouTube 视频时会丢失链接，CC 链接数也会被少算。

**修复与复测**：前后台统一保留 `v` 等内容标识参数，只移除 `utm_*`、`si`、`fbclid` 等追踪参数及锚点。不同 `watch?v=` 链接不再合并；相同视频附带分享参数仍会正确去重。

### P1-02：兑换 RPC 没有请求幂等键 — 已修复

**复现**：对同一测试账号并发发送两次完全相同的 1 分钻石兑换请求。

**实际结果**：两次请求均返回 200，并创建两张 pending 订单。

**已确认**：数据库 advisory lock 能防止超额兑换，但不能判断两次请求是不是同一次点击/重试。

**影响**：前端按钮通常会禁用，但网络重试、双设备或两个并发请求仍可能产生重复订单并重复预留积分。

**修复与复测**：前端每次兑换生成 `request_id`；数据库已上线唯一索引、按 UID 串行锁和幂等返回。对同一请求编号并发调用两次，两次均安全返回 200，其中一次 `idempotent=false`、一次 `idempotent=true`，数据库最终仅有 1 张订单。

### P1-03：兑换标签不会主动刷新可用积分 — 已修复

**复现**：用户保持登录状态，后台新增积分并产生订单后，直接切换到 Redeem Rewards。

**实际结果**：数据库流水余额为 19，pending 预留为 2，可用应为 17；页面仍显示旧会话的 `0 Available Points`，奖励按钮全部禁用。

**原因**：`switchCreatorTab('redeem')` 只调用 `renderOptions()` 和 `loadOrders()`，没有重新执行 `getBalance()` 和 `getPendingRedemptionTotal()`。

**影响**：用户在结算期间已经打开页面时，收到积分后不刷新/不重新登录会看到旧余额，误以为积分未到账。

**修复与复测**：新增统一的 `refreshAvailableBalance()`，登录仪表盘、切换兑换标签和兑换成功后都会重新查询流水余额及 pending 预留。页面保持登录期间，数据库可用余额从 19 变为 17，切换到 Redeem Rewards 后页面立即显示 17，无需刷新或重新登录。

### 数据库迁移与清理

- 已执行 `supabase/migrations/20260827103000_add_redemption_request_id.sql`。
- REST 已确认 `redemption_orders.request_id` 可查询，5 参数 `redeem_points` 可调用。
- 针对性复测 UID `E2ERETESTAUG27` 已精确清理；`redemption_orders`、`point_logs`、`submissions`、`kocs` 最终计数均为 0。

## 3. 详细测试结果

### 注册与审核：通过

| 项目 | 结果 |
|---|---|
| 18 位 System ID | HTTP 400，阻止 |
| 20 位 System ID | HTTP 400，阻止 |
| 19 位 System ID | 注册成功 |
| 重复申请 | 返回 duplicate，不新增记录 |
| 批准前登录 | `kocs` 无记录，无法登录 |
| 管理员批准 | 创建 1 个 KOC |
| 欢迎周边 | 创建 1 张 0 分 pending 订单 |
| 新人月 | 正确写为 `2026-09` |
| 重复批准 | HTTP 409，未重复创建 |
| Discord DM | 未发送 |

### 月份和窗口：部分通过

- 当前唯一月份：`2026-08`。
- 创作者页面正确显示 `AUGUST 2026`。
- My Submissions 只显示当前期，没有提供未来月份。
- 开关和截止时间公式测试通过。
- 为避免影响正在使用系统的正式创作者，没有在线全局关闭投稿或兑换。

### 投稿、CC 和 Showcase：通过

- 第一次提交 10 条 TikTok 链接成功，显示 `1/2`。
- 第二条有效投稿后共有 15 条链接。
- 第三次投稿按钮显示 `Used Up` 并锁定。
- My Submissions 刷新后仍显示两条记录和 15 条链接。
- CC 在 15 条时显示 `15 / 15`。
- 拒绝一条投稿后，有效常规投稿数变为 1，CC 链接数降为 5。
- Showcase 独立存在，不占常规投稿次数。

### 算分与 My Submissions：通过

真实页面确认：

| 卡片 | 期望 | 实际 |
|---|---:|---:|
| Base Content Score | 18 | 18 |
| Bonus Points | 6 | 6 |
| Total Added This Month | 24 | 24 |
| Valid Work Links | 15 | 15 |

明细卡正确显示：
- 常规投稿 `+6`。
- 常规投稿 `+12`。
- Showcase Bonus `+1`。
- 三条记录均显示 `Scored`。

### 等级：公式通过

- 单月 ≥5：仍为 Certified。
- 连续 2 月 ≥5：Gold。
- 连续 3 月 ≥5：Platinum。
- 基础分 4、奖励后总分超过 5：不计为合格月份。
- Gold / Platinum 后续低分：不降级。
- 同月重复历史：按月份归一，不重复计数。

没有点击全库“一键自动升级”，避免修改正式 KOC 的等级历史。

### 积分、兑换和发货：通过

- 流水余额 24，创建 2 分 pending 订单后流水仍为 24，可用为 22。
- 请求 30 分兑换时 RPC 返回 HTTP 400：积分不足。
- 取消 2 分订单后可用积分恢复 24。
- 创建 5 分周边订单后可用积分为 19。
- 发货后只写入一条 `-5` redemption 流水，余额变为 19。
- 重复发货检查只找到一条对应扣分。
- 0 分欢迎周边发货前后 point_logs 行数无变化。
- My Orders 能显示 shipped、pending、cancelled 状态。

### 持久化和 UI：部分通过

- 页面切换、数据库重新拉取后，投稿和摘要数字保持一致。
- 桌面端核心页面可操作，无明显遮挡。
- 创作者端本轮查看的登录、投稿、My Submissions、兑换和订单文案均为英文。
- 未完成独立 Android/iPhone 真机测试；移动端主要依赖现有 CSS 断点检查，不能替代真机签字。

## 4. 测试清理确认

测试结束后按 UID 精确清理，最终结果：

| 表 | 测试数据剩余 |
|---|---:|
| `registration_applications` | 0 |
| `kocs` | 0 |
| `submissions` | 0 |
| `point_logs` | 0 |
| `redemption_orders` | 0 |
| `score_imports` | 0 |

生产配置恢复为：

```text
period = 2026-08
is_current_period = true
submissions_open = true
redemption_open = true
submissions_close_at = null
redemption_close_at = null
```

## 5. 上线建议

首次测试发现的三项问题已经修复并通过针对性复测。

**当前签字：核心流程达到上线条件。仍建议上线初期监控真实移动设备反馈；MochiBot 广播继续保持禁用，待单独安全测试后再启用。**
