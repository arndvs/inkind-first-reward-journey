-- Warehouse spot checks for the two Canvases in 02-journey.md.
-- Run 00_sample_data.sql first.

USE SCHEMA INKIND_POC.FIRST_REWARD;

-- Main Canvas (02, section 1): everyone who matches the entry filters.
-- The save is the trigger, so it isn't part of this count.
SELECT u.user_id
FROM users u
JOIN rewards r           ON r.user_id = u.user_id
                        AND r.reward_type = 'referral_welcome'
                        AND r.redeemed_at IS NULL
LEFT JOIN transactions t ON t.user_id = u.user_id
WHERE t.user_id IS NULL;                           -- no purchase found = never paid

-- Browsing Canvas (02, section 4): reward unused, never paid, nothing saved,
-- and a third session within 14 days of signup. Braze checks this with SDK
-- session data at entry; this is the warehouse version for comparing counts.
SELECT u.user_id
FROM users u
JOIN rewards r           ON r.user_id = u.user_id
                        AND r.reward_type = 'referral_welcome'
                        AND r.redeemed_at IS NULL
LEFT JOIN transactions t ON t.user_id = u.user_id
JOIN (
  SELECT e.user_id
  FROM app_events e
  JOIN users su ON su.user_id = e.user_id
  WHERE e.event_name = 'session_start'
    AND e.event_at < DATEADD(day, 14, su.created_at)
  GROUP BY e.user_id
  HAVING COUNT(*) >= 3                             -- third session inside the first two weeks
) s                      ON s.user_id = u.user_id
WHERE t.user_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM app_events sv
    WHERE sv.user_id = u.user_id
      AND sv.event_name = 'restaurant_saved'
  );
