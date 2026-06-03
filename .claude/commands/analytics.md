---
description: Analyse GA4 analytics data from BigQuery — heatmaps, sessions, actions, insights
allowed-tools: mcp__bigquery__query, Bash, Read, Write, Glob, AskUserQuestion
---

I'll help you analyse your GA4 analytics data from BigQuery. This command guides you through querying and interpreting your game's analytics.

## Prerequisites Check

Before doing anything else, verify:

1. **BigQuery MCP is available**: Try running a simple query via `mcp__bigquery__query` (e.g., `SELECT 1`). If the tool is not available, stop and tell the user:
   ```
   BigQuery MCP server is not connected. To set it up:
   1. Create a service account in Google Cloud with BigQuery Data Viewer + BigQuery Job User roles
   2. Download the JSON key file
   3. Run: claude mcp add bigquery -s user -- npx -y @ergut/mcp-bigquery-server --project-id YOUR_PROJECT --location YOUR_REGION --key-file /path/to/key.json
   4. Restart Claude Code
   ```

2. **Analytics config**: Read `bigquery/.analytics-config.json`. If it doesn't exist, this is the first run — proceed to Dataset Discovery.

## Dataset Discovery (First Run Only)

If `bigquery/.analytics-config.json` doesn't exist:

1. Ask the user for their **BigQuery project ID** (e.g., `roblox-template-analytics`)
2. Query BigQuery to list available datasets: `SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA`
3. Show datasets matching `analytics_*` pattern and ask the user to confirm which one
4. Save to `bigquery/.analytics-config.json`:
   ```json
   {
     "projectId": "roblox-template-analytics",
     "dataset": "analytics_528555006"
   }
   ```

## Analysis Wizard

After prerequisites pass and config is loaded, proceed to the interactive wizard.

### Step 1: What do you want to know?

Ask the user what they'd like to explore:

1. **Heatmap** — Where do players spend time? Hot zones, dead zones, spatial patterns.
2. **Action analysis** — Which controller actions are most/least popular? Feature adoption over time.
3. **Session metrics** — Average session length, daily active users, retention patterns.
4. **Player flow** — What do players do first? What sequences lead to leaving? Action ordering.
5. **Demographics** — Player breakdown by country, locale, membership type.
6. **Insights** — Holistic analysis across all data. Identify patterns, anomalies, and actionable findings.
7. **Custom query** — Describe what you want in natural language. I'll write and run the SQL.

### Step 2: Date Range

Ask: "What date range? (default: last 7 days, or specify e.g. '2026-03-10 to 2026-03-17')"

Compute the `_TABLE_SUFFIX` range from the date range for cost-efficient querying. All queries below should include this filter.

### Step 3: Run Queries and Analyse

Use the query templates below. Replace `PROJECT.DATASET` with the values from `.analytics-config.json`. Replace `DATE_START` and `DATE_END` with the computed `_TABLE_SUFFIX` values (YYYYMMDD format, no hyphens).

---

## Query Templates

### Heatmap Query
```sql
SELECT
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'cell_x') AS cell_x,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'cell_z') AS cell_z,
  SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'player_seconds')) AS total_player_seconds,
  MAX((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'unique_players')) AS peak_unique_players,
  SUM((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'dwell_seconds')) AS total_dwell_seconds
FROM `PROJECT.DATASET.events_*`
WHERE event_name IN ('heatmap_summary', 'heatmap_cell', 'heatmap_presence')
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
GROUP BY cell_x, cell_z
ORDER BY total_player_seconds DESC, total_dwell_seconds DESC
```

After running, identify:
- Hottest cells (highest player_seconds or dwell_seconds)
- Cold/dead zones (cells with zero or near-zero activity)
- Clusters and spatial patterns
- After presenting text analysis, ask: "Would you like me to generate a heatmap image?"

**If user wants an image:**
1. Check `bigquery/.venv/` exists. If not, create it:
   ```bash
   cd "bigquery" && python -m venv .venv && .venv/Scripts/pip install -r requirements.txt
   ```
