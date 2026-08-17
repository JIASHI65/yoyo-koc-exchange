#!/usr/bin/env python3
"""Generate the v5 full-rebuild SQL + a reordered/normalized CSV.

Reads the authoritative v5 CSV and produces:
  - reset-and-load-v5.sql : wipe old data -> add 5 address columns -> import KOCs -> opening balances
  - normalized CSV        : important columns left, the 5 address columns at far right
"""
import csv, os
from collections import Counter

SRC = "/Users/arissalee/Desktop/所有信息的表格 v5.csv"
REPO = "/Users/arissalee/yoyo-koc-exchange-work"
OUT_SQL = os.path.join(REPO, "reset-and-load-v5.sql")
OUT_CSV = "/Users/arissalee/Documents/Codex/2026-08-17/ban/outputs/所有信息的表格 v6.csv"

# 用户 2026-08-17 修正：ClarySage8611 的正确账号ID（原与 Achiru 重复）
OVERRIDES = {
    "ClarySage8611": {"account_id": "6029673467943678208"},
}

def norm_tier(t):
    t = (t or "").strip()
    if t == "认证":
        return "certified"
    if t == "铂金":
        return "platinum"
    if t.startswith("金"):
        return "gold"
    return "certified"  # 空等级 -> 系统默认 certified

def norm_server(s):
    s = (s or "").strip()
    low = s.lower()
    if low.startswith("official"):
        return "正式服"
    if low.startswith("beacon"):
        return "灯塔服"
    return s  # 已是 正式服/灯塔服，或为空

def sql_str(v):
    if v is None:
        return "''"
    return "'" + str(v).replace("'", "''") + "'"

