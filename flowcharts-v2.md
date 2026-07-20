# Yoyo KOC Creator Management System — 核心流程图 v2.0

---

## 一、业务主流程图（泳道图）

**覆盖范围**: 新人注册 → 投稿 → 月度结算 → 积分兑换 → 发货全链路
**角色**: 创作者 / Discord 机器人 Mochi / 管理员系统 / AI 算分 Agent

```mermaid
flowchart TD
    %% ===== 泳道定义 =====
    subgraph Creator["🎨 创作者"]
        direction TB
        C1["加入 Discord 社群"]
        C2["收到 Mochi 注册私信"]
        C3["填写注册信息<br>Discord/Account ID/Game UID/地址/电话"]
        C4["登录创作者端"]
        C5["提交作品链接<br>(每月2次机会)"]
        C6["查看积分/等级/进度"]
        C7["兑换奖励<br>钻石/谷歌卡/周边"]
        C8["收到发货通知"]
    end

    subgraph Mochi["🤖 Discord Bot Mochi"]
        direction TB
        M1["检测新人入群"]
        M2["自动私信注册链接"]
        M3["⌛ 每月25号: 催交链接广播"]
        M4["⌛ 次月6号: 算分完成通知"]
        M5["⌛ 等级晋升通知"]
        M6["私信兑换确认"]
    end

    subgraph Admin["🖥️ 管理员系统"]
        direction TB
        A1["KOC信息库<br>创作者台账/等级管理"]
        A2["作品审核<br>算分导入/预览/确认应用"]
        A3["积分计算<br>CC/新人任务/确认发货"]
        A4["Mochi 广播管理"]
        A5["发货管理<br>周边/端内/谷歌卡"]
        A6["KOC数据报告<br>投稿月报/社群周报"]
    end

    subgraph Agent["🤖 AI 算分 Agent"]
        direction TB
        AG1["接收待审核链接列表"]
        AG2["浏览器逐条扫描<br>各平台链接"]
        AG3["获取播放量/浏览量/互动数"]
        AG4["按规则计算积分"]
        AG5["输出算分 JSON"]
    end

    %% ===== 跨泳道流程 =====
    C1 --> M1
    M1 --> M2
    M2 -->|私信| C2
    C2 --> C3
    C3 -->|注册成功| A1
    
    A4 -->|触发 催交广播| M3
    M3 -->|私信| C4
    C4 --> C5
    C5 -->|提交数据| A2
    
    A2 -->|导出待审核 JSON| AG1
    AG1 --> AG2 --> AG3 --> AG4 --> AG5
    AG5 -->|导入算分结果| A2
    
    A2 -->|确认应用积分| A1
    A2 -->|确认应用积分| A3
    
    A3 -->|检测 CC/新人奖励| A1
    A4 -->|触发 算分完成广播| M4
    M4 -->|私信| C6
    
    C6 --> C7
    C7 -->|兑换请求| A3
    A3 -->|审核确认| A5
    A5 -->|发货| C8
    A4 -->|触发 晋升通知| M5
    M5 -->|私信| C6
    A5 --> M6
    M6 -->|私信确认| C8

    %% ===== 样式 =====
    classDef creator fill:#e8f5e9,stroke:#43a047,stroke-width:2px,color:#1b5e20
    classDef mochi fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    classDef admin fill:#fce4ec,stroke:#d81b60,stroke-width:2px,color:#880e4f
    classDef agent fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c
    class C1,C2,C3,C4,C5,C6,C7,C8 creator
    class M1,M2,M3,M4,M5,M6 mochi
    class A1,A2,A3,A4,A5,A6 admin
    class AG1,AG2,AG3,AG4,AG5 agent
```

---

## 二、页面操作流程图（用户操作路径）

### 2.1 创作者端操作路径

