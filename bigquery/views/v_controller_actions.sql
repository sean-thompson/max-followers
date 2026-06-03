-- v_controller_actions: Flattened controller action events from GA4
-- Each row is one controller action dispatched by a player.
-- Replace DATASET_PLACEHOLDER with your actual dataset name (e.g., analytics_528555006).

CREATE OR REPLACE VIEW `DATASET_PLACEHOLDER.v_controller_actions` AS
SELECT
  event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_time,
  user_id,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'controller_name') AS controller_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'action_name') AS action_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id
FROM `DATASET_PLACEHOLDER.events_*`
WHERE event_name = 'controller_action'
