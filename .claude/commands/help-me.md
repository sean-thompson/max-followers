---
description: List all available Claude slash commands for this project
---

## Project Overview

> **This is a template project.** If you are starting a new game from this template, update this section with game-specific details before developing.

This project is an MVC-based Roblox game template. Here are the key things worth knowing as a developer:

### Architecture at a glance

- **Models** (server-side) — authoritative state. All models extend `AbstractModel` and are auto-discovered by ModelRunner. Five scopes: `User`, `UserSession`, `Server`, `UserEntity`, `ServerEntity`.
- **Controllers** (server-side) — validate player intents and update models. Extend `AbstractController`, auto-discovered by ControllerRunner.
- **Views** (client-side) — observe state and send intents. Extend `AbstractView`, use CollectionService tags to find their targets in Studio.
- **Services** (server-side) — background tasks (loops or event-driven). Game services in `services/game/` are auto-discovered by ServiceRunner via `init()`.
- **Configs** — static tunable data. Split into a types file (Rojo-synced) and a data module created in Studio.

### Quirks and things to know

**`Network.luau` is the single source of truth for networking.**
Every controller intent, model state, and action constant is declared here. `NetworkBuilder` generates all Bolt events and RemoteProperties at module load — nothing is registered manually. Always keep it in alphabetical order.

**Auto-discovery everywhere.**
Models, controllers, and game services all register themselves automatically. You never import or instantiate them in a runner — just drop the file in the right folder. The exception is framework services (`services/framework/`), which have an explicit initialization order.

**Rojo owns all code; Studio owns all instances.**
Scripts live in `Source/` and sync via Rojo. UI, workspace objects, terrain, and any non-code instances are created in Studio and are not in version control. The `$ignoreUnknownInstances: true` config ensures Rojo won't delete Studio-created content.

**`syncState()` triggers both DataStore persistence and client state sync.**
Calling `self:syncState()` in a model method does two things: queues a DataStore write (via PersistenceService) and broadcasts the new state to relevant clients via Bolt RemoteProperty. Never update model properties without calling it.

**Views use CollectionService, not direct instance references.**
A view is initialized once per tagged instance. The tag goes on the root instance only — never on children. `WaitForChild` errors in views are intentional: they mean the Studio hierarchy is wrong.

**DataStore failures kick the player.**
PersistenceService kicks players when DataStore loading fails on join, rather than silently using defaults. This prevents data corruption. Don't change this behaviour without understanding the implications.

**Bolt is the networking library (not RemoteEvents directly).**
`Network.Intent.*` are Bolt ReliableEvents. `Network.State.*` are Bolt RemoteProperties. Don't bypass these with raw RemoteEvents — the type safety and batching depend on going through Bolt.

---

This project includes several slash commands to scaffold code quickly. Here's an overview of what's available:

---

## Scaffolding Commands

### `/create-model`

Scaffolds a server-side `AbstractModel` file.

- **Location:** `Source/ServerScriptService/models/<scope>/`
- **Wizard covers:** Model name, scope, properties, and methods
- **Scopes:**
  - `User` — per-player, persistent (e.g. InventoryModel)
  - `UserSession` — per-player, ephemeral/session-only (e.g. ManaModel)
  - `Server` — shared across all players, ephemeral (e.g. ShrineModel)
  - `UserEntity` — per-player, persistent, multiple instances (e.g. PetModel)
  - `ServerEntity` — shared, ephemeral, multiple instances; predefined or dynamic variants (e.g. DrawbridgeModel, CandlesModel)
- Also updates `Network.luau` with state definition and type export.

---

### `/create-controller`

Scaffolds a server-side `AbstractController` file.

- **Location:** `Source/ServerScriptService/controllers/`
- **Wizard covers:** Controller name, actions, model interactions, validation strategy, and Network.luau wiring
- **Pattern:** ACTIONS lookup table maps `Network.Actions.*` constants to handler functions
- Also updates `Network.luau` with controller config and action type export.

---

### `/create-service`

Scaffolds a server-side service for background tasks.

- **Location:** `Source/ServerScriptService/services/game/`
- **Wizard covers:** Service name and pattern selection
- **Patterns:**
  - `Loop-based` — runs on a timer (e.g. cleanup, regeneration)
  - `Event-driven` — reacts to system events (e.g. PlayerAdded, PlayerRemoving)
- Auto-discovered by ServiceRunner via `init()` function — no registration needed.

---

### `/create-view`

Scaffolds a client-side `AbstractView` file.

- **Location:** `Source/ReplicatedFirst/views/`
- **Wizard covers:** View name, CollectionService tag, instance type, user actions, state observation, and immediate feedback
- **Patterns** (auto-detected from your answers):
  - `A` — pure client-side feedback (particles, sounds, animations)
  - `B` — intent-based (sends actions to a controller via `Network.Intent.*`)
  - `C` — state observation (observes model state via `Network.State.*`)
  - `B+C` — combination of B and C

---

### `/create-config`

Scaffolds a config types file under `ReplicatedStorage/Config/ConfigTypes/`.

- **Location:** `Source/ReplicatedStorage/Config/ConfigTypes/`
- **Wizard covers:** Config name, description, properties, and example data
- **Pattern:** Two-part — a types file (synced via Rojo) paired with a data module created manually in Studio
- Outputs the config module code to paste directly into Studio.

---

### `/analytics`

Analyse GA4 analytics data from BigQuery — heatmaps, sessions, actions, and insights.

- **Requires:** BigQuery MCP server configured (see README Analytics section)
- **Wizard covers:** Analysis type selection, date range, and result interpretation
- **Analysis types:** Heatmap (spatial), action popularity, session metrics, player flow, demographics, holistic insights, custom queries
- **Visualisation:** Can generate heatmap images via Python (auto-sets up venv on first use)
- On first run, discovers your BigQuery dataset and creates flattened views for efficient querying.

---

## Maintenance Note

If you add a new command to `.claude/commands/`, update this file to document it.