```mermaid
flowchart TD
    %% ===== 登录 → 核心操作 =====
    START(["🌐 打开创作者端"]) --> LOGIN{"已有账号?"}
    LOGIN -->|"🆕 我是新创作者"| REG["填写注册信息<br>Discord / Account ID / Game UID<br>姓名 / 服务器 / 地址 / 电话"]
    LOGIN -->|"✅ 我已注册"| AUTH["输入 Discord + UID 验证"]
    REG --> AUTH
    AUTH --> DASH["🎯 Dashboard 主页<br>5 个功能 Tab"]
    
    %% ===== Submit Works =====
    DASH --> TAB1["📝 Submit Works"]
    TAB1 --> CHECK{"剩余提交次数?"}
    CHECK -->|"≥1 次"| FORM["填写提交表单<br>统一链接框 (图片/视频混投)<br>反馈 (选填)"]
    CHECK -->|"0 次"| LOCKED["🔒 已用完机会<br>表单变灰 + 提示联系管理员"]
    FORM --> SUBMIT["✅ 提交成功<br>显示第 X/2 次"]
    SUBMIT --> TAB1
    
    %% ===== My Submissions =====
    DASH --> TAB2["📋 My Submissions"]
    TAB2 --> STATS["📊 本月统计数据<br>已提交 X 条 · 已评分/待审核"]
    STATS --> CC{"检测到连续创作?"}
    CC -->|"≥15条"| CC_DONE["🎁 CC达标提醒<br>月卡×1+蜗壳币×500+金币×1000"]
    CC -->|"&lt;15条"| CC_PROGRESS["📊 进度条: X/15<br>再投 N 条可获 CC 奖励"]
    STATS --> TIER{"检测到等级?"}
    TIER -->|"认证创作官"| UPGRADE["📈 升级提示<br>连续2个月≥5分 → 金级"]
    TIER -->|"金级创作官"| UPGRADE2["📈 升级提示<br>连续3个月≥5分 → 铂金"]
    TIER -->|"铂金创作官"| TOP["🏆 已达最高等级"]
    STATS --> HISTORY["📅 历史月度记录<br>2026年7月起"]
    
    %% ===== Redeem Rewards =====
    DASH --> TAB3["🎁 Redeem Rewards"]
    TAB3 --> REDEEM_CHECK{"管理员开放兑换?"}
    REDEEM_CHECK -->|"🔒 未开放"| LOCKED_TAB["🔒 暂不开放兑换<br>请等待结算通知"]
    REDEEM_CHECK -->|"✅ 开放"| REWARDS["🛒 选择奖励"]
    REWARDS --> DIAMOND["💎 钻石兑换<br>450钻石/份 × N"]
    REWARDS --> GPLAY["🎮 谷歌卡"]
    REWARDS --> MERCH["📦 周边"]
    DIAMOND --> CONFIRM["✅ 确认兑换"]
    GPLAY --> CONFIRM
    MERCH --> CONFIRM
    CONFIRM --> DONE["🎉 兑换成功<br>等待管理员发货"]
    
    %% ===== FAQ =====
    DASH --> TAB4["❓ FAQ"]
    TAB4 --> SEARCH["🔍 搜索问题"]
    TAB4 --> CATEGORIES["📂 分类浏览<br>积分/兑换/等级/规则"]
    TAB4 --> POST["📝 Post in Discord<br>#town-service-station"]

    %% ===== 样式 =====
    classDef start fill:#fce4ec,stroke:#d81b60,color:#880e4f
    classDef action fill:#fff5f9,stroke:#f2a6c4,color:#3d2b36
    classDef decision fill:#fef6f9,stroke:#e8a0b5,color:#3d2b36
    classDef done fill:#e8f5e9,stroke:#43a047,color:#1b5e20
    classDef locked fill:#f5f5f5,stroke:#999,color:#666
    class START start
    class REG,AUTH,DASH,FORM,STATS,REWARDS,DIAMOND,GPLAY,MERCH action
    class LOGIN,CHECK,CC,TIER,REDEEM_CHECK decision
    class SUBMIT,CC_DONE,DONE,TOP done
    class LOCKED,LOCKED_TAB locked
```

### 2.2 管理后台操作路径

