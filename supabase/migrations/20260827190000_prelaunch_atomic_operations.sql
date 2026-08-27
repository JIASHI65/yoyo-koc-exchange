-- Pre-launch reliability hardening: atomic period publishing, submissions,
-- idempotent point writes, shipping deductions, and registration guards.

BEGIN;

ALTER TABLE public.point_logs
  ADD COLUMN IF NOT EXISTS operation_key TEXT;

UPDATE public.point_logs
SET operation_key = 'settlement:' || period || ':' || uid
WHERE operation_key IS NULL
  AND source = 'auto_settlement'
  AND reason = period || ' submission settlement';

UPDATE public.point_logs
SET operation_key = 'newbie-bonus:' || period || ':' || uid
WHERE operation_key IS NULL
  AND source = 'auto_settlement'
  AND reason LIKE 'New Creator Bonus%';

UPDATE public.point_logs
SET operation_key = 'ship-order:' || substring(reason FROM '#([0-9]+)')
WHERE operation_key IS NULL
  AND source = 'redemption'
  AND reason ~ '^Shipped order #[0-9]+$';

UPDATE public.redemption_orders
SET request_id = 'cc:' || period || ':' || uid
WHERE (request_id IS NULL OR request_id = '')
  AND option_name = 'CC:' || period;

CREATE UNIQUE INDEX IF NOT EXISTS idx_point_logs_operation_key_unique
  ON public.point_logs(operation_key)
  WHERE operation_key IS NOT NULL AND operation_key <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_campaign_config_single_current
  ON public.campaign_config(is_current_period)
  WHERE is_current_period = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_registration_pending_uid_unique
  ON public.registration_applications(uid)
  WHERE status IN ('pending', 'approved');

CREATE UNIQUE INDEX IF NOT EXISTS idx_registration_pending_account_unique
  ON public.registration_applications(account_id)
  WHERE status IN ('pending', 'approved');

CREATE UNIQUE INDEX IF NOT EXISTS idx_submissions_showcase_uid_period_unique
  ON public.submissions(uid, period)
  WHERE submission_type = 'showcase' AND COALESCE(period, '') <> '';

