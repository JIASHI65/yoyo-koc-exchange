# Yoyo KOC Exchange — 核心流程图

---

## 1. 创作者端架构

```mermaid
flowchart TD
    A(["👤 用户进入网站"]) --> B{选择入口}
    B -->|"🆕 新创作者"| C["注册表单<br>Discord / Account ID / Game UID<br>姓名 / 服务器 / 地址 / 电话"]
    B -->|"✅ 已注册"| D["登录: Discord + UID"]
    C --> E["生成 UID<br>存入 KOC 信息库"]
    E --> F["进入 Dashboard"]
    D --> F
    
    F --> G["🎨 Submit Works<br>提交作品链接"]
    F --> H["📋 My Submissions<br>查看提交记录"]
    F --> I["🎁 Redeem Rewards<br>兑换奖励"]
    F --> J["❓ FAQ"]
    
    G --> K{"还剩几次提交?"}
    K -->|"第 1 次"| L["提交成功 ✅<br>还剩 1 次"]
    K -->|"第 2 次"| M["提交成功 ✅<br>表单锁定变灰 🔒"]
    
    H --> N["显示: 已提交 X 条"]
    N --> O{"投稿 > 15 条?"}
    O -->|"是"| P["提醒: 再冲一下 40 分可全额结算"]
    O -->|"否"| Q["显示 CC 进度: X/15"]
    
    I --> R{"管理员开放兑换?"}
    R -->|"否"| S["🔒 暂不开放兑换<br>请等待通知"]
    R -->|"是"| T["显示可选奖励<br>💎钻石 / 🎮谷歌卡 / 📦周边"]
    T --> U{"积分 >= 选项要求?"}
    U -->|"是"| V["可选择 + 确认兑换"]
    U -->|"否"| W["显示灰色不可选"]
```

---

## 2. 月度结算核心流程 (完整闭环)

```mermaid
flowchart LR
    S1["📆 月底<br>管理员点广播"] --> S2["Mochi 通知所有人<br>请在 5 号前提交链接"]
    S2 --> S3["📥 创作者提交链接"]
    S3 --> S4["⛔ 次月 5 号<br>截止提交"]
    
    S4 --> S5["👨‍💼 管理员操作"]
    S5 --> S6["📥 导出待审核 JSON"]
    S5 --> S7["📋 复制 Agent 提示词"]
    
    S6 --> S8["🤖 Codex Agent<br>浏览器扫描每条链接<br>获取互动数 / views"]
    S7 --> S8
    
    S8 --> S9["📤 Agent 输出<br>算分 JSON"]
    S9 --> S10["👨‍💼 管理员导入"]
    S10 --> S11["📊 预览<br>自动合并同 UID"]
    S11 --> S12["✅ 确认应用积分"]
    
    S12 --> S13["系统自动执行:"]
    S13 --> S14["① 标记 scored"]
    S13 --> S15["② 写入 point_logs<br>积分到账创作者端"]
    S13 --> S16["③ 检测 CC<br>(15+ 条自动创建订单)"]
    S13 --> S17["④ 检测新人月<br>(满5分 +2 bonus)"]
    
    S15 --> S18["📢 管理员广播<br>算分完成通知"]
    S18 --> S19["👤 创作者登录查看积分"]
    S19 --> S20["🎁 兑换奖励"]
    S20 --> S21["📦 管理员处理发货"]
```

---

## 3. 算分导入模块 (作品审核页) 详细流程

```mermaid
flowchart TD
    A(["作品审核 Tab"]) --> B["导入区域"]
    
    B --> C{"选择导入方式"}
    C -->|"粘贴 JSON"| D["粘贴到文本框"]
    C -->|"上传文件"| E["选择 .json / .txt"]
    
    D --> F["📥 点击预览"]
    E --> F
    
    F --> G{"解析成功?"}
    G -->|"❌ 格式无效"| H["显示错误提示"]
    G -->|"✅ 解析成功"| I["自动合并同 UID"]
    
    I --> J["显示预览区:"]
    J --> K["📊 统计: 总提交数 / 总积分"]
    J --> L["📋 明细: 合并后每人积分"]
    
    K --> M["确认应用积分按钮"]
    L --> M
    
    M --> N["标记 submissions → scored"]
    N --> O["自动写入 point_logs"]
    O --> P{"检测 CC?"}
    P -->|"该 UID 当月总提交 ≥ 15 条"| Q["创建端内奖励订单<br>月卡×1 + 蜗壳币×500 + 金币×1000"]
    P -->|"否"| R{"检测新人 bonus?"}
    
    Q --> R
    R -->|"新人月 + 积分 ≥ 5"| S["+2 bonus<br>标记 newbie_bonus"]
    R -->|"否"| T["跳过"]
    
    S --> U["✅ 刷新全部板块"]
    T --> U
    
    U --> V["创作者端积分自动更新 ✓"]
```