```mermaid
flowchart TD
    %% ===== 登录 =====
    ADMIN["🔐 管理员登录<br>密码: yoyo2026"] --> PANEL["🎀 管理后台<br>10 个功能 Tab"]
    
    %% ===== 月度结算主操作路径 =====
    PANEL --> MONTH["📅 选择结算月份<br>全局影响所有模块"]
    
    %% ---- 第一步: 作品审核 ----
    MONTH --> SUB["📋 作品审核"]
    SUB --> EXPORT["📥 导出待审核 JSON"]
    EXPORT --> COPY["📋 复制 Agent 提示词"]
    COPY --> AGENT["📤 发给 Codex Agent<br>浏览器扫描链接算分"]
    AGENT --> IMPORT["📥 导入算分结果<br>粘贴 JSON / 上传文件"]
    IMPORT --> PREVIEW["👁️ 预览<br>自动合并同 UID"]
    PREVIEW --> CONFIRM["✅ 确认应用积分"]
    
    CONFIRM --> AUTO{"系统自动处理"}
    AUTO --> MARK["① 标记 submissions → scored"]
    AUTO --> POINTS["② 写入 point_logs<br>积分到账创作者前端"]
    AUTO --> CC["③ 检测 CC 达标<br>(≥15条 → 自动打开开关)"]
    AUTO --> NEWBIE["④ 检测新人任务<br>(满5分 → +2 bonus)"]
    
    %% ---- 第二步: 积分计算 ----
    POINTS --> SCORE["🧮 积分计算"]
    SCORE --> SCORE_TABLE["📊 当月积分表"]
    SCORE_TABLE --> CC_SWITCH["CC 开关 (自动/手动)"]
    SCORE_TABLE --> NEWBIE_SWITCH["新人任务开关 (自动/手动)"]
    SCORE_TABLE --> MANUAL["🖊️ 手动加减积分<br>+/- 框 + 备注"]
    SCORE_TABLE --> REDEEM_CHECK2["认可兑换 / 确认发货"]
    
    %% ---- 第三步: 发货管理 ----
    REDEEM_CHECK2 --> SHIP["📦 周边/端内/谷歌卡"]
    SHIP --> SHIP_PENDING["待发货列表"]
    SHIP_PENDING --> SHIP_DONE["✅ 标记已发货"]
    
    %% ---- 第四步: 广播 ----
    CONFIRM --> BROADCAST["📢 Mochi 广播"]
    BROADCAST --> B1["🆕 ① 新人欢迎"]
    BROADCAST --> B2["📥 ② 催交链接"]
    BROADCAST --> B3["✅ ③ 算分完成"]
    BROADCAST --> B4["⭐ ④ 等级变动"]
    B1 --> B_PREVIEW["👁️ 预览收件人列表"]
    B2 --> B_PREVIEW
    B3 --> B_PREVIEW
    B4 --> B_PREVIEW
    B_PREVIEW --> B_SEND["📤 确认发送"]
    
    %% ---- 其他操作 ----
    PANEL --> KOC["📋 KOC信息库"]
    KOC --> KOC_LIST["创作者台账<br>等级管理/筛选/搜索"]
    KOC_LIST --> KOC_EDIT["🖊️ 双击编辑<br>等级/积分/状态"]
    KOC_LIST --> KOC_BATCH["批量操作<br>标记新/老创作者<br>全选/删除"]
    
    PANEL --> RULES["📐 规则配置"]
    RULES --> RULES_EDIT["编辑阈值<br>CC 条数/等级标准/兑换比例"]
    
    PANEL --> REPORT["📊 KOC数据报告"]
    REPORT --> MONTHLY_REPORT["KOC投稿月报<br>6 个 KPI + 6 个图表 + 洞察"]
    REPORT --> WEEKLY_REPORT["社群运营周报<br>(跳转外部链接)"]
    
    PANEL --> AUDIT_LOG["📜 操作日志"]
    AUDIT_LOG --> LOG_LIST["查看所有操作记录"]

    %% ===== 样式 =====
    classDef adminPanel fill:#fce4ec,stroke:#d81b60,color:#880e4f
    classDef action fill:#fff5f9,stroke:#f2a6c4,color:#3d2b36
    classDef decision fill:#fef6f9,stroke:#e8a0b5,color:#3d2b36
    classDef done fill:#e8f5e9,stroke:#43a047,color:#1b5e20
    class ADMIN,PANEL adminPanel
    class MONTH,SUB,EXPORT,COPY,AGENT,IMPORT,PREVIEW,CONFIRM,SCORE,SHIP,BROADCAST,KOC,RULES,REPORT action
    class AUTO,B1,B2,B3,B4 decision
    class MARK,POINTS,CC,NEWBIE,B_SEND,SHIP_DONE done
```

---

## 三、异常分支流程图

### 3.1 投稿数据抓取失败

```mermaid
flowchart TD
    START["🤖 Agent 开始扫描链接"] --> TRY["打开链接"]
    TRY --> RESULT{"页面可访问?"}
    
    RESULT -->|"✅ 正常加载"| PARSE["解析互动数/播放量"]
    RESULT -->|"❌ 链接失效/404"| LOG1["记录: 不可访问"]
    RESULT -->|"❌ 平台封禁/需要登录"| LOG2["记录: 平台限制"]
    RESULT -->|"❌ 页面加载超时"| LOG3["记录: 超时"]
    
    LOG1 --> RETRY{"重试次数<br>&lt;3?"}
    LOG2 --> RETRY
    LOG3 --> RETRY
    
    RETRY -->|"是"| TRY
    RETRY -->|"否"| FAILED["标记为抓取失败"]
    
    FAILED --> REVIEW["管理员审核:<br>手动补充积分"]
    PARSE --> DONE["写入算分 JSON"]
    
    FAILED --> JSON["写入算分 JSON<br>score: 0 · error: true"]

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef retry fill:#fff3e0,stroke:#f57c00
    class START,PARSE,DONE normal
    class LOG1,LOG2,LOG3,FAILED error
    class RETRY,REVIEW retry
```

