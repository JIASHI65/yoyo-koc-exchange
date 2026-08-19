-- Add is_current_period column to campaign_config
-- This marks which period is currently active for creator frontend

ALTER TABLE campaign_config
ADD COLUMN IF NOT EXISTS is_current_period BOOLEAN DEFAULT false;

-- Create index for faster lookup
CREATE INDEX IF NOT EXISTS idx_campaign_config_is_current
ON campaign_config(is_current_period) WHERE is_current_period = true;

-- Set 2026-07 as current period (adjust as needed)
UPDATE campaign_config SET is_current_period = false;
UPDATE campaign_config SET is_current_period = true WHERE period = '2026-07';

COMMENT ON COLUMN campaign_config.is_current_period IS 'Marks the active settlement period shown to creators. Only one period should have this = true at any time.';