---

## 4. KOC 信息库 & 等级体系

```mermaid
flowchart LR
    subgraph KOC信息库
        K1["Discord 昵称"]
        K2["UID (YOYO-xxx)"]
        K3["⭐ 等级"]
        K4["Name"]
        K5["Region"]
        K6["Account ID"]
        K7["Server"]
        K8["Address"]
    end
    
    K3 --> L{"等级下拉选择"}
    L -->|"默认"| C["✅ 认证创作官"]
    L -->|"连续2个月≥5分"| G["🟡 金级创作官"]
    L -->|"连续3个月≥5分"| P["💎 铂金创作官"]
    
    subgraph 数据联动
        D1["📦 周边发货<br>← 提取 Name / Address"]
        D2["💎 端内奖励<br>← 提取 UID / Account ID / Server"]
        D3["🎮 谷歌卡<br>← 提取 UID / Account ID / Server"]
    end
    
    KOC信息库 --> D1
    KOC信息库 --> D2
    KOC信息库 --> D3
    
    subgraph 标记
        T1["🆕 新人月<br>newbie_month:YYYY-MM"]
        T2["👴 老创作者<br>old_creator:true"]
        T3["🎁 连续创作<br>CC:YYYY-MM"]
        T4["➕ 新人bonus<br>newbie_bonus:YYYY-MM"]
    end
    
    KOC信息库 --> T1
    KOC信息库 --> T2
    KOC信息库 --> T3
    KOC信息库 --> T4
```

---

## 5. 管理员 Tab 导航

```mermaid
flowchart TD
    A["🎀 Admin Panel"] --> A1["📅 结算月份选择器 (全局)"]
    
    A --> T1["📋 KOC信息库"]
    A --> T2["🧮 积分计算"]
    A --> T3["📋 作品审核"]
    A --> T4["📦 周边发货"]
    A --> T5["💎 端内奖励"]
    A --> T6["🎮 谷歌卡"]
    A --> T7["📐 规则配置"]
    
    T1 --> T1A["台账表格 + 双击编辑"]
    T1 --> T1B["等级下拉选择"]
    T1 --> T1C["搜索 / 添加 KOC"]
    T1 --> T1D["批量标记老创作者"]
    
    T2 --> T2A["月度积分表"]
    T2 --> T2B["CC 开关"]
    T2 --> T2C["Pending 操作"]
    T2 --> T2D["关闭兑换按钮"]
    
    T3 --> T3A["提交表格 + 过滤"]
    T3 --> T3B["导出 / 复制提示词"]
    T3 --> T3C["🤖 算分结果导入"]
    T3C --> T3C1["粘贴 / 上传"]
    T3C1 --> T3C2["预览 + 合并"]
    T3C2 --> T3C3["✅ 确认应用积分"]
    
    T4 --> T4A["月分组订单"]
    T4 --> T4B["双击编辑 + 发货"]
    
    T5 --> T5A["月分组订单"]
    T5 --> T5B["CC 自动显示"]
    
    T6 --> T6A["月分组订单"]
    T6 --> T6B["双击编辑"]
    
    T7 --> T7A["TikTok / YouTube / 社交"]
    T7 --> T7B["编辑阈值数值"]
    T7 --> T7C["同步到 Agent 模板"]
```

---

## 6. Mochi 广播流程

