-- v_sessions: Player session data from GA4
-- Joins player_join and player_leave events with user properties for demographics.
-- Replace DATASET_PLACEHOLDER with your actual dataset name (e.g., analytics_528555006).

CREATE OR REPLACE VIEW `DATASET_PLACEHOLDER.v_sessions` AS
SELECT
  event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_time,
  event_name,
  user_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds') AS session_duration_seconds,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'country') AS country,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'locale') AS locale,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'account_age_days') AS account_age_days,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'membership') AS membership
FROM `DATASET_PLACEHOLDER.events_*`
WHERE event_name IN ('player_join', 'player_leave')
