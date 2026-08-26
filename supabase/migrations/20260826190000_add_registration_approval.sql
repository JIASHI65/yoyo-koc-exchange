CREATE TABLE IF NOT EXISTS public.registration_applications (
  id BIGSERIAL PRIMARY KEY,
  discord_name TEXT NOT NULL,
  account_id TEXT NOT NULL,
  uid TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  server TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '',
  city TEXT NOT NULL DEFAULT '',
  state TEXT NOT NULL DEFAULT '',
  postal_code TEXT NOT NULL DEFAULT '',
  country TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  review_notes TEXT NOT NULL DEFAULT '',
  reviewed_by TEXT NOT NULL DEFAULT '',
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_registration_applications_status_created
  ON public.registration_applications(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_registration_applications_uid
  ON public.registration_applications(uid);
CREATE INDEX IF NOT EXISTS idx_registration_applications_account_id
  ON public.registration_applications(account_id);

ALTER TABLE public.registration_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "registration_applications_anon_all" ON public.registration_applications;

DROP POLICY IF EXISTS "kocs_allow_insert" ON public.kocs;
DROP POLICY IF EXISTS "anon all" ON public.kocs;
DROP POLICY IF EXISTS "anon_insert_kocs" ON public.kocs;
CREATE POLICY "kocs_no_public_insert" ON public.kocs
  FOR INSERT TO anon WITH CHECK (false);
REVOKE INSERT ON TABLE public.kocs FROM anon, authenticated;

COMMENT ON TABLE public.registration_applications IS
  'New creator applications awaiting administrator approval. Service-role Edge Function is the only access path.';
