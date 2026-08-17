#!/usr/bin/env python3
"""Verify the live Supabase state after running reset-and-load-v5.sql.

Exit code 0 = all checks pass; 1 = something is off.
Uses the public anon key (RLS is disabled on this project), read-only checks.
"""
import csv, json, sys, urllib.request
from collections import Counter

URL = "https://rryzofimrehmkijkckrm.supabase.co/rest/v1"
KEY = "sb_publishable_oyewqnQ8AnitAOD94Qg0nA_v6Zqkr7r"
SRC = "/Users/arissalee/Desktop/所有信息的表格 v5.csv"

def get(path):
    req = urllib.request.Request(URL + path, headers={"apikey": KEY, "Authorization": "Bearer " + KEY})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))

def main():
    rows = list(csv.DictReader(open(SRC, encoding="utf-8-sig")))
    imported = rows  # 全部 94 人（无 UID 的用 PENDING- 占位）
    pending_set = {(r["discord名"] or "").strip() for r in rows if not (r["UID"] or "").strip()}
    exp_balance = sum(int((r["积分余额"] or "0").strip()) for r in rows)
    exp_count = len(rows)

    fails = []
    def check(ok, msg):
        print(("✅ " if ok else "❌ ") + msg)
        if not ok:
            fails.append(msg)

    kocs = get("/kocs?select=*")
    logs = get("/point_logs?select=uid,change,source,reason")
    orders = get("/redemption_orders?select=id")
    subs = get("/submissions?select=id")
    imports = get("/score_imports?select=id")

    # counts
    check(len(kocs) == exp_count, f"kocs 数量 = {len(kocs)}（期望 {exp_count}）")
    check(len(logs) == exp_count, f"point_logs 数量 = {len(logs)}（期望 {exp_count}）")

    # new columns present
    sample = kocs[0] if kocs else {}
    for col in ("city", "state", "postal_code", "country", "phone"):
        check(col in sample, f"kocs 已含新列 {col}")

    # balance
    total = sum(int(l["change"]) for l in logs)
    check(total == exp_balance, f"point_logs 求和 = {total}（期望 {exp_balance}）")

    # logs all manual + v5 reason
    bad_src = [l for l in logs if l.get("source") != "manual"]
    check(not bad_src, f"所有流水 source=manual（异常 {len(bad_src)} 条）")
    bad_reason = [l for l in logs if "v5 数据迁移" not in (l.get("reason") or "")]
    check(not bad_reason, f"所有流水 reason 含 v5 数据迁移（异常 {len(bad_reason)} 条）")

    # uid unique
    uids = [k["uid"] for k in kocs]
    dups = [u for u, n in Counter(uids).items() if n > 1]
    check(not dups, f"UID 无重复（重复 {dups}）")

    # pending people present, keyed by PENDING- placeholder uid
    pending_by_discord = {k["discord_name"]: k["uid"] for k in kocs if (k["uid"] or "").startswith("PENDING-")}
    missing_pending = sorted(pending_set - set(pending_by_discord))
    check(not missing_pending, f"6 名待补UID者已入库（缺失 {missing_pending}）")
    wrong_prefix = [d for d, u in pending_by_discord.items() if u != "PENDING-" + d]
    check(not wrong_prefix, f"待补UID占位正确（异常 {wrong_prefix}）")

    # ClarySage8611 correction
    clary = next((k for k in kocs if k["discord_name"] == "ClarySage8611"), None)
    check(clary and clary.get("account_id") == "6029673467943678208", "ClarySage8611 账号ID = 6029673467943678208")

    # server normalized to Chinese
    servers = Counter((k.get("server") or "") for k in kocs)
    bad_srv = {s: n for s, n in servers.items() if s not in ("正式服", "灯塔服", "")}
    check(not bad_srv, f"区服已统一中文（异常 {bad_srv}），分布 {dict(servers)}")

    # tier valid
    bad_tier = {k["discord_name"] for k in kocs if k.get("tier") not in ("certified", "gold", "platinum")}
    check(not bad_tier, f"等级合法（异常 {bad_tier}）")

    # wiped tables
    check(len(orders) == 0, f"redemption_orders 已清空（当前 {len(orders)}）")
    check(len(subs) == 0, f"submissions 已清空（当前 {len(subs)}）")
    check(len(imports) == 0, f"score_imports 已清空（当前 {len(imports)}）")

    print()
    if fails:
        print(f"共 {len(fails)} 项未通过。")
        sys.exit(1)
    print("全部通过 ✅ 线上数据与 v5 一致。")

if __name__ == "__main__":
    main()