```mermaid
flowchart TD
    A(["Mochi 广播"]) --> B["4 个阶段"]
    
    B --> S1["① 🆕 新人欢迎"]
    B --> S2["② 📬 月底收链接提醒"]
    B --> S3["③ ✅ 算分完成通知"]
    B --> S4["④ ⭐ 等级变动通知"]
    
    S1 --> C["触发: 检测到新人入群"]
    C --> D["自动私信:"]
    D --> D1["欢迎成为认证创作者 🎉"]
    D --> D2["下个月是你的新人活动月"]
    D --> D3["新人月投稿满5分 → +2 bonus"]
    D --> D4["请完成注册: 点击链接填写信息"]
    
    S2 --> E["触发: 管理员点一键广播"]
    E --> F["私信所有人:"]
    F --> F1["📢 收集作品链接已开启"]
    F --> F2["请在 5 号前提交所有链接"]
    F --> F3["点击链接去投稿"]
    
    S3 --> G["触发: 管理员导入算分完成"]
    G --> H["私信所有投稿者:"]
    H --> H1["✅ 积分已结算完毕"]
    H --> H2["请登录查看积分并兑换奖励"]
    
    S4 --> I["触发: 管理员手动改等级后"]
    I --> J["私信升级者:"]
    J --> J1["🎉 恭喜升级为 金级/铂金 创作官!"]
    
    subgraph 确认机制
        K["📱 管理员点广播"]
        K --> L["弹窗确认:"]
        L --> L1["👥 发送对象: XXX 人"]
        L --> L2["💬 消息内容: (可编辑)"]
        L --> L3["✅ 确认发送 / ✖ 取消"]
        L3 -->|确认| M["Mochi 执行私信"]
    end
    
    S1 --> K
    S2 --> K
    S3 --> K
    S4 --> K
```

---

## 7. 创作者完整生命周期

```mermaid
flowchart LR
    A(["🎯 入群"]) --> B["Mochi 自动私信"]
    B --> C["完成注册<br>填写 Account ID / UID / 地址等"]
    
    C --> D["📅 新人月<br>(入群次月)"]
    D --> E["投稿作品"]
    E --> F{"满 5 分?"}
    F -->|"是 ✅"| G["+2 bonus<br>新人任务完成"]
    F -->|"否"| H["本月无 bonus"]
    
    G --> I["🔄 持续创作"]
    H --> I
    I --> J{"连续 2 个月<br>月分 ≥ 5?"}
    J -->|"是"| K["🟡 晋升金级创作官"]
    J -->|"否"| L["保留当前等级"]
    
    K --> M{"连续 3 个月<br>月分 ≥ 5?"}
    M -->|"是"| N["💎 晋升铂金创作官"]
    M -->|"否"| O["保留金级"]
    
    N --> P["🏆 最高等级"]
    
    I --> Q{"月投 15+ 条?"}
    Q -->|"是"| R["🎁 连续创作奖励<br>月卡+蜗壳币+金币"]
    Q -->|"否"| S["进度: X/15"]
    
    P --> T["🎁 兑换奖励"]
    R --> T
    T --> U["💎 钻石 / 🎮 谷歌卡 / 📦 周边"]
```

---

## 8. 数据库关系图

```mermaid
erDiagram
    KOCS ||--o{ SUBMISSIONS : "提交"
    KOCS ||--o{ POINT_LOGS : "积分"
    KOCS ||--o{ REDEMPTION_ORDERS : "兑换"
    
    KOCS {
        uid text PK
        discord_name text
        name text
        account_id text
        region text
        server text
        address text
        tier text "certified|gold|platinum"
        status text "active|inactive"
        notes text "tags: CC/old_creator/newbie_month/bonus"
        created_at timestamptz
    }
    
    SUBMISSIONS {
        id int8 PK
        uid text FK
        discord_name text
        server text
        links_engagement text "换行分隔的链接"
        status text "pending|scored"
        points_earned int4
        score_details jsonb
        total_engagement_count int4
        total_view_count int4
        scored_at timestamptz
        admin_notes text
        created_at timestamptz
    }
    
    POINT_LOGS {
        id int8 PK
        uid text FK
        change int4
        balance_after int4
        source text "auto_settlement|redemption|admin"
        reason text
        period text "YYYY-MM"
        created_by text
        created_at timestamptz
    }
    
    REDEMPTION_ORDERS {
        id int8 PK
        uid text FK
        discord_name text
        koc_name text
        option_type text "merch|diamonds|gplay"
        option_name text
        points_spent int4
        reward_amount text
        contact_info text
        status text "pending|shipped|cancelled"
        period text "YYYY-MM"
        admin_notes text
        created_at timestamptz
        processed_at timestamptz
    }
```
