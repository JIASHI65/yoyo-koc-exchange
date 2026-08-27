BEGIN;

REVOKE ALL ON FUNCTION public.publish_campaign_period(TEXT, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.add_point_log_once(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ship_redemption_order(BIGINT) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.publish_campaign_period(TEXT, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.add_point_log_once(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.ship_redemption_order(BIGINT) TO service_role;

REVOKE ALL ON FUNCTION public.submit_creator_work(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_creator_showcase(TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_creator_work(
  p_uid TEXT,
  p_account_id TEXT,
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
  IF p_uid IS NULL OR btrim(p_uid) = '' OR p_account_id !~ '^\d{19}$' OR p_period IS NULL OR btrim(p_period) = '' THEN
    RAISE EXCEPTION 'valid creator credentials and period are required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM kocs
    WHERE uid = p_uid AND account_id = p_account_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'creator credentials do not match';
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
  p_account_id TEXT,
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
  IF p_uid IS NULL OR btrim(p_uid) = '' OR p_account_id !~ '^\d{19}$' OR p_period IS NULL OR btrim(p_period) = '' THEN
    RAISE EXCEPTION 'valid creator credentials and period are required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM kocs
    WHERE uid = p_uid AND account_id = p_account_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'creator credentials do not match';
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

GRANT EXECUTE ON FUNCTION public.submit_creator_work(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_creator_showcase(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;

COMMIT;