### 3.2 积分计算异常

```mermaid
flowchart TD
    START["确认应用积分"] --> CHECK{"检查异常条件"}
    
    CHECK -->|"该 UID 当月已有积分"| DUPLICATE{"重复提交?"}
    CHECK -->|"积分格式异常/负数"| SKIP["跳过该条<br>记录到异常列表"]
    CHECK -->|"UID 在 KOC 库不存在"| UNKNOWN["自动创建 KOC 记录<br>标记: 系统自动注册"]
    
    DUPLICATE -->|"是 (已 scored)"| DUP_SKIP["跳过写入<br>记录日志: 重复积分"]
    DUPLICATE -->|"否 (正常追加)"| WRITE["写入 point_logs"]
    
    WRITE --> CC_CHECK{"CC 条件<br>当月提交≥15条?"}
    CC_CHECK -->|"是"| CC_AUTO["自动打开 CC 开关"]
    CC_CHECK -->|"否"| NEWBIE_CHECK{"新人月 + ≥5分?"}
    
    CC_AUTO --> NEWBIE_CHECK
    
    NEWBIE_CHECK -->|"是"| NEWBIE_BONUS["自动 +2 分<br>标记 newbie_bonus"]
    NEWBIE_CHECK -->|"否"| DONE["✅ 完成"]
    
    SKIP --> ADMIN_ALERT["🔔 管理员通知<br>检查异常数据"]
    UNKNOWN --> ADMIN_ALERT

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef warn fill:#fff3e0,stroke:#f57c00
    class START,WRITE,CC_AUTO,NEWBIE_BONUS,DONE normal
    class SKIP,UNKNOWN error
    class DUPLICATE,DUP_SKIP,ADMIN_ALERT warn
```

### 3.3 重复投稿

```mermaid
flowchart TD
    START["创作者提交链接"] --> CHECK_LIMIT{"剩余次数 > 0?"}
    
    CHECK_LIMIT -->|"❌ 0 次"| REJECT["拒绝提交<br>提示: 已用完 2 次机会<br>请联系管理员"]
    CHECK_LIMIT -->|"✅ ≥1 次"| CHECK_LINKS["检测链接内容"]
    
    CHECK_LINKS --> CHECK_DUP{"与历史提交<br>存在完全相同的 URL?"}
    
    CHECK_DUP -->|"是"| DUP_ALERT["提示: 该链接已提交过<br>请检查后重试"]
    CHECK_DUP -->|"否"| CHECK_BLANK{"链接框为空?"}
    
    CHECK_BLANK -->|"是"| EMPTY_ALERT["提示: 请粘贴作品链接"]
    CHECK_BLANK -->|"否"| SAVE["✅ 保存提交<br>写入 submissions 表"]
    
    DUP_ALERT --> START
    EMPTY_ALERT --> START
    
    SAVE --> DEDUCT["扣除 1 次提交机会"]
    DEDUCT -> DONE["显示成功状态"]

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef warn fill:#fff3e0,stroke:#f57c00
    class START,SAVE,DEDUCT,DONE normal
    class REJECT error
    class CHECK_DUP,DUP_ALERT,CHECK_BLANK,EMPTY_ALERT warn
```

### 3.4 兑换库存不足 / 余额不足

```mermaid
flowchart TD
    START["创作者发起兑换请求"] --> CHECK_BALANCE{"账户余额 ≥ 所需积分?"}
    
    CHECK_BALANCE -->|"❌ 余额不足"| BALANCE_FAIL["❌ 兑换失败<br>提示: 积分不足<br>当前 X 分 · 需要 Y 分"]
    CHECK_BALANCE -->|"✅ 余额充足"| CHECK_STOCK{"库存检查"}
    
    CHECK_STOCK -->|"端内奖励"| GAME_STOCK{"钻石/道具<br>库存充足?"}
    CHECK_STOCK -->|"谷歌卡"| GC_STOCK{"谷歌卡<br>库存充足?"}
    CHECK_STOCK -->|"周边"| MERCH_STOCK{"周边<br>库存充足?"}
    
    GAME_STOCK -->|"❌ 不足"| STOCK_FAIL["❌ 兑换失败<br>提示: 该奖励库存不足<br>请联系管理员补货"]
    GC_STOCK -->|"❌ 不足"| STOCK_FAIL
    MERCH_STOCK -->|"❌ 不足"| STOCK_FAIL
    
    GAME_STOCK -->|"✅ 充足"| DEDUCT_POINTS["扣除积分<br>创建兑换订单"]
    GC_STOCK -->|"✅ 充足"| DEDUCT_POINTS
    MERCH_STOCK -->|"✅ 充足"| DEDUCT_POINTS
    
    DEDUCT_POINTS --> NOTIFY_ADMIN["📢 通知管理员<br>有新兑换待处理"]
    NOTIFY_ADMIN --> DONE["✅ 兑换成功<br>等待发货"]
    
    STOCK_FAIL --> ADMIN_ALERT["📢 通知管理员<br>库存不足需补货"]

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef warn fill:#fff3e0,stroke:#f57c00
    class START,DEDUCT_POINTS,DONE normal
    class BALANCE_FAIL,STOCK_FAIL error
    class CHECK_BALANCE,CHECK_STOCK,GAME_STOCK,GC_STOCK,MERCH_STOCK warn
```

