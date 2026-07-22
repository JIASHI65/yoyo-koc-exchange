-- Yoyo KOC hardening upgrade patch
-- Date: 2026-07
--
-- How to use:
-- 1) Open Supabase Dashboard -> SQL Editor.
-- 2) Paste and run this entire file.
-- 3) This patch is idempotent: it uses CREATE OR REPLACE / DROP VIEW IF EXISTS.
-- 4) It does not delete business data from kocs, submissions, point_logs, or redemption_orders.
--
-- What it upgrades:
-- - koc_balances view uses SUM(point_logs.change) instead of the last balance_after snapshot.
-- - get_balance(uid) uses the same ledger sum.
-- - redeem_points(...) locks by UID, validates items, subtracts pending orders, and creates pending orders atomically.
-- - next_koc_uid() generates the next YOYO-### UID under an advisory lock.
--
-- Quick verification after running:
-- SELECT get_balance('<existing_uid>');
-- SELECT next_koc_uid();
-- SELECT * FROM koc_balances LIMIT 5;

BEGIN;

DROP VIEW IF EXISTS koc_balances;
CREATE VIEW koc_balances AS
SELECT
  k.uid,
  k.discord_name,
  k.name,
  k.channel_tag,
  k.status,
  COALESCE((SELECT SUM(pl.change) FROM point_logs pl WHERE pl.uid = k.uid), 0)::INTEGER AS current_points
FROM kocs k
WHERE k.status = 'active';

CREATE OR REPLACE FUNCTION get_balance(p_uid TEXT)
RETURNS INTEGER AS $$
  SELECT COALESCE(SUM(change), 0)::INTEGER
  FROM point_logs
  WHERE uid = p_uid;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION redeem_points(
  p_uid TEXT,
  p_period TEXT,
  p_items JSONB,
  p_contact_info TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_available INTEGER;
  v_pending INTEGER;
  v_total_cost INTEGER := 0;
  v_item JSONB;
  v_order_count INTEGER := 0;
BEGIN
  IF p_uid IS NULL OR btrim(p_uid) = '' THEN
    RAISE EXCEPTION 'p_uid is required';
  END IF;
  IF p_period IS NULL OR btrim(p_period) = '' THEN
    RAISE EXCEPTION 'p_period is required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'p_items must be a non-empty array';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_uid));

  SELECT COALESCE(SUM(change), 0)::INTEGER INTO v_available
  FROM point_logs
  WHERE uid = p_uid;

  SELECT COALESCE(SUM(points_spent), 0)::INTEGER INTO v_pending
  FROM redemption_orders
  WHERE uid = p_uid AND status = 'pending';

  v_available := v_available - v_pending;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    IF COALESCE(NULLIF(v_item->>'option_type', ''), '') = '' THEN
      RAISE EXCEPTION 'option_type is required';
    END IF;
    IF COALESCE(NULLIF(v_item->>'option_name', ''), '') = '' THEN
      RAISE EXCEPTION 'option_name is required';
    END IF;
    IF COALESCE((v_item->>'points_spent')::INTEGER, 0) <= 0 THEN
      RAISE EXCEPTION 'points_spent must be positive';
    END IF;
    v_total_cost := v_total_cost + COALESCE((v_item->>'points_spent')::INTEGER, 0);
  END LOOP;

  IF v_total_cost > v_available THEN
    RAISE EXCEPTION 'insufficient points: available %, required %', v_available, v_total_cost;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO redemption_orders (
      uid, discord_name, koc_name,
      option_type, option_name, points_spent, reward_amount,
      contact_info, status, period, created_at
    ) VALUES (
      p_uid,
      COALESCE(v_item->>'discord_name', ''),
      COALESCE(v_item->>'koc_name', ''),
      v_item->>'option_type',
      v_item->>'option_name',
      (v_item->>'points_spent')::INTEGER,
      COALESCE(v_item->>'reward_amount', ''),
      COALESCE(NULLIF(v_item->>'contact_info', ''), p_contact_info),
      'pending',
      p_period,
      NOW()
    );
    v_order_count := v_order_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'order_count', v_order_count,
    'available_before', v_available,
    'total_cost', v_total_cost,
    'available_after', v_available - v_total_cost
  );
END;
$$;

CREATE OR REPLACE FUNCTION next_koc_uid()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_next INTEGER;
BEGIN
  PERFORM pg_advisory_xact_lock(424242);
  SELECT COALESCE(MAX(CASE WHEN uid ~ '^YOYO-[0-9]+$' THEN substring(uid FROM 6)::INTEGER END), 0) + 1
    INTO v_next
  FROM kocs;
  RETURN 'YOYO-' || LPAD(v_next::TEXT, 3, '0');
END;
$$;

COMMIT;