def main():
    with open(SRC, encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    out_rows = []
    pending_rows = []
    problems = []
    seen_uid = {}
    seen_discord = {}

    for r in rows:
        discord = (r["discord名"] or "").strip()
        uid = (r["UID"] or "").strip()
        is_pending = not uid
        if is_pending:
            uid = "PENDING-" + discord  # 数据库主键占位，等注册后替换为真 UID
        if uid in seen_uid:
            problems.append("UID 重复: " + uid)
        seen_uid[uid] = discord
        if discord in seen_discord:
            problems.append("Discord 名重复: " + discord)
        seen_discord[discord] = uid

        ov = OVERRIDES.get(discord, {})
        account_id = ov.get("account_id", (r["账号ID"] or "").strip())
        balance = int((r["积分余额"] or "0").strip())

        note_parts = []
        if is_pending:
            note_parts.append("待补UID")
        base = (r["核查备注"] or "").strip()
        if discord == "ClarySage8611":
            base = "账号ID已修正（原与Achiru重复）"
        if base:
            note_parts.append(base)
        months = (r["投稿月份"] or "").strip().rstrip("，, ")
        if months:
            note_parts.append("投稿月份: " + months)
        if (r["加热授权同意"] or "").strip() == "是":
            note_parts.append("加热授权: 是")

        (pending_rows if is_pending else out_rows).append({
            "uid": uid,
            "discord_name": discord,
            "name": (r["姓名"] or "").strip(),
            "channel_tag": "",
            "status": "active",
            "region": (r["地区"] or "").strip(),
            "address": (r["地址"] or "").strip(),
            "account_id": account_id,
            "server": norm_server(r["区服"]),
            "notes": " | ".join(note_parts),
            "tier": norm_tier(r["等级"]),
            "city": (r["城市"] or "").strip(),
            "state": (r["洲"] or "").strip(),
            "postal_code": (r["邮编"] or "").strip(),
            "country": (r["国家"] or "").strip(),
            "phone": (r["电话"] or "").strip(),
            "balance": balance,
        })

    all_rows = out_rows + pending_rows  # 没有 UID 的人排在最后

    if any(o["balance"] < 0 for o in all_rows):
        problems.append("存在负积分余额")

    # ---------- SQL ----------
    cols = ["uid", "discord_name", "name", "channel_tag", "status", "region",
            "address", "account_id", "server", "notes", "tier",
            "city", "state", "postal_code", "country", "phone"]

    L = []
    L.append("-- ============================================================")
    L.append("-- KOC 兑换系统 · v5 全量重建（生成于 2026-08-17）")
    L.append("-- 1) 清空旧数据  2) 新增地址五列(表最右)  3) 导入 KOC  4) 期初积分流水")
    L.append("-- 执行位置：Supabase SQL Editor")
    L.append("-- ============================================================")
    L.append("BEGIN;")
    L.append("")
    L.append("-- 1. 清空旧数据（先删引用表，再删主表；保留 reward_options / campaign_config 配置）")
    L.append("DELETE FROM point_logs;")
    L.append("DELETE FROM redemption_orders;")
    L.append("DELETE FROM submissions;")
    L.append("DELETE FROM score_imports;")
    L.append("DELETE FROM kocs;")
    L.append("")
    L.append("-- 2. 新增地址五列（追加在 kocs 表最右）")
    L.append("ALTER TABLE kocs ADD COLUMN IF NOT EXISTS city TEXT DEFAULT '';")
    L.append("ALTER TABLE kocs ADD COLUMN IF NOT EXISTS state TEXT DEFAULT '';")
    L.append("ALTER TABLE kocs ADD COLUMN IF NOT EXISTS postal_code TEXT DEFAULT '';")
    L.append("ALTER TABLE kocs ADD COLUMN IF NOT EXISTS country TEXT DEFAULT '';")
    L.append("ALTER TABLE kocs ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '';")
    L.append("")
    L.append("-- 3. 导入 KOC（" + str(len(all_rows)) + " 人）")
    L.append("INSERT INTO kocs (" + ", ".join(cols) + ") VALUES")
    L.append(",\n".join("  (" + ", ".join(sql_str(o[c]) for c in cols) + ")" for o in all_rows))
    L.append("ON CONFLICT (uid) DO UPDATE SET " + ", ".join(c + " = EXCLUDED." + c for c in cols[1:]) + ";")
    L.append("")
    L.append("-- 4. 期初积分流水（余额 = SUM(point_logs.change)，故每人写一条 manual 流水）")
    L.append("INSERT INTO point_logs (uid, change, balance_after, source, reason, period, created_by) VALUES")
    L.append(",\n".join(
        "  ({}, {}, {}, 'manual', 'v5 数据迁移 · 期初余额', '', 'migration')".format(
            sql_str(o["uid"]), o["balance"], o["balance"]) for o in all_rows) + ";")
    L.append("")
    L.append("COMMIT;")

    with open(OUT_SQL, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")

    # ---------- CSV（重排：重要列在左，地址五列在最右）----------
    csv_cols = ["discord名", "投稿月份", "等级", "区服", "账号ID", "UID", "积分余额",
                "地区", "姓名", "加热授权同意", "主要投稿平台", "核查备注",
                "地址", "城市", "洲", "邮编", "国家", "电话"]
    normal_csv_rows = [r for r in rows if (r["UID"] or "").strip()]
    pending_csv_rows = [r for r in rows if not (r["UID"] or "").strip()]
    with open(OUT_CSV, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=csv_cols)
        w.writeheader()
        for r in normal_csv_rows + pending_csv_rows:
            discord = (r["discord名"] or "").strip()
            ov = OVERRIDES.get(discord, {})
            w.writerow({
                "discord名": discord,
                "投稿月份": (r["投稿月份"] or "").strip(),
                "等级": (r["等级"] or "").strip(),
                "区服": norm_server(r["区服"]),
                "账号ID": ov.get("account_id", (r["账号ID"] or "").strip()),
                "UID": (r["UID"] or "").strip(),
                "积分余额": (r["积分余额"] or "").strip(),
                "地区": (r["地区"] or "").strip(),
                "姓名": (r["姓名"] or "").strip(),
                "加热授权同意": (r["加热授权同意"] or "").strip(),
                "主要投稿平台": (r["主要投稿平台"] or "").strip(),
                "核查备注": (r["核查备注"] or "").strip(),
                "地址": (r["地址"] or "").strip(),
                "城市": (r["城市"] or "").strip(),
                "洲": (r["洲"] or "").strip(),
                "邮编": (r["邮编"] or "").strip(),
                "国家": (r["国家"] or "").strip(),
                "电话": (r["电话"] or "").strip(),
            })

    # ---------- 汇总 ----------
    total_balance = sum(o["balance"] for o in all_rows)
    print("CSV 总行数      :", len(rows))
    print("导入 KOC 数     :", len(all_rows))
    print("待补UID(排最后) :", len(pending_rows), [o["discord_name"] for o in pending_rows])
    print("数据问题        :", problems or "无")
    print("积分总额        :", total_balance)
    print("等级分布        :", dict(Counter(o["tier"] for o in all_rows)))
    print("区服分布        :", dict(Counter(o["server"] for o in all_rows)))
    print("产出 SQL        :", OUT_SQL)
    print("产出 CSV        :", OUT_CSV)

if __name__ == "__main__":
    main()
