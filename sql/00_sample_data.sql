-- Synthetic sample data for the first-reward journey. Every name, ID, and amount is made up.
-- Creates its own warehouse and database so both can be dropped afterward:
--   DROP DATABASE INKIND_POC; DROP WAREHOUSE INKIND_POC_WH;

CREATE WAREHOUSE IF NOT EXISTS INKIND_POC_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;  -- smallest size, sleeps after 60s idle
USE WAREHOUSE INKIND_POC_WH;
CREATE DATABASE IF NOT EXISTS INKIND_POC;
CREATE OR REPLACE SCHEMA INKIND_POC.FIRST_REWARD;
USE SCHEMA INKIND_POC.FIRST_REWARD;

-- Ten users, each one a case the journey has to handle.
--   u_1001  referral reward unused, saved two restaurants, never paid
--   u_1002  used the reward on a $64.20 first meal, then ate again
--   u_1003  $12.50 reward unused, saved one restaurant
--   u_1004  first meal was $38, under the $50 minimum, so the reward is still unused
--   u_1005  signed up without a referral, so no reward
--   u_1006  reward unused, opened the app three times in a week, never saved
--   u_1007  reward unused, three recent sessions but signed up over a month ago
--   u_1008  reward unused, but its minimum spend is missing (a data problem)
--   u_1009  reward unused, paid on Oct 14, but that row reached the warehouse on Oct 27
--   u_1010  reward unused, saved two restaurants, never paid

CREATE OR REPLACE TABLE users (
  user_id     STRING,
  created_at  TIMESTAMP_NTZ
);
INSERT INTO users VALUES
  ('u_1001', '2026-10-08 10:54:00'),
  ('u_1002', '2026-09-20 18:30:00'),
  ('u_1003', '2026-10-15 12:10:00'),
  ('u_1004', '2026-10-01 09:00:00'),
  ('u_1005', '2026-10-05 20:45:00'),
  ('u_1006', '2026-10-18 17:20:00'),
  ('u_1007', '2026-09-10 08:15:00'),
  ('u_1008', '2026-10-20 13:05:00'),
  ('u_1009', '2026-10-02 19:40:00'),
  ('u_1010', '2026-10-09 11:25:00');

CREATE OR REPLACE TABLE rewards (
  reward_id    STRING,
  user_id      STRING,
  reward_type  STRING,
  amount       NUMBER(10,2),
  min_spend    NUMBER(10,2),
  redeemed_at  TIMESTAMP_NTZ,
  updated_at   TIMESTAMP_NTZ
);
INSERT INTO rewards VALUES
  ('rw_01', 'u_1001', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-10-08 10:54:00'),
  ('rw_02', 'u_1002', 'referral_welcome', 25.00, 50.00, '2026-10-03 19:41:00', '2026-10-03 19:41:00'),
  ('rw_03', 'u_1003', 'referral_welcome', 12.50, 50.00, NULL,                  '2026-10-15 12:10:00'),
  ('rw_04', 'u_1004', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-10-01 09:00:00'),
  ('rw_06', 'u_1006', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-10-18 17:20:00'),
  ('rw_07', 'u_1007', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-09-10 08:15:00'),
  ('rw_08', 'u_1008', 'referral_welcome', 25.00, NULL,  NULL,                  '2026-10-20 13:05:00'),
  ('rw_09', 'u_1009', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-10-02 19:40:00'),
  ('rw_10', 'u_1010', 'referral_welcome', 25.00, 50.00, NULL,                  '2026-10-09 11:25:00');

-- loaded_at is when the row reached the warehouse; u_1009's arrived 13 days late.
CREATE OR REPLACE TABLE transactions (
  transaction_id  STRING,
  user_id         STRING,
  amount          NUMBER(10,2),
  reward_applied  BOOLEAN,
  created_at      TIMESTAMP_NTZ,
  loaded_at       TIMESTAMP_NTZ
);
INSERT INTO transactions VALUES
  ('tx_01', 'u_1002', 64.20, TRUE,  '2026-10-03 19:41:00', '2026-10-03 20:00:00'),
  ('tx_02', 'u_1002', 41.00, FALSE, '2026-10-17 20:12:00', '2026-10-17 20:30:00'),
  ('tx_03', 'u_1004', 38.00, FALSE, '2026-10-12 18:55:00', '2026-10-12 19:10:00'),
  ('tx_04', 'u_1009', 72.00, FALSE, '2026-10-14 19:20:00', '2026-10-27 06:00:00');

CREATE OR REPLACE TABLE app_events (
  user_id        STRING,
  event_name     STRING,
  restaurant_id  STRING,
  event_at       TIMESTAMP_NTZ
);
INSERT INTO app_events VALUES
  ('u_1001', 'session_start',    NULL,    '2026-10-08 10:58:00'),
  ('u_1001', 'session_start',    NULL,    '2026-10-11 21:05:00'),
  ('u_1001', 'restaurant_saved', 'r_201', '2026-10-11 21:09:00'),
  ('u_1001', 'restaurant_saved', 'r_214', '2026-10-11 21:12:00'),
  ('u_1003', 'session_start',    NULL,    '2026-10-16 12:30:00'),
  ('u_1003', 'restaurant_saved', 'r_233', '2026-10-16 12:34:00'),
  ('u_1006', 'session_start',    NULL,    '2026-10-18 17:25:00'),
  ('u_1006', 'session_start',    NULL,    '2026-10-21 19:02:00'),
  ('u_1006', 'session_start',    NULL,    '2026-10-25 18:40:00'),
  ('u_1007', 'session_start',    NULL,    '2026-09-10 08:20:00'),
  ('u_1007', 'session_start',    NULL,    '2026-10-20 12:00:00'),
  ('u_1007', 'session_start',    NULL,    '2026-10-22 12:10:00'),
  ('u_1007', 'session_start',    NULL,    '2026-10-24 19:45:00'),
  ('u_1008', 'session_start',    NULL,    '2026-10-20 13:10:00'),
  ('u_1010', 'session_start',    NULL,    '2026-10-09 11:30:00'),
  ('u_1010', 'restaurant_saved', 'r_208', '2026-10-09 11:41:00'),
  ('u_1010', 'restaurant_saved', 'r_219', '2026-10-13 20:02:00');