2. Format query results as JSON: `[{"cell_x": N, "cell_z": N, "value": N}, ...]` using `total_player_seconds` (or `total_dwell_seconds` for transitions mode) as the value
3. Pipe to heatmap.py:
   ```bash
   echo '<json_data>' | "bigquery/.venv/Scripts/python" "bigquery/scripts/heatmap.py" --title "Player Heatmap" --output "bigquery/output/heatmap.png"
   ```
4. Read the output image file to display it to the user

### Controller Actions Query
```sql
SELECT
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'controller_name') AS controller_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'action_name') AS action_name,
  COUNT(*) AS action_count,
  COUNT(DISTINCT user_id) AS unique_users
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'controller_action'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
GROUP BY controller_name, action_name
ORDER BY action_count DESC
```

Also run a daily trend query:
```sql
SELECT
  event_date,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'action_name') AS action_name,
  COUNT(*) AS action_count
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'controller_action'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
GROUP BY event_date, action_name
ORDER BY event_date, action_count DESC
```

Analyse: most/least popular actions, feature adoption, engagement depth.

### Session Metrics Query
```sql
SELECT
  COUNT(*) AS total_leave_events,
  COUNT(DISTINCT user_id) AS unique_users,
  AVG((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds')) AS avg_session_seconds,
  MIN((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds')) AS min_session_seconds,
  MAX((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds')) AS max_session_seconds
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'player_leave'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
```

Also run daily session counts:
```sql
SELECT
  event_date,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_id) AS unique_users
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'player_join'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
GROUP BY event_date
ORDER BY event_date
```

### Player Flow Query
```sql
SELECT
  user_id,
  TIMESTAMP_MILLIS((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'timestamp')) AS action_time,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'controller_name') AS controller_name,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'action_name') AS action_name
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'controller_action'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
ORDER BY user_id, action_time
```

Note: Uses the `timestamp` param (captured at queue time) rather than `event_timestamp` (set at HTTP send time) for accurate action ordering. Analyse action sequences: first actions, common paths, actions before leaving.

### Demographics Query
```sql
SELECT
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'country') AS country,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'locale') AS locale,
  (SELECT value.string_value FROM UNNEST(user_properties) WHERE key = 'membership') AS membership,
  COUNT(*) AS session_count,
  AVG((SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'session_duration_seconds')) AS avg_session_seconds
FROM `PROJECT.DATASET.events_*`
WHERE event_name = 'player_leave'
  AND _TABLE_SUFFIX BETWEEN 'DATE_START' AND 'DATE_END'
GROUP BY country, locale, membership
ORDER BY session_count DESC
```

### Insights (Holistic)
Run ALL of the above queries, then provide a comprehensive analysis covering:
- What stands out? What's surprising?
- Are there dead zones in the map?
- Are there underused features?
- Do certain player demographics behave differently?
- What actionable recommendations can you make?

### Custom Query
The user describes what they want in natural language. Write SQL using the same UNNEST patterns above against `PROJECT.DATASET.events_*`. Run it and explain the results.

## Important Notes

- Always use `_TABLE_SUFFIX` filtering for date ranges to control query costs
- Default to last 7 days if the user doesn't specify
- Present text analysis first, offer visualisations on request
- When showing numbers, include context (e.g., "847 player-seconds in cell (3,5) — that's 3x the average")
- For insights, go beyond raw numbers — identify patterns, anomalies, and make recommendations
- If a query returns no data, suggest the user check their date range or whether the relevant events are being tracked
- **Always measure standard deviation alongside any mean.** Whenever you compute an average (session length, action counts per user, player-seconds per cell, etc.), also query STDDEV in the same pass. Then act on what the SD reveals:
  - If SD is low relative to the mean → the mean is trustworthy, report it confidently
  - If SD is high relative to the mean → flag the spread, consider reporting median/mode instead, and if the data exists to explain *why* (e.g., outlier sessions, demographic splits, time-of-day effects), dig into that
  - This applies across all analysis types, not just sessions — heatmap cell values, action counts, demographics breakdowns, etc.
