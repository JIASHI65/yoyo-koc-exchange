# Yoyo Town · KOC Redemption System

## What This Does
- **KOC page** (`index.html`): KOC enters Discord name + UID → sees points → chooses reward → submits
- **Admin page** (`admin.html`): You manage KOCs, add/subtract points, process orders

## Setup (10 minutes)

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com) → **New project**
2. Pick a name (e.g. `yoyo-koc`), set a DB password, choose region
3. Wait for provisioning (~1 min)

### 2. Run Schema
1. In Supabase dashboard, go to **SQL Editor**
2. Copy the content of `supabase-schema.sql`
3. Paste and click **Run** → creates all tables + functions

### 3. Configure API Keys
1. In Supabase → **Settings** → **API**
2. Copy `Project URL` and `anon public key`
3. Open `index.html` and `admin.html`
4. Replace at the top:
```js
const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_KEY = 'your-anon-key';
```
5. In `admin.html`, also change the password if you want:
```js
const ADMIN_PASSWORD = 'yoyo2026';
```

### 4. Security (IMPORTANT)
In Supabase → **Authentication** → **Policies**, add these RLS policies:

```sql
-- Allow anon read for kocs
CREATE POLICY "anon can read kocs" ON kocs FOR SELECT USING (true);
-- Allow anon insert for point_logs and redemption_orders
CREATE POLICY "anon can insert point_logs" ON point_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "anon can insert orders" ON redemption_orders FOR INSERT WITH CHECK (true);
CREATE POLICY "anon can read orders" ON redemption_orders FOR SELECT USING (true);
CREATE POLICY "anon can read point_logs" ON point_logs FOR SELECT USING (true);
CREATE POLICY "anon can update orders" ON redemption_orders FOR UPDATE USING (true);
```

Or simpler: Go to **SQL Editor** and paste:
```sql
ALTER TABLE kocs ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE redemption_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_options ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon all" ON kocs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon all" ON point_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon all" ON redemption_orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "anon all" ON reward_options FOR ALL USING (true) WITH CHECK (true);
```

### 5. Deploy (GitHub Pages)
1. Push `index.html` + `admin.html` to a GitHub repo
2. Settings → Pages → Deploy from `main` branch, `/` root
3. Done! KOC page at `https://yourname.github.io/repo/`
4. Admin at `https://yourname.github.io/repo/admin.html`

### 6. Add Your First KOC
1. Open admin page → Login with password `yoyo2026`
2. Tab "Add KOC" → Enter UID + Discord name
3. Tab "KOCs" → click "+/- Points" to add points

### 7. Tell Your KOCs
Post in Discord:
> 🎀 June points are ready! Check your points and redeem rewards here:
> 🔗 https://yourname.github.io/repo/
> Enter your Discord name and UID to start.

## Workflow
1. You calculate points in Excel → add them via admin panel
2. Post announcement in Discord
3. KOCs check their points and submit redemptions
4. You process orders in admin panel → mark as shipped
5. Future: main system auto-writes to `point_logs` (source=auto_settlement)

## File Structure
```
koc-exchange/
├── index.html             # KOC redemption page
├── admin.html             # Admin management panel
├── supabase-schema.sql    # Database schema
└── README.md              # This file
```
