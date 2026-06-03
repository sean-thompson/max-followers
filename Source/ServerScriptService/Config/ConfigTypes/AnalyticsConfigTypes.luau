--!strict
--[[
	AnalyticsConfigTypes
	Type definitions for GA4 analytics configuration

	The AnalyticsConfig lives in ServerScriptService (not ReplicatedStorage) because
	it contains an API secret that should not be visible to clients.

	Create the config in Studio: ServerScriptService > Config > AnalyticsConfig (ModuleScript)
]]

-- Heatmap tracking: records where players spend time on a 2D grid (X/Z).
-- Two tracking modes:
--   "summary"     - Accumulates dwell time per cell in memory, flushes periodically.
--                   Low event volume, suitable for production. Answers "where do players go?"
--   "transitions" - Fires an event each time a player crosses a cell boundary.
--                   High granularity, captures player paths/flow. Best for small-scale playtesting.
export type HeatmapConfig = {
	enabled: boolean,
	trackingMode: string,              -- "summary" (production) or "transitions" (playtesting)
	boundsMin: { number },             -- { X, Z } world-space minimum corner
	boundsMax: { number },             -- { X, Z } world-space maximum corner
	cellSize: number,                  -- studs per cell
	sampleIntervalSeconds: number,     -- how often to check player positions
	flushIntervalSeconds: number,      -- summary mode: how often to flush aggregates to GA4
	heartbeatIntervalSeconds: number,  -- transitions mode: interval for stationary player events
}

-- GA4 analytics via the Measurement Protocol.
-- Controller actions and player lifecycle events are tracked automatically.
-- Custom events can be sent via AnalyticsService:trackEvent(player, name, params).
export type AnalyticsConfig = {
	enabled: boolean,                  -- master toggle for all analytics
	measurementId: string,             -- GA4 measurement ID (e.g., "G-XXXXXXXXXX")
	apiSecret: string,                 -- GA4 Measurement Protocol API secret
	hashSalt: string,                  -- salt for one-way hashing UserIds (change per game)
	flushIntervalSeconds: number,      -- how often to send batched events to GA4
	maxBatchSize: number,              -- max events per GA4 request (GA4 limit is 25)
	debug: boolean,                    -- log events to output + send to GA4 DebugView
	heatmap: HeatmapConfig,            -- spatial heatmap tracking settings
}

return nil
