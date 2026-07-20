-- Add submission and redemption toggle columns to campaign_config
ALTER TABLE campaign_config ADD COLUMN IF NOT EXISTS submissions_open BOOLEAN DEFAULT false;
ALTER TABLE campaign_config ADD COLUMN IF NOT EXISTS redemption_open BOOLEAN DEFAULT false;

-- Set July defaults (currently active period)
UPDATE campaign_config SET submissions_open = true, redemption_open = true WHERE period = '2026-07';
