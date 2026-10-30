-- The Cloud Data Ingestion view from 01-data-contract.md, section 4, unchanged.
-- Run 00_sample_data.sql first.

USE SCHEMA INKIND_POC.FIRST_REWARD;

CREATE OR REPLACE VIEW braze_first_reward_attributes AS
SELECT
  r.user_id                         AS EXTERNAL_ID,              -- must match the backend's external_id
  GREATEST(r.updated_at, COALESCE(t.first_at, r.updated_at)) AS UPDATED_AT,  -- COALESCE stops a NULL from blanking it
  OBJECT_CONSTRUCT_KEEP_NULL(                                    -- keeps nulls so a used reward clears in Braze
    'first_reward_amount',    IFF(r.redeemed_at IS NULL, r.amount, NULL),
    'first_reward_display',   IFF(r.redeemed_at IS NULL,
                                  IFF(r.amount = FLOOR(r.amount),
                                      TO_VARCHAR(r.amount::INT),
                                      TRIM(TO_VARCHAR(r.amount, '9999990.00'))),
                                  NULL),
    'first_reward_min_spend', IFF(r.redeemed_at IS NULL, r.min_spend::INT, NULL),
    'first_transaction_at',   t.first_at                         -- NULL = never paid
  )                                 AS PAYLOAD
FROM rewards r
LEFT JOIN (                                                      -- LEFT JOIN keeps users with no purchases
  SELECT user_id, MIN(created_at) AS first_at
  FROM transactions
  GROUP BY user_id                                               -- one row per user, so the join can't duplicate users
) t
  ON t.user_id = r.user_id
WHERE r.reward_type = 'referral_welcome';

-- What Braze would read: one row per referred user.
SELECT * FROM braze_first_reward_attributes ORDER BY EXTERNAL_ID;
