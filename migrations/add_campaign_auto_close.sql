-- Per-period automatic close times. Values are stored as UTC timestamptz.
ALTER TABLE campaign_config
  ADD COLUMN IF NOT EXISTS submissions_close_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS redemption_close_at TIMESTAMPTZ;