CREATE OR REPLACE FUNCTION public.publish_campaign_period(
  p_period TEXT,
  p_rules_json TEXT,
  p_points_cap INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_period IS NULL OR p_period !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'invalid campaign period';
  END IF;

  PERFORM pg_advisory_xact_lock(77190501);

  UPDATE campaign_config
  SET is_current_period = false
  WHERE is_current_period = true AND period <> p_period;

  INSERT INTO campaign_config (
    period, name, rules_json, points_cap, is_active, is_current_period, updated_at
  ) VALUES (
    p_period,
    p_period || ' Settlement',
    COALESCE(p_rules_json, '{}'),
    COALESCE(p_points_cap, 40),
    true,
    true,
    NOW()
  )
  ON CONFLICT (period) DO UPDATE SET
    rules_json = EXCLUDED.rules_json,
    points_cap = EXCLUDED.points_cap,
    is_active = true,
    is_current_period = true,
    updated_at = NOW();

  RETURN jsonb_build_object('ok', true, 'period', p_period);
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_creator_work(
  p_uid TEXT,
  p_period TEXT,
  p_discord_name TEXT,
  p_server TEXT,
  p_links TEXT,
  p_feedback TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
  v_submission_id BIGINT;
BEGIN
  IF p_uid IS NULL OR btrim(p_uid) = '' OR p_period IS NULL OR btrim(p_period) = '' THEN
    RAISE EXCEPTION 'uid and period are required';
  END IF;
  IF p_links IS NULL OR btrim(p_links) = '' THEN
    RAISE EXCEPTION 'submission links are required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('submission|' || p_uid || '|' || p_period));

  IF NOT EXISTS (
    SELECT 1 FROM campaign_config
    WHERE period = p_period
      AND is_current_period = true
      AND submissions_open = true
      AND (submissions_close_at IS NULL OR NOW() < submissions_close_at)
  ) THEN
    RAISE EXCEPTION 'submission window is closed';
  END IF;

  SELECT COUNT(*)::INTEGER INTO v_count
  FROM submissions
  WHERE uid = p_uid
    AND period = p_period
    AND COALESCE(submission_type, 'work') <> 'showcase'
    AND status <> 'rejected';

  IF v_count >= 2 THEN
    RAISE EXCEPTION 'submission limit reached';
  END IF;

  INSERT INTO submissions (
    discord_name, uid, server, links_engagement, feedback,
    submission_type, status, period, created_at
  ) VALUES (
    COALESCE(p_discord_name, ''), p_uid, COALESCE(p_server, ''), p_links,
    COALESCE(p_feedback, ''), 'work', 'pending', p_period, NOW()
  ) RETURNING id INTO v_submission_id;

  RETURN jsonb_build_object(
    'ok', true,
    'submission_id', v_submission_id,
    'used', v_count + 1,
    'remaining', 1 - v_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_creator_showcase(
  p_uid TEXT,
  p_period TEXT,
  p_discord_name TEXT,
  p_server TEXT,
  p_link TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission_id BIGINT;
BEGIN
  IF p_uid IS NULL OR btrim(p_uid) = '' OR p_period IS NULL OR btrim(p_period) = '' THEN
    RAISE EXCEPTION 'uid and period are required';
  END IF;
  IF p_link IS NULL OR btrim(p_link) = '' THEN
    RAISE EXCEPTION 'showcase link is required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('showcase|' || p_uid || '|' || p_period));

  IF NOT EXISTS (
    SELECT 1 FROM campaign_config
    WHERE period = p_period
      AND is_current_period = true
      AND submissions_open = true
      AND (submissions_close_at IS NULL OR NOW() < submissions_close_at)
  ) THEN
    RAISE EXCEPTION 'submission window is closed';
  END IF;

  IF EXISTS (
    SELECT 1 FROM submissions
    WHERE uid = p_uid AND period = p_period AND submission_type = 'showcase'
  ) THEN
    RAISE EXCEPTION 'showcase already submitted';
  END IF;

  INSERT INTO submissions (
    discord_name, uid, server, links_engagement,
    submission_type, status, period, created_at
  ) VALUES (
    COALESCE(p_discord_name, ''), p_uid, COALESCE(p_server, ''), p_link,
    'showcase', 'pending', p_period, NOW()
  ) RETURNING id INTO v_submission_id;

  RETURN jsonb_build_object('ok', true, 'submission_id', v_submission_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.add_point_log_once(
  p_uid TEXT,
  p_change INTEGER,
  p_source TEXT,
  p_reason TEXT,
  p_period TEXT,
  p_created_by TEXT,
  p_operation_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance INTEGER;
  v_log_id BIGINT;
BEGIN
  IF p_uid IS NULL OR btrim(p_uid) = '' OR p_operation_key IS NULL OR btrim(p_operation_key) = '' THEN
    RAISE EXCEPTION 'uid and operation key are required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('points|' || p_uid));

  SELECT id INTO v_log_id
  FROM point_logs
  WHERE operation_key = p_operation_key
  LIMIT 1;

  IF v_log_id IS NOT NULL THEN
    SELECT COALESCE(SUM(change), 0)::INTEGER INTO v_balance FROM point_logs WHERE uid = p_uid;
    RETURN jsonb_build_object('ok', true, 'inserted', false, 'log_id', v_log_id, 'balance', v_balance);
  END IF;

  SELECT COALESCE(SUM(change), 0)::INTEGER INTO v_balance FROM point_logs WHERE uid = p_uid;
  v_balance := v_balance + p_change;

  INSERT INTO point_logs (
    uid, change, balance_after, source, reason, period,
    created_by, operation_key, created_at
  ) VALUES (
    p_uid, p_change, v_balance, p_source, p_reason, p_period,
    COALESCE(p_created_by, ''), p_operation_key, NOW()
  ) RETURNING id INTO v_log_id;

  RETURN jsonb_build_object('ok', true, 'inserted', true, 'log_id', v_log_id, 'balance', v_balance);
END;
$$;

CREATE OR REPLACE FUNCTION public.ship_redemption_order(p_order_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order redemption_orders%ROWTYPE;
  v_point_result JSONB;
BEGIN
  SELECT * INTO v_order
  FROM redemption_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.status = 'cancelled' THEN
    RAISE EXCEPTION 'cancelled order cannot be shipped';
  END IF;

  UPDATE redemption_orders
  SET status = 'shipped', processed_at = COALESCE(processed_at, NOW()), processed_by = 'admin'
  WHERE id = p_order_id;

  IF COALESCE(v_order.points_spent, 0) > 0 THEN
    v_point_result := add_point_log_once(
      v_order.uid,
      -v_order.points_spent,
      'redemption',
      'Shipped order #' || v_order.id,
      COALESCE(NULLIF(v_order.period, ''), TO_CHAR(NOW(), 'YYYY-MM')),
      'admin_ship',
      'ship-order:' || v_order.id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'already_shipped', v_order.status = 'shipped',
    'points_deducted', COALESCE((v_point_result->>'inserted')::BOOLEAN, false)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.publish_campaign_period(TEXT, TEXT, INTEGER) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_creator_work(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_creator_showcase(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_point_log_once(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ship_redemption_order(BIGINT) TO anon, authenticated;

COMMIT;
