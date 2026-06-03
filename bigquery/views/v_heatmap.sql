-- v_heatmap: Flattened heatmap events from GA4
-- Combines both summary and transitions mode events into a unified view.
-- Replace DATASET_PLACEHOLDER with your actual dataset name (e.g., analytics_528555006).

CREATE OR REPLACE VIEW `DATASET_PLACEHOLDER.v_heatmap` AS
SELECT
  event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_time,
  event_name,
  user_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'cell_x') AS cell_x,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'cell_z') AS cell_z,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'player_seconds') AS player_seconds,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'unique_players') AS unique_players,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'dwell_seconds') AS dwell_seconds,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'session_id') AS session_id
FROM `DATASET_PLACEHOLDER.events_*`
WHERE event_name IN ('heatmap_summary', 'heatmap_cell', 'heatmap_presence')
