CREATE TABLE IF NOT EXISTS public.monthly_report_snapshots (
  period TEXT PRIMARY KEY,
  payload JSONB NOT NULL,
  source_name TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.monthly_report_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS monthly_report_snapshots_read ON public.monthly_report_snapshots;
CREATE POLICY monthly_report_snapshots_read
  ON public.monthly_report_snapshots
  FOR SELECT
  TO anon, authenticated
  USING (true);

REVOKE INSERT, UPDATE, DELETE
  ON public.monthly_report_snapshots
  FROM anon, authenticated;
