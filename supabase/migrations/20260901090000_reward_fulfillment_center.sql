BEGIN;

CREATE TABLE IF NOT EXISTS public.reward_fulfillments (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL UNIQUE REFERENCES public.redemption_orders(id) ON DELETE CASCADE,
  uid TEXT NOT NULL REFERENCES public.kocs(uid) ON DELETE CASCADE,
  period TEXT NOT NULL DEFAULT '',
  reward_type TEXT NOT NULL CHECK (reward_type IN ('diamonds','gplay','merch')),
  fulfillment_status TEXT NOT NULL DEFAULT 'preparing' CHECK (fulfillment_status IN ('preparing','ready','delivered','shipped')),
  gift_codes JSONB NOT NULL DEFAULT '[]'::jsonb,
  carrier TEXT NOT NULL DEFAULT '',
  tracking_number TEXT NOT NULL DEFAULT '',
  reward_note TEXT NOT NULL DEFAULT '',
  is_published BOOLEAN NOT NULL DEFAULT false,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT NOT NULL DEFAULT 'admin'
);

CREATE INDEX IF NOT EXISTS idx_reward_fulfillments_uid_period
  ON public.reward_fulfillments(uid, period);
CREATE INDEX IF NOT EXISTS idx_reward_fulfillments_publish
  ON public.reward_fulfillments(is_published, period);

ALTER TABLE public.reward_fulfillments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.reward_fulfillments FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.reward_fulfillments TO service_role;

CREATE OR REPLACE FUNCTION public.publish_reward_fulfillments(p_ids BIGINT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.reward_fulfillments%ROWTYPE;
  v_published INTEGER := 0;
BEGIN
  IF p_ids IS NULL OR cardinality(p_ids) = 0 THEN
    RAISE EXCEPTION 'no fulfillment records selected';
  END IF;

  FOR v_row IN
    SELECT * FROM public.reward_fulfillments
    WHERE id = ANY(p_ids)
    ORDER BY id
    FOR UPDATE
  LOOP
    IF v_row.is_published THEN
      CONTINUE;
    END IF;
    PERFORM public.ship_redemption_order(v_row.order_id);
    UPDATE public.reward_fulfillments
    SET is_published = true,
        published_at = NOW(),
        updated_at = NOW(),
        updated_by = 'admin'
    WHERE id = v_row.id;
    v_published := v_published + 1;
  END LOOP;

  IF v_published = 0 THEN
    RAISE EXCEPTION 'no unpublished fulfillment records found';
  END IF;

  RETURN jsonb_build_object('ok', true, 'published', v_published);
END;
$$;

REVOKE ALL ON FUNCTION public.publish_reward_fulfillments(BIGINT[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_reward_fulfillments(BIGINT[]) TO service_role;

COMMIT;
