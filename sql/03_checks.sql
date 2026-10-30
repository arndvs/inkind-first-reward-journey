-- Pass/fail checks. Run 00, 01, and 02 first; every row should say PASS.

USE SCHEMA INKIND_POC.FIRST_REWARD;

WITH v AS (SELECT * FROM braze_first_reward_attributes),
main_audience AS (
  SELECT u.user_id
  FROM users u
  JOIN rewards r           ON r.user_id = u.user_id
                          AND r.reward_type = 'referral_welcome'
                          AND r.redeemed_at IS NULL
  LEFT JOIN transactions t ON t.user_id = u.user_id
  WHERE t.user_id IS NULL
),
checks AS (
  SELECT 'One Braze row per referred user' AS check_name,
         '9' AS expected,
         (SELECT COUNT(DISTINCT EXTERNAL_ID) || '' FROM v
           HAVING COUNT(*) = COUNT(DISTINCT EXTERNAL_ID)) AS actual
  UNION ALL
  SELECT 'UPDATED_AT is never NULL', '0',
         (SELECT COUNT_IF(UPDATED_AT IS NULL) || '' FROM v)
  UNION ALL
  SELECT 'A used reward is sent as JSON null, so Braze clears it (u_1002)', 'true',
         (SELECT IS_NULL_VALUE(PAYLOAD:first_reward_amount)::STRING FROM v WHERE EXTERNAL_ID = 'u_1002')
  UNION ALL
  SELECT 'Plain OBJECT_CONSTRUCT would drop that key instead (keys left)', '0',
         (SELECT ARRAY_SIZE(OBJECT_KEYS(OBJECT_CONSTRUCT('first_reward_amount', NULL::NUMBER)))::STRING)
  UNION ALL
  SELECT 'Whole-dollar display (u_1001)', '25',
         (SELECT PAYLOAD:first_reward_display::STRING FROM v WHERE EXTERNAL_ID = 'u_1001')
  UNION ALL
  SELECT 'Two-decimal display (u_1003)', '12.50',
         (SELECT PAYLOAD:first_reward_display::STRING FROM v WHERE EXTERNAL_ID = 'u_1003')
  UNION ALL
  SELECT 'Minimum spend sent as a whole number (u_1001)', '50',
         (SELECT PAYLOAD:first_reward_min_spend::STRING FROM v WHERE EXTERNAL_ID = 'u_1001')
  UNION ALL
  SELECT 'First meal under $50 keeps the reward (u_1004)', '25',
         (SELECT PAYLOAD:first_reward_amount::INT::STRING FROM v WHERE EXTERNAL_ID = 'u_1004')
  UNION ALL
  SELECT 'Main Canvas audience', 'u_1001,u_1003,u_1006,u_1007,u_1008,u_1010',
         (SELECT LISTAGG(user_id, ',') WITHIN GROUP (ORDER BY user_id) FROM main_audience)
  UNION ALL
  SELECT 'Rewards with a missing minimum (the template aborts these)', 'u_1008',
         (SELECT LISTAGG(user_id, ',') WITHIN GROUP (ORDER BY user_id) FROM rewards
           WHERE reward_type = 'referral_welcome' AND redeemed_at IS NULL AND min_spend IS NULL)
  UNION ALL
  -- Why UPDATED_AT should use load time in production: with a last sync on Oct 20,
  -- u_1009's purchase arrived later, but its event-time UPDATED_AT is older than the sync,
  -- so an incremental sync would skip it.
  SELECT 'Rows a sync on Oct 20 would miss because data arrived late', 'u_1009',
         (SELECT LISTAGG(v.EXTERNAL_ID, ',') WITHIN GROUP (ORDER BY v.EXTERNAL_ID)
          FROM v JOIN transactions t ON t.user_id = v.EXTERNAL_ID
          WHERE t.loaded_at > '2026-10-20'::TIMESTAMP_NTZ
            AND v.UPDATED_AT <= '2026-10-20'::TIMESTAMP_NTZ)
)
SELECT check_name, expected, actual, IFF(expected = actual, 'PASS', 'FAIL') AS result
FROM checks;