### 3.5 新人奖励不达标

```mermaid
flowchart TD
    START["积分结算 → 新人月检测"] --> CHECK_NEWBIE{"KOC 状态<br>= 新创作者?"}
    
    CHECK_NEWBIE -->|"❌ 非新人"| SKIP["跳过新人奖励"]
    CHECK_NEWBIE -->|"✅ 新人月"| CHECK_SCORE{"当月积分 ≥ 5 分?"}
    
    CHECK_SCORE -->|"✅ ≥5分"| BONUS_ENABLED{"新人任务开关<br>是否已打开?"}
    CHECK_SCORE -->|"❌ &lt;5分"| NOT_YET["未达标<br>提示: 再投 X 分即可<br>获得 +2 bonus"]
    
    BONUS_ENABLED -->|"✅ 已打开"| VERIFY_BONUS{"确认 +2 分<br>是否已写入?"}
    BONUS_ENABLED -->|"❌ 未打开"| AUTO_ENABLE["自动打开开关<br>管理员可手动确认"]
    
    VERIFY_BONUS -->|"已写入"| DONE["✅ 新人任务完成"]
    VERIFY_BONUS -->|"未写入"| WRITE_BONUS["写入 +2 bonus<br>到 point_logs"]
    
    AUTO_ENABLE --> ADMIN_CHECK["👨‍💼 管理员审核:<br>手动确认 +2 分"]
    ADMIN_CHECK -->|"确认"| WRITE_BONUS
    
    NOT_YET --> REMIND["📢 系统记录:<br>该新人未达标<br>下月重新计算"]

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef warn fill:#fff3e0,stroke:#f57c00
    class START,BONUS_ENABLED,AUTO_ENABLE,WRITE_BONUS,DONE normal
    class NOT_YET,REMIND warn
    class CHECK_NEWBIE,CHECK_SCORE,VERIFY_BONUS decision
```

### 3.6 算分导入数据格式异常

```mermaid
flowchart TD
    START["管理员导入算分 JSON"] --> PARSE{"JSON 格式正确?"}
    
    PARSE -->|"❌ 格式错误"| FORMAT_ERROR["提示: JSON 格式无效<br>检查是否包含多余字符"]
    PARSE -->|"✅ 格式正确"| VALIDATE{"字段完整性校验"}
    
    VALIDATE -->|"缺少必填字段<br>(uid/score)"| FIELD_ERROR["提示: 缺少必要字段<br>显示具体字段名"]
    VALIDATE -->|"✅ 字段完整"| UID_CHECK{"UID 匹配检验"}
    
    UID_CHECK -->|"部分 UID<br>在 KOC 库不存在"| MISSING_UID["标记: 未知 UID<br>创建临时 KOC 记录"]
    UID_CHECK -->|"✅ 全部匹配"| MERGE["合并同 UID<br>累加积分"]
    
    MISSING_UID --> ADMIN_REVIEW["管理员审核<br>补充 KOC 信息"]
    ADMIN_REVIEW --> MERGE
    
    MERGE --> PREVIEW["显示预览:<br>✓ 正常记录 X 条<br>⚠️ 异常记录 Y 条"]
    PREVIEW --> CONFIRM["确认应用积分"]

    classDef normal fill:#e8f5e9,stroke:#43a047
    classDef error fill:#fce4ec,stroke:#e53935
    classDef warn fill:#fff3e0,stroke:#f57c00
    class START,MERGE,PREVIEW,CONFIRM normal
    class FORMAT_ERROR,FIELD_ERROR error
    class UID_CHECK,MISSING_UID,ADMIN_REVIEW warn
```

---

*文档版本: v2.0 | 日期: 2026-07-20*
