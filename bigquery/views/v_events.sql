-- v_events: All events with common params flattened from GA4
-- General-purpose view for custom queries and cross-event analysis.
-- Replace DATASET_PLACEHOLDER with your actual dataset name (e.g., analytics_528555006).

CREATE OR REPLACE VIEW `DATASET_PLACEHOLDER.v_events` AS
SELECT
  event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_time,
  event_name,
  user_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'country') AS country,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'locale') AS locale,
  event_params,
  user_properties
FROM `DATASET_PLACEHOLDER.events_*`
