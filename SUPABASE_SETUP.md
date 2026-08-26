# Supabase 保活设置指南

## 问题
Supabase 免费计划会在 7 天不活跃后自动暂停项目。

## 解决方案
已添加 GitHub Actions 自动脚本，每 2 天自动 ping 一次 Supabase。

## 设置步骤

### 1. 添加 GitHub Secrets

进入你的 GitHub 仓库：
https://github.com/yoyo-creative-studio/yoyo-koc-exchange/settings/secrets/actions

点击 **New repository secret**，添加以下两个 secrets：

#### Secret 1: SUPABASE_URL
- Name: `SUPABASE_URL`
- Value: 你的 Supabase 项目 URL
  - 格式：`https://你的项目id.supabase.co`
  - 在 `index.html` 或 `admin.html` 里能找到

#### Secret 2: SUPABASE_ANON_KEY  
- Name: `SUPABASE_ANON_KEY`
- Value: 你的 Supabase anon public key
  - 在 `index.html` 或 `admin.html` 里能找到
  - 这是公开 key，不是 service_role key

### 2. 推送到 GitHub

```bash
cd /Users/arissalee/yoyo-koc-exchange-work
git add .github/workflows/keep-supabase-alive.yml
git commit -m "feat: add Supabase keep-alive workflow"
git push
```

### 3. 验证

1. 去 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 左侧会看到 "Keep Supabase Alive" workflow
4. 点击右侧的 "Run workflow" 按钮手动测试一次
5. 如果成功，以后就会每 2 天自动运行

## 运行时间

- 每 2 天的 UTC 02:17 自动运行（北京时间 10:17 AM）
- 你也可以随时手动触发

## 故障排查

如果 workflow 失败：
1. 检查 Secrets 是否正确设置
2. 检查 Supabase URL 格式是否正确
3. 确认 anon key 是否有效

## 长期方案

如果不想依赖这个脚本，可以考虑：
1. 升级到 Supabase Pro（$25/月）
2. 迁移到 Firebase（免费计划不会暂停）
3. 迁移到 PocketBase（自己部署，完全掌控）
