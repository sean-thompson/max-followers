# Roblox Template

An MVC-based starter template for Roblox game development with automatic DataStore synchronization. This template uses Rojo for code management, Claude Code for AI-assisted development, and the Roblox MCP server for direct Studio integration.

> **Note:** This template uses Luau exclusively. All script files use the `.luau`, `.server.luau`, or `.client.luau` extensions.

## MVC Architecture Overview

This template implements a strict Model-View-Controller pattern with automatic state persistence:

- **Models** (server-side): Authoritative game state that automatically syncs to DataStore
- **Views** (client-side): LocalScripts that provide responsive UI and wait for server confirmation
- **Controllers** (server-side): Listen to intents via Bolt ReliableEvents, validate, and update Models

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  View (Client) │  ← react-luau (HUD) or
                    │                │    LocalScript (Workspace)
                    └───┬────────┬───┘
                        │        │
          Immediate     │        │ Send intent via
          feedback      │        │ Network.Intent.*
          (visual)      │        │ (Bolt ReliableEvent)
                        │        ▼
                        │  ┌──────────────────┐
                        │  │ Controller       │  ← Listens to Bolt events
                        │  │ (Server)         │    Validates request
                        │  └────────┬─────────┘
                        │           │
                        │           ▼
                        │  ┌──────────────────┐
                        │  │ Model (Server)   │  ← Authoritative state
                        │  │                  │
                        │  └────┬─────────┬───┘
                        │       │         │
                        │       │         └─────────► DataStore
                        │       │                     (auto-sync)
                        │       ▼
                        │  ┌──────────────────┐
                        │  │ State Sync       │  ← Network.State.*
                        │  └────────┬─────────┘    (Bolt RemoteProperty)
                        │           │
                        │           ▼
                        └──────► View Updates  ← Visual state change
                                (Client)         via Observe() callback
```

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SERVER                                          │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐ │
│  │     Models      │    │   Controllers   │    │        Services         │ │
│  │   (state)       │◄───│   (intents)     │    │                         │ │
│  │                 │    │                 │    │  ┌───────────────────┐  │ │
│  │  user/          │    │ Listens to      │    │  │    framework/     │  │ │
│  │  server/        │    │ Network.Intent  │    │  │  (explicit order) │  │ │
│  │  userEntities/  │    │ validates &     │    │  │  - Persistence    │  │ │
│  │  serverEntities/│    │ updates models  │    │  │  - SlashCommand   │  │ │
│  │                 │    │                 │    │  ├───────────────────┤  │ │
│  │  ↓ syncState()  │    └─────────────────┘    │  │    game/          │  │ │
│  │  ↓              │                           │  │  (auto-discover)  │  │ │
│  │  ↓ DataStore ───┼──────────────────────────►│  │  - CandleService  │  │ │
│  │                 │                           │  │  - YourService    │  │ │
│  └────────┬────────┘                           │  └───────────────────┘  │ │
│           │                                    └─────────────────────────┘ │
│           │ Network.State.*                                                 │
│           ▼                                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                              CLIENT                                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                            Views                                     │   │
│  │                                                                      │   │
│  │   Observe(Network.State.*)  ──►  Update UI/Visuals                  │   │
│  │   User interaction          ──►  Fire Network.Intent.*              │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                           SHARED (ReplicatedStorage)                         │
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐ │
│  │     Network     │    │     Configs     │    │        Bolt             │ │
│  │                 │    │                 │    │   (networking lib)      │ │
│  │  Intent.*       │    │  Static data    │    │                         │ │
│  │  State.*        │    │  Prices, rates  │    │  ReliableEvent          │ │
│  │  Actions.*      │    │  Thresholds     │    │  RemoteProperty         │ │
│  │                 │    │                 │    │                         │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key relationships:**
- **Controllers → Models**: Controllers validate intents and update model state
- **Models → Views**: Models sync state via `Network.State.*`, Views observe changes
- **Views → Controllers**: Views fire intents via `Network.Intent.*`
- **Services**: Run independently - framework services have explicit order, game services are auto-discovered
- **Configs**: Static data accessible from both server and client

### Data Flow Steps

**On Player Join:**
1. **Player Joins**: PlayerAdded event fires
2. **Auto-Load**: PersistenceService loads saved data from DataStore (or uses defaults for new players). If DataStore loading fails, the player is kicked with a friendly message to prevent data corruption.
3. **Model Initialization**: Models are created and loaded data is applied
4. **Initial Broadcast**: Model broadcasts initial state to the player

**During Gameplay:**
1. **User Interaction**: User clicks a button, interacts with a 3D object, etc.
2. **Immediate Feedback**: View provides instant visual feedback (button animation, hover effect)
3. **Intent Sent**: View fires Bolt ReliableEvent via Network.Intent.* expressing user intent (not a command)
4. **Server Validation**: Controller receives intent via Bolt event, validates permissions/rules
5. **Model Update**: Controller updates the appropriate Model(s)
6. **Auto-Persist**: Model change triggers automatic DataStore write (queued with rate limiting)
7. **State Sync**: Model syncs state via Bolt RemoteProperty (Network.State.*)
8. **View Update**: Views receive state updates via Observe() callback and update visual state accordingly

## MVC Components

### Models (src/server/)

Models represent authoritative game state and live exclusively on the server:

- Single source of truth for all game data
- Automatically load from DataStore when player joins (via PersistenceService)
- Automatically persist to DataStore when state changes (via PersistenceService)
- Broadcast state changes to clients
- Three scopes available:
  - **User-scoped**: One per player, persistent (e.g., inventory, progress)
  - **Server-scoped**: Shared by all, ephemeral (e.g., match timer, shrine)
  - **UserEntity-scoped**: Multiple per player, persistent (e.g., pets, bases, character slots)
- Examples: InventoryModel (User), ShrineModel (Server), PetModel (UserEntity)

**[📖 See the Model Development Guide](MODEL_GUIDE.md)** for step-by-step instructions on creating models. The guide includes a complete example using `InventoryModel`.

### Controllers (src/server/)

Controllers handle business logic and orchestrate Model updates:

- Listen to Bolt ReliableEvents (via Network.Intent.*) expressing user intent
- Validate requests (permissions, game rules, anti-cheat)
- Update Models based on validated intents
- Never directly manipulate Views
- Examples: InventoryController, CombatController, ShopController

**[📖 See the Controller Development Guide](CONTROLLER_GUIDE.md)** for step-by-step instructions on creating controllers. The guide includes a complete example using `CashMachineController`.

### Services (src/server/)

Services are server-side modules that run automatically to handle background tasks:

- Run without user input (loops, system events)
- Handle periodic cleanup, scheduled updates, system operations
- Two patterns: Loop-based (periodic tasks) and Event-driven (respond to events)
- Organized into two categories:
  - **Framework services** (`services/framework/`): Explicit initialization order (PersistenceService, AnalyticsService, SlashCommandService)
  - **Game services** (`services/game/`): Auto-discovered by ServiceRunner - just add an `init()` function
- Examples: AnalyticsService (GA4 events), HeatmapService (spatial tracking), CandleService (candle expiry)

**[📖 See the Services Guide](SERVICES_GUIDE.md)** for step-by-step instructions on creating services. The guide includes patterns, decision trees, and complete examples.

### Views (src/client/)

Views come in two flavours depending on what they control:

**HUD views (ScreenGui / UI)** -- react-luau components:
- Built as `.luau` ModuleScripts in `Source/ReplicatedFirst/views/`
- Composed into a single ScreenGui tree mounted by `HudApp.client.luau`
- Use the `useBoltState` hook to subscribe to Bolt RemoteProperty state (Network.State.*)
- Receive data and callbacks as React props -- no BindableEvents needed
- Spring physics animation available via hooks (`useSpring`, `useTransition`, `useDrag`) -- force/dampening/mass config with zero-re-render motor bindings
- Modal windows are managed via React state (`activeModal`) inside HudApp
- Examples: StatusBarView, FavoursView, CandlesView

**Workspace views (3D parts / models)** -- imperative LocalScripts:
- Written as `.client.luau` LocalScripts in `Source/ReplicatedFirst/views/`
- Use CollectionService to target tagged objects in Workspace
- Observe state changes via Bolt RemoteProperty (Network.State.*) using Observe() callback
- Observe() fires immediately with current state -- no need to request initial state
- Provide immediate feedback for user interactions (particles, sounds, tweens)
- Examples: CashMachineView, ShrineView, BazaarView

**[📖 See the View Development Guide](VIEW_GUIDE.md)** for step-by-step instructions on creating views. The guide includes a complete example using `CashMachineView`.

### Configs (ReplicatedStorage)

Configs are static game data modules that hold tunable values:

- Separate from code - easy to adjust during playtesting
- Two-part pattern: type definitions (synced via Rojo) + data modules (created in Studio)
- Type definitions live in `Source/ReplicatedStorage/Config/ConfigTypes/`
- Config modules are created manually in Studio under `ReplicatedStorage.Config`
- Examples: item prices, spawn rates, level thresholds, damage values

**[📖 See the Config Development Guide](CONFIG_GUIDE.md)** for step-by-step instructions on creating configs. The guide includes a complete example using `FavoursConfig`.

### Claude Slash Commands

Claude Code slash commands are available to scaffold all MVC components without writing boilerplate by hand. Commands live in [`.claude/commands/`](.claude/commands/).

| Command | What it does |
|---|---|
| `/create-model` | Scaffolds a server-side `AbstractModel` file with scope, properties, and Network.luau wiring |
| `/create-controller` | Scaffolds a server-side `AbstractController` file with actions, validation, and Network.luau wiring |
| `/create-service` | Scaffolds a server-side service for background tasks (loop-based or event-driven) |
| `/create-view` | Scaffolds a view -- react-luau component for HUD or imperative LocalScript for workspace |
| `/create-config` | Scaffolds a config types file and outputs the Studio config module |

Run `/help-me` in Claude Code for a full description of each command.

> **Maintenance:** If you add a new command to `.claude/commands/`, update `.claude/commands/help-me.md` to document it.

### Slash Commands (Admin/Debug Tool)

Slash commands provide a quick way for high-rank users to execute model methods directly from chat:

- Convention-based: Any model method automatically becomes a slash command
- Permission-controlled: Only rank 200+ users in the owning group
- Zero configuration: Commands auto-discovered at server startup
- Examples: `/inventorymodel addGold 100`, `/shrinemodel donate 123 50`

**[📖 See the Slash Commands Guide](SLASH_COMMANDS.md)** for complete documentation on using and customizing slash commands.

### Bolt Networking Library

Bolt is a high-performance networking library included with this template that provides efficient alternatives to RemoteEvents and RemoteFunctions:

- **Binary serialization**: Reduces bandwidth usage through compact data encoding
- **Automatic batching**: Groups multiple messages into single network packets
- **Type-safe API**: Strongly typed events, properties, and functions
- **Optional optimization**: Works with default serialization or custom serializers

**[📖 See the Bolt API Reference](BOLT_API.md)** for complete documentation on using Bolt for networking in your game.

## Key Principles

### 1. Intents, Not Commands

Bolt ReliableEvents express **what the user wants to do**, not direct commands:
- Good: `RequestPurchaseItem`, `AttemptEquipWeapon`
- Bad: `SetInventory`, `UpdatePlayerGold`

### 2. Optimistic UI with Server Authority

- **Immediate feedback**: Button animations, sound effects, loading states
- **Wait for confirmation**: Inventory updates, score changes, state transitions
- **Visual feedback**: Show loading/pending states while waiting for server

### 3. How Views Connect

**HUD views** use react-luau:
- Components subscribe to server state with the `useBoltState` hook
- Spring physics animation hooks (`useSpring`, `useTransition`, `useDrag`) provide smooth motion with configurable force/dampening/mass and zero-re-render motor bindings
- Props and callbacks flow through the React tree (HudApp is the root)
- No CollectionService tags or Studio-authored ScreenGuis needed

**Workspace views** use CollectionService tags:
- `game:GetService("CollectionService"):GetTagged("CashMachine")` finds tagged parts/models
- Supports both server-created and client-only objects

### 4. Separation of Concerns

- **Models**: Know nothing about Views or user input
- **Views**: Know nothing about business logic or validation
- **Controllers**: Bridge between user intent and state changes

## Project Architecture

This template enforces strict separation between code and Studio-created content:

### Code Management (Rojo)

All code must be managed through Rojo and stored in the repository:

- `Source/ServerScriptService/` - Server-side scripts (syncs to ServerScriptService)
- `Source/ReplicatedFirst/` - Client-side scripts (syncs to ReplicatedFirst)
- `Source/ReplicatedStorage/` - Shared modules (syncs to ReplicatedStorage)

### Studio-Only Content

All UI and Workspace objects must be created directly in Roblox Studio:

- This includes: Workspace parts/models/terrain, Lighting, SoundService, other service configurations, any non-code instances (HUD UI is now code-only via react-luau -- no StarterGui authoring needed)
- These instances are NOT synced via Rojo and will NOT be in version control
- The `$ignoreUnknownInstances: true` configuration ensures Rojo won't delete Studio-created content

## Analytics (GA4)

This template includes built-in Google Analytics 4 integration via the Measurement Protocol. Controller actions and player lifecycle events are tracked automatically — new controllers get analytics coverage with zero additional code.

### What's Tracked Automatically
- **Controller actions**: Every `dispatchAction()` call generates a `controller_action` event with controller and action names
- **Player join/leave**: Session start, player join, and player leave events with session duration
- **Player demographics**: Locale, country, account age, and membership (non-personal, hashed user IDs)

### Spatial Heatmap
HeatmapService tracks where players spend time on a configurable 2D grid (X/Z). Two modes:
- **Summary** (default): Accumulates dwell time per cell, flushes periodically. Production-safe.
- **Transitions**: Fires events on cell boundary crossings. Captures player paths, best for playtesting.

### Setup
1. Create `AnalyticsConfig` ModuleScript in Studio at `ServerScriptService > Config`
2. Fill in your GA4 `measurementId`, `apiSecret`, and `hashSalt`
3. Enable HttpService in Game Settings > Security
4. See [CONFIG_GUIDE.md](CONFIG_GUIDE.md) for the full config structure including heatmap settings

## Prerequisites

1. [Rojo](https://rojo.space/) - Install the Rojo CLI and Roblox Studio plugin
2. [Claude Code](https://claude.com/claude-code) - AI-powered development assistant
3. [Roblox Studio MCP Server](https://github.com/Roblox/studio-rust-mcp-server/releases) - For Claude integration

## Claude + MCP Integration

The Roblox Studio MCP server gives Claude direct access to your running Studio instance:

- **Direct Studio access**: Execute Luau code in Roblox Studio from Claude
- **Live debugging**: Query game state, read Output, inspect Explorer hierarchy
- **Model insertion**: Add marketplace assets programmatically
- **Permissions configured** in `.claude/settings.local.json` (not tracked in git)

### Setup Steps for This Project

1. **Install the Roblox Studio MCP Server** from https://github.com/Roblox/studio-rust-mcp-server/releases
   - Download `rbx-studio-mcp.exe` to a known location (e.g., `C:\Users\YOUR_USERNAME\Downloads\`)

2. **Add MCP Server to Claude CLI** (local to this project):
   ```bash
   claude mcp add --scope local --transport stdio roblox-studio -- "C:\Users\YOUR_USERNAME\Downloads\rbx-studio-mcp.exe" --stdio
   ```

   This will add the MCP server configuration to your local `.claude.json` file for this project.

3. **Verify connection**:
   ```bash
   claude mcp list
   ```

   You should see:
   ```
   roblox-studio: C:\Users\YOUR_USERNAME\Downloads\rbx-studio-mcp.exe --stdio - ✓ Connected
   ```

4. **IMPORTANT: Restart Claude Code**
   - Exit Claude Code completely
   - Restart Claude Code
   - Resume your conversation or start a new one
   - The MCP tools will only be available after the restart

5. **Test the connection**
   - Ask Claude to run: `print("MCP test successful!")`
   - Check Roblox Studio's Output window for the message
   - If you see the output, MCP is working correctly!

### Startup Order (Critical)

Always start in this order:
1. Open Roblox Studio FIRST
2. Start Rojo (`rojo serve`)
3. Start Claude Code

### MCP Limitations (Edit Mode vs Play Mode)

**Important**: The game is NOT running while editing in Studio. MCP operates in Edit mode by default.

#### What MCP CAN do:
- Query workspace structure
- Find tagged objects
- Insert models from the marketplace
- Execute server-side code
- Read Output window contents
- Read Explorer hierarchy

#### What MCP CANNOT do:
- Test client scripts (LocalScripts don't run in Edit mode)
- Simulate player join events
- Test UI rendering
- Verify runtime initialization
- Test attribute changes/events that require the game to be running

**Solution**: Use Play mode (F5 in Studio) to test client-side behavior, UI, and gameplay.

## Development Workflow

### Building an MVC Feature

1. **Create the Model** (`src/server/models/`)
   - Define the data structure as a ModuleScript (`.luau`)
   - Call `syncState()` after state changes to trigger persistence and state sync
   - DataStore persistence is automatic via PersistenceService
   - Example: `PlayerInventory.luau`

2. **Create the Controller** (`src/server/controllers/`)
   - Create a Script (`.server.luau`) that listens to Bolt ReliableEvents
   - Validate incoming requests
   - Call Model methods to update state
   - Example: `InventoryController.server.luau`

3. **Create the View** (`src/client/views/`)

   **For HUD / ScreenGui features** (react-luau):
   - Create a `.luau` ModuleScript that returns a React component
   - Use `useBoltState` to subscribe to Network.State.* inside the component
   - Wire the component into `HudApp.client.luau` (add require, render in tree)
   - Example: `FavoursView.luau`

   **For Workspace / 3D features** (imperative):
   - Create a `.client.luau` LocalScript
   - Use CollectionService to find tagged parts/models in Workspace
   - Observe state changes via Network.State.* and update visuals
   - Example: `CashMachineView.client.luau`

4. **Create Visual Elements in Studio** (workspace views only)
   - Build parts/models in Workspace
   - Add CollectionService tags to elements the View will target
   - Example: Tag a part with "CashMachine"

5. **Define Network Events** (`Network.luau`)
   - Add entries to NetworkConfig for controllers and states
   - NetworkBuilder automatically generates Bolt events at module load
   - Network.Intent.* - Bolt ReliableEvents for user actions
   - Network.State.* - Bolt RemoteProperties for model state
   - Network.Actions.* - Action constants for type-safe validation

## Quick Reference: Adding New Components

These checklists provide step-by-step guidance for adding new components to your MVC architecture. Each checklist explicitly includes updating the Network.luau module (Network.Actions and event registration).

### Adding a New Model

1. ✓ **Choose scope**: User (per-player, single instance, persistent), Server (shared, ephemeral), or UserEntity (per-player, multiple instances, persistent). See [MODEL_GUIDE.md](MODEL_GUIDE.md) for decision tree.
2. ✓ **Create model file** in `src/server/models/user/`, `src/server/models/server/`, or `src/server/models/userEntities/`
3. ✓ **Extend AbstractModel** with proper inheritance pattern (`setmetatable`)
4. ✓ **Define properties** in the exported type (using `typeof(setmetatable(...))`)
5. ✓ **Implement `.new()`** method with AbstractModel.new("ModelName", ownerId, scope)
6. ✓ **Implement `.get()`** method using AbstractModel.getOrCreate()
7. ✓ **Implement `.remove()`** method using AbstractModel.removeInstance()
8. ✓ **Add business logic methods** that modify properties and call `self:syncState()`
9. ✓ **Register state in Network.luau**:
   - Add entry to NetworkConfig.States with default values (NetworkBuilder auto-generates Bolt RemoteProperty)
   - Add exported data type (e.g., `export type YourModelData = { ownerId: string, ... }`)
10. ✓ **Test with ModelRunner** - Models are auto-discovered by PersistenceService

**See [MODEL_GUIDE.md](MODEL_GUIDE.md) for detailed examples.**

### Adding a New Controller

1. ✓ **Decide what user intents** this controller will handle (e.g., "Purchase", "Equip", "Donate")
2. ✓ **Add action constants to Network.luau** FIRST:
   - Add entry to NetworkConfig.Controllers with action list (NetworkBuilder auto-generates Intent and Actions)
   - Example: `YourFeature = { "Action1", "Action2" }` in NetworkConfig.Controllers
3. ✓ **Create controller file** in `src/server/controllers/`
4. ✓ **Extend AbstractController** with proper inheritance pattern
5. ✓ **Define action handler functions** (if using lookup table pattern)
6. ✓ **Create ACTIONS lookup table** mapping Network.Actions constants to handler functions
7. ✓ **Set up OnServerEvent listener** with typed action parameter (e.g., `action: string`)
8. ✓ **Add validation logic** (amount checks, permissions, anti-cheat)
9. ✓ **Get model instance** using Model.get(ownerId)
10. ✓ **Dispatch actions** using `self:dispatchAction(ACTIONS, action, player, model, ...)`
11. ✓ **Test with ControllerRunner** - Controllers are auto-discovered

**See [CONTROLLER_GUIDE.md](CONTROLLER_GUIDE.md) for detailed examples.**

### Adding a New View

**Choose the right kind of view first:**
- HUD / ScreenGui feature → react-luau component (`.luau` ModuleScript)
- Workspace / 3D feature → imperative LocalScript (`.client.luau`)

#### HUD view (react-luau)

1. ✓ **Verify Network.State.* exists** (if observing state)
2. ✓ **Create view file** in `src/client/views/` as a `.luau` ModuleScript (e.g., `YourView.luau`)
3. ✓ **Write a React function component** that returns UI elements via `React.createElement`
4. ✓ **Use `useBoltState` hook** to subscribe to Bolt state: `local data = useBoltState(Network.State.YourModel, defaultValue)`
5. ✓ **Accept props** for data, callbacks, and modal state from HudApp
6. ✓ **Fire intents** using `Network.Intent.YourFeature:FireServer(Network.Actions.YourFeature.Action, ...)`
7. ✓ **Wire into HudApp.client.luau**: require the component and add it to the render tree
8. ✓ **Test in Play mode** (F5 in Studio)

#### Workspace view (imperative)

1. ✓ **Decide which pattern**: A (pure client), B (intent-based), or C (state observation). See [VIEW_GUIDE.md](VIEW_GUIDE.md) for decision tree.
2. ✓ **Verify Network.Actions constants exist** (if sending intents - Pattern B)
3. ✓ **Verify Network.State.* exists** (if observing state - Pattern C)
4. ✓ **Create view file** in `src/client/views/` (name it `YourView.client.luau`)
5. ✓ **Use CollectionService** to find tagged instances and set up each one
6. ✓ **Connect to user interactions** (proximity prompts, click detectors, etc.)
7. ✓ **Use Network.Actions constants** when firing intents (e.g., `Network.Intent.YourFeature:FireServer(Network.Actions.YourFeature.Action)`)
8. ✓ **Use Network.State and Observe()** when observing state changes:
    - Observe state: `Network.State.YourModel:Observe(function(data) ... end)`
    - Observe() fires immediately with current value - no need to request initial state
9. ✓ **Create objects in Roblox Studio** and tag with CollectionService
10. ✓ **Test in Play mode** (F5 in Studio)

**See [VIEW_GUIDE.md](VIEW_GUIDE.md) for detailed examples.**

### Adding a New Config

1. ✓ **Decide if you need a config** - Use for tunable values (prices, rates, thresholds). See [CONFIG_GUIDE.md](CONFIG_GUIDE.md) for decision tree.
2. ✓ **Create types file** in `Source/ReplicatedStorage/Config/ConfigTypes/{Name}ConfigTypes.luau`
3. ✓ **Define table types** for any structured data (e.g., `export type PricesTable = { [string]: number }`)
4. ✓ **Define main config type** (e.g., `export type {Name}Config = { ... }`)
5. ✓ **Return nil** from types file (types-only module)
6. ✓ **Create config module in Studio** under `ReplicatedStorage.Config`
7. ✓ **Import types** from ConfigTypes folder
8. ✓ **Annotate config variable** with the type for type safety
9. ✓ **Test in Studio** by requiring in command bar

**See [CONFIG_GUIDE.md](CONFIG_GUIDE.md) for detailed examples.**

### Adding a New Service

1. ✓ **Choose pattern**: Loop-based (periodic tasks) or Event-driven (respond to events). See [SERVICES_GUIDE.md](SERVICES_GUIDE.md) for decision tree.
2. ✓ **Choose location**: `services/game/` for most services (auto-discovered), `services/framework/` only if initialization order matters
3. ✓ **Create service file** in `Source/ServerScriptService/services/game/YourService.luau`
4. ✓ **Implement init() function** that starts the service (required for auto-discovery)
5. ✓ **For loop-based**: Use `task.spawn()` with `while true do` loop and `isRunning` flag
6. ✓ **For event-driven**: Connect to events (PlayerAdded, etc.) in init()
7. ✓ **Add print statements** with `[ServiceName]` prefix for debugging
8. ✓ **Test in Play mode** - Check Output window for `[ServiceRunner] Initialized: YourService`

**See [SERVICES_GUIDE.md](SERVICES_GUIDE.md) for detailed examples.**

### Updating Network.Actions

**When to update:** You need a new user action (button click, prompt trigger, purchase intent, etc.)

1. ✓ **Open `Source/ReplicatedStorage/Network.luau`**
2. ✓ **Add entry to NetworkConfig.Controllers** (NetworkBuilder auto-generates Intent and Actions):
   ```lua
   -- In NetworkConfig table
   Controllers = {
       YourFeature = { "ActionName", "AnotherAction" },
   },
   ```
3. ✓ **Add exported action type** (optional, for type safety):
   ```lua
   export type YourFeatureAction = "ActionName" | "AnotherAction"
   ```
4. ✓ **Update controller** to use new action in ACTIONS table and dispatchAction call
5. ✓ **Update view** to use Network.Intent.YourFeature and Network.Actions constants

**Naming conventions:**
- ✅ Good: `PurchaseWeapon`, `EquipItem`, `Donate`, `BuyTreasure` (verb-based, intent-focused)
- ❌ Bad: `SetInventory`, `Update`, `Click`, `Execute` (commands or too vague)

**See [CONTROLLER_GUIDE.md](CONTROLLER_GUIDE.md) for more details on working with Network.Actions.**

### Updating Network.State

**When to update:** You create a new model that syncs state to clients

1. ✓ **Open `Source/ReplicatedStorage/Network.luau`**
2. ✓ **Add entry to NetworkConfig.States** with default values (NetworkBuilder auto-generates Bolt RemoteProperty):
   ```lua
   -- In NetworkConfig table
   States = {
       YourModel = {
           ownerId = "",
           property1 = defaultValue,
           property2 = defaultValue,
       },
   },
   ```
3. ✓ **Add exported data type** matching model properties (optional, for type safety):
   ```lua
   export type YourModelData = {
       ownerId: string,  -- Always include!
       property1: type,
       property2: type,
   }
   ```
4. ✓ **Use in model** - Call `Network.registerState("YourModel")` in AbstractModel.new()
5. ✓ **Update views** to use Network.State.YourModel:Observe() when observing state

**What to include in data type:**
- ✅ Always: `ownerId: string` (required for filtering, even if not always used)
- ✅ Include: Properties that views need to display
- ✅ Include: Properties that change over time
- ❌ Don't include: Internal model state that clients never see
- ❌ Don't include: Computed values that views calculate themselves

**See [MODEL_GUIDE.md](MODEL_GUIDE.md) and [VIEW_GUIDE.md](VIEW_GUIDE.md) for more details on working with Network.State.**

## Tutorial: Adding a Complete Feature

This tutorial walks through adding a complete "Weapon Shop" feature from scratch, demonstrating the full MVC flow and how Network.luau ties everything together with Bolt networking.

### Feature Requirements

- Players can view available weapons in a shop UI
- Each weapon has a name and gold cost
- Players can purchase weapons with their gold
- Purchase validates player has enough gold
- UI shows updated gold after purchase
- Shop broadcasts purchases to all players (for demonstration)

### Step 1: Plan Your Architecture

Before writing code, decide:

**Models:**
- Use existing `InventoryModel` (already tracks gold, will deduct cost)
- Create new `WeaponShopModel` (Server-scoped, tracks last purchase for broadcast)

**Controller:**
- Create `WeaponShopController` to validate purchases and update models

**Views:**
- Reuse `StatusBarView` (already observes InventoryStateChanged for gold display)
- Create `WeaponShopView` to show weapons and handle purchase clicks

**Network Events:**
- Add `Network.Intent.WeaponShop` - Bolt ReliableEvent for purchase actions
- Add `Network.Actions.WeaponShop.PurchaseWeapon` - Action constant
- Add `Network.State.WeaponShop` - Bolt RemoteProperty to broadcast purchases to all players
- Use existing `Network.State.Inventory` (for gold updates)

### Step 2: Add Network Events

**File:** `Source/ReplicatedStorage/Network.luau`

Add the Bolt ReliableEvent and action constants:

```lua
-- Add to Network.Intent section
Network.Intent.WeaponShop = Bolt.ReliableEvent("WeaponShopIntent")

-- Add to Network.Actions section
Network.Actions.WeaponShop = {
    PurchaseWeapon = "PurchaseWeapon",
}

-- Add to Network.State section (for broadcasting purchases)
Network.State.WeaponShop = Bolt.RemoteProperty({
    ownerId = "SERVER",
    lastPurchase = "",
    buyerName = "",
})
```

### Step 3: Create the WeaponShopModel

**File:** `src/server/models/server/WeaponShopModel.luau`

```lua
--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local WeaponShopModel = {}
WeaponShopModel.__index = WeaponShopModel
setmetatable(WeaponShopModel, AbstractModel)

export type WeaponShopModel = typeof(setmetatable({} :: {
    lastPurchase: string,
    buyerName: string,
}, WeaponShopModel)) & AbstractModel.AbstractModel

function WeaponShopModel.new(ownerId: string): WeaponShopModel
    local self = AbstractModel.new("WeaponShopModel", ownerId, "Server") :: any
    setmetatable(self, WeaponShopModel)

    self.lastPurchase = ""
    self.buyerName = ""

    return self :: WeaponShopModel
end

function WeaponShopModel.get(ownerId: string): WeaponShopModel
    return AbstractModel.getOrCreate("WeaponShopModel", ownerId, function()
        return WeaponShopModel.new(ownerId)
    end) :: WeaponShopModel
end

function WeaponShopModel.remove(ownerId: string): ()
    AbstractModel.removeInstance("WeaponShopModel", ownerId)
end

function WeaponShopModel:recordPurchase(weaponName: string, playerName: string): ()
    self.lastPurchase = weaponName
    self.buyerName = playerName
    self:syncState()  -- Broadcast to all players (Server-scoped)
end

return WeaponShopModel
```

**Key points:**
- Server-scoped model (accessed via `WeaponShopModel.get("SERVER")`)
- `syncState()` automatically broadcasts to all players for Server-scoped models
- Tracks last purchase for demonstration purposes

### Step 5: Create the WeaponShopController

**File:** `src/server/controllers/WeaponShopController.luau`

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local WeaponShopModel = require(script.Parent.Parent.models.server.WeaponShopModel)
local Network = require(ReplicatedStorage.Network)

local WeaponShopController = {}
WeaponShopController.__index = WeaponShopController
setmetatable(WeaponShopController, AbstractController)

export type WeaponShopController = typeof(setmetatable({}, WeaponShopController)) & AbstractController.AbstractController

-- Weapon catalog (in real game, might come from configuration)
local WEAPON_PRICES = {
    Sword = 100,
    Bow = 150,
    Staff = 200,
}

local function purchaseWeapon(player: Player, inventory: any, weaponShop: any, weaponName: string)
    local price = WEAPON_PRICES[weaponName]

    if not price then
        warn("Invalid weapon requested by " .. player.Name .. ": " .. weaponName)
        return
    end

    -- Try to spend gold (returns true if successful)
    if inventory:spendGold(price) then
        print(player.Name .. " purchased " .. weaponName .. " for " .. price .. " gold")
        weaponShop:recordPurchase(weaponName, player.Name)
    else
        print(player.Name .. " doesn't have enough gold for " .. weaponName)
    end
end

local ACTIONS = {
    [Network.Actions.WeaponShop.PurchaseWeapon] = purchaseWeapon,
}

function WeaponShopController.new(): WeaponShopController
    local self = AbstractController.new("WeaponShopController") :: any
    setmetatable(self, WeaponShopController)

    -- Set up event listener
    self.intentEvent.OnServerEvent:Connect(function(
        player: Player,
        action: string,
        weaponName: string
    )
        -- Validate weapon name
        if type(weaponName) ~= "string" or weaponName == "" then
            warn("Invalid weapon name from " .. player.Name)
            return
        end

        -- Get models
        local inventory = InventoryModel.get(tostring(player.UserId))
        local weaponShop = WeaponShopModel.get("SERVER")

        -- Dispatch action
        self:dispatchAction(ACTIONS, action, player, inventory, weaponShop, weaponName)
    end)

    return self :: WeaponShopController
end

return WeaponShopController
```

**Key points:**
- Uses Network.Actions constants for type-safe action handling
- Validates weapon name and price lookup
- Gets both user-scoped (inventory) and server-scoped (shop) models
- `spendGold()` returns boolean, so validation is built into model
- Broadcasts purchase via weaponShop:recordPurchase()

### Step 6: Create the WeaponShopView

Because this is a ScreenGui / HUD feature, it is built as a react-luau component and wired into HudApp.

**File:** `src/client/views/WeaponShopView.luau`

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("React"))

local viewsFolder = script.Parent
local useBoltState = require(viewsFolder:WaitForChild("hooks"):WaitForChild("useBoltState"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local e = React.createElement

local SHOP_DEFAULT = {
    ownerId = "SERVER",
    lastPurchase = "",
    buyerName = "",
}

local WEAPONS = {
    { name = "Sword", price = 100 },
    { name = "Bow",   price = 150 },
    { name = "Staff", price = 200 },
}

local function WeaponShopView()
    local shopData = useBoltState(Network.State.WeaponShop, SHOP_DEFAULT)

    -- Show broadcast when someone buys something
    if shopData.lastPurchase ~= "" then
        print("SHOP: " .. shopData.buyerName .. " just bought a " .. shopData.lastPurchase .. "!")
    end

    local buttons = {}
    for i, weapon in WEAPONS do
        buttons["Weapon" .. i] = e("TextButton", {
            Text = weapon.name .. " (" .. weapon.price .. "g)",
            Size = UDim2.fromOffset(200, 50),
            LayoutOrder = i,
            [React.Event.Activated] = function()
                print("Requesting to purchase " .. weapon.name .. "...")
                Network.Intent.WeaponShop:FireServer(
                    Network.Actions.WeaponShop.PurchaseWeapon,
                    weapon.name
                )
            end,
        })
    end

    buttons["Layout"] = e("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })

    return e("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, buttons)
end

return WeaponShopView
```

**Then wire it into HudApp.client.luau:**

```lua
-- In HudApp.client.luau, add require:
local WeaponShopView = require(viewsFolder:WaitForChild("WeaponShopView"))

-- Add to the modal section (alongside Favours, Candles):
elseif activeModal == "weaponShop" then
    modalElement = e(ModalWindow, {
        title = "Weapon Shop",
        ...
        bodyContent = e(WeaponShopView),
    })
```

**Key points:**
- React component -- no AbstractView, no CollectionService tags
- Uses `useBoltState` hook to subscribe to shop state reactively
- Uses Network.Actions.WeaponShop.PurchaseWeapon for type-safe intent
- Fires intents via `React.Event.Activated` callback on buttons
- Wired into HudApp's modal system via React state
- No Studio-authored ScreenGui needed -- UI is entirely code-driven
- StatusBarView (already exists) will show gold updates automatically

### Step 7: Test Setup

No Studio UI authoring is needed for HUD views. The react-luau component renders its own UI tree into HudApp's ScreenGui automatically.

### Step 8: Test the Complete Flow

1. **Start Play mode** (F5 in Studio)
2. **Open Output window** to see print statements
3. **Click a weapon button** (e.g., "Sword")
4. **Observe the flow:**
   ```
   Output:
   Requesting to purchase Sword...
   [Player Name] purchased Sword for 100 gold
   SHOP: [Player Name] just bought a Sword!
   ```
5. **Check StatusBarView**: Gold should decrease by 100
6. **Try purchasing without enough gold**: Should see "doesn't have enough gold" message

### Step 9: Test with Multiple Players (Optional)

1. **Start Server Test** (Test tab → Server in Studio)
2. **Start 2+ player clients**
3. **Purchase weapon on one client**
4. **Observe broadcast on all clients**: "SHOP: PlayerName just bought a Sword!"

### What You Learned

✓ **Network.Actions connects views to controllers** - Type-safe action constants prevent typos
✓ **Network.State with Observe() connects models to views** - Reactive state synchronization via Bolt
✓ **Model scopes matter** - User-scoped (Inventory) vs Server-scoped (WeaponShop)
✓ **Automatic scope detection** - syncState() automatically detects scope from model type
✓ **MVC separation** - Views don't validate, Controllers validate, Models are authoritative
✓ **Optimistic UI** - Immediate feedback (print) + wait for confirmation (gold update)
✓ **Complete data flow** - User click → Bolt ReliableEvent → Controller validation → Model update → Bolt RemoteProperty sync → useBoltState / Observe() → View update

### Next Steps

- Add weapon inventory to InventoryModel
- Show owned weapons in UI
- Add weapon equipping system
- Persist weapon purchases to DataStore (automatic via PersistenceService!)
- Add sell-back functionality

### General Workflow

1. Write code in your preferred editor in the `src/` directories
2. Rojo will automatically sync your code changes to Studio
3. Create workspace objects (parts, models) directly in Studio
4. Tag workspace objects with CollectionService for workspace views to find them
5. Test with MCP (structural) and Play mode (behavioral)
6. Commit only code changes to git - Studio-created content stays in place file

### File Naming Conventions

- `.server.luau` - Creates a Script (server-side) - Use for Controllers
- `.client.luau` - Creates a LocalScript (client-side) - Use for workspace views and client entry points (e.g., `HudApp.client.luau`)
- `.luau` - Creates a ModuleScript - Use for Models, shared utilities, and react-luau HUD view components
- Folders become Folder instances in Roblox

### Directory Structure Recommendation

```
Source/
├── ServerScriptService/
│   ├── models/              # Game state (ModuleScripts)
│   │   ├── user/            # Per-player, persistent
│   │   ├── server/          # Global, ephemeral
│   │   ├── userEntities/    # Multiple per player
│   │   └── serverEntities/  # Multiple per server
│   ├── controllers/         # Business logic (Scripts)
│   └── services/            # Background tasks
│       ├── framework/       # Explicit order (Persistence, SlashCommand)
│       └── game/            # Auto-discovered (drop in & run)
├── ReplicatedFirst/
│   └── views/               # HUD (react-luau .luau) + workspace (.client.luau)
│       ├── components/      # Shared React UI components
│       └── hooks/           # Custom React hooks
│           ├── useBoltState.luau
│           ├── SpringSolver.luau
│           ├── useSpring.luau
│           ├── useSpringNumber.luau
│           ├── useTransition.luau
│           └── useDrag.luau
└── ReplicatedStorage/
    ├── Network.luau         # Intent/State/Actions definitions
    └── Config/              # Static game data (prices, rates, etc.)
```

## Testing and Development Workflow

### Quick Reference: When to Use MCP vs Play Mode

| Task | MCP (Edit Mode) | Play Mode (F5) |
|------|----------------|----------------|
| **Structural Setup** |
| Create workspace objects | ✓ | |
| Set attributes on objects | ✓ | |
| Insert marketplace models | ✓ | |
| Verify object hierarchy | ✓ | |
| **Code & Script Testing** |
| Test server scripts | ✓ | ✓ |
| Test client scripts (LocalScripts) | ✗ | ✓ |
| Test module initialization | ✗ | ✓ |
| Debug print statements | ✓ (server only) | ✓ (all) |
| **UI & Interaction** |
| Create UI elements | ✓ | |
| Test UI rendering | ✗ | ✓ |
| Test button clicks | ✗ | ✓ |
| Test UI animations | ✗ | ✓ |
| **Gameplay & Events** |
| Test player join logic | ✗ | ✓ |
| Test player movement | ✗ | ✓ |
| Test collision events | ✗ | ✓ |
| Test RemoteEvents/Functions | ✗ | ✓ |

### Development Iteration Patterns

#### Pattern 1: Structural Setup (Use MCP)
```
1. Ask Claude to create workspace objects via MCP
2. Ask Claude to set attributes via MCP
3. Ask Claude to verify structure via MCP
4. Move to Pattern 2 or 3 for testing
```

#### Pattern 2: Client Behavior Testing (Use Play Mode)
```
1. Write client code in src/client/
2. Press F5 in Studio to enter Play mode
3. Check Output window for print statements
4. Verify UI rendering and interactions
5. Exit Play mode, adjust code, repeat
```

#### Pattern 3: Hybrid Workflow (Use Both)
```
1. Use MCP to verify objects exist and have correct attributes
2. Use Play mode to test actual behavior
3. Use MCP to check Output window for errors
4. Iterate
```

### Common Pitfalls and Solutions

**Pitfall**: Trying to test client scripts with MCP
- **Solution**: Always use Play mode (F5) to test LocalScripts

**Pitfall**: Forgetting to check attribute values before Play testing
- **Solution**: Ask Claude to verify attributes via MCP first

**Pitfall**: Not checking Output window during Play mode
- **Solution**: Keep Output window visible during all tests

### Best Practices

1. **Start with MCP for setup verification**: Check that objects exist and attributes are set correctly
2. **Use Play mode for actual testing**: Test all client behavior, UI, and gameplay with F5
3. **Add print statements liberally**: Use print() to debug initialization and event handling
4. **Keep Output window visible**: Watch for errors and print statements during Play mode
5. **Test incrementally**: After each change, verify it works before moving on
6. **Use MCP for quick sanity checks**: Between Play mode tests, verify structure with MCP

## Development Rules

### DO:
- Write all code in `src/` directories and sync via Rojo
- Create all UI and Workspace objects in Studio
- Commit code changes to git regularly

### DON'T:
- Try to sync Workspace or UI through Rojo
- Write code directly in Studio - always use your editor + Rojo
- Commit place files (`.rbxl`/`.rbxlx`) to git

## Error Handling Philosophy

**NEVER use fallbacks to hide configuration errors.**

### DO:
- Use `WaitForChild()` to wait for required objects to load
- Prefer `WaitForChild()` over `FindFirstChild()` — a hang or error is better than a silent nil failure
- Only use `FindFirstChild()` when the child's absence is a valid, intentional state (e.g. optional UI buttons, get-or-create patterns, internal diff algorithms)
- Throw clear errors when requirements aren't met
- Let the game break loudly if something is misconfigured

### DON'T:
- Add fallback values that hide missing or broken configurations
- Silently continue when required objects don't exist
- Use `warn()` and continue - use `error()` to stop execution
- Use `FindFirstChild()` as a lazy substitute for `WaitForChild()` on required children

**Why?** Configuration errors indicate broken dependencies. Hiding these with fallbacks makes bugs harder to find. Better to fail fast and fix the root cause.

## Troubleshooting

### My View Isn't Receiving State Updates

**Symptoms:** View listener never fires, UI doesn't update after model changes

**Common causes:**

1. **State property not registered**
   - Check: Is Network.State.YourModel registered in Network.luau?
   - Fix: Add `Network.State.YourModel = Bolt.RemoteProperty(defaultState)` in Network.luau
   - Example: Model name "Inventory" → `Network.State.Inventory`

2. **Observe() not called**
   - Check: Are you using Network.State.YourModel:Observe(callback)?
   - Fix: Use Observe() instead of OnClientEvent
   - Pattern: `Network.State.YourModel:Observe(function(data) ... end)`
   - Note: Observe() fires immediately with current value - no need to request initial state

3. **Wrong ownerId filtering**
   - Check: Are you filtering by ownerId when you shouldn't?
   - Fix: Bolt handles per-player filtering automatically for User-scoped models
   - See: StatusBarView.client.luau for example (no ownerId filtering needed)

4. **Model not syncing after changes**
   - Check: Do your model methods call `self:syncState()`?
   - Fix: Add `self:syncState()` after every property change

5. **Network module not loaded**
   - Check: Can you require Network.luau successfully?
   - Fix: Ensure Network.luau is in ReplicatedStorage and Rojo is syncing properly

### My Controller Isn't Receiving Intents

**Symptoms:** Button clicks don't trigger controller, OnServerEvent never fires

**Common causes:**

1. **Intent event not registered**
   - Check: Is Network.Intent.YourFeature registered in Network.luau?
   - Fix: Add `Network.Intent.YourFeature = Bolt.ReliableEvent("YourFeatureIntent")` in Network.luau
   - View should use: `Network.Intent.YourFeature:FireServer(...)`

2. **Network.Actions constant typo**
   - Check: Is the action string exactly matching?
   - Fix: Use Network.Actions constants in BOTH view and controller
   - Example: `Network.Actions.WeaponShop.PurchaseWeapon`

3. **Action not in ACTIONS table**
   - Check: Is the action constant mapped to a handler function?
   - Fix: Add to ACTIONS table: `[Network.Actions.Feature.Action] = handlerFunction`

4. **Controller not initialized**
   - Check: Is ControllerRunner creating your controller?
   - Fix: Ensure controller file is in `src/server/controllers/` and has proper structure

5. **Validation failing silently**
   - Check: Look for warn() statements in Output window
   - Fix: Add print() statements to track execution flow

### My Model Isn't Persisting

**Symptoms:** Data lost on server restart, player rejoin shows default values

**Common causes:**

1. **Model not calling syncState()**
   - Check: Do your model methods call `self:syncState()`?
   - Fix: PersistenceService triggers when syncState() is called - no sync means no save!

2. **Server-scoped model expecting persistence**
   - Check: Is your model using "Server" scope?
   - Fix: Only "User" scope models are persisted to DataStore
   - Server-scoped models are ephemeral by design

3. **DataStore not enabled in Studio**
   - Check: Game Settings → Security → Enable Studio Access to API Services
   - Fix: Enable this setting and PublishToRoblox first

4. **Properties not in _extractState()**
   - Check: Does AbstractModel._extractState() return all properties?
   - Fix: Ensure all public properties (without leading underscore) are included

### Type Checking Errors in Editor

**Symptoms:** Luau-lsp shows errors, red squiggles in VS Code

**Common causes:**

1. **Missing type exports**
   - Check: Did you export the type from Network.luau?
   - Fix: Add type exports if needed for additional type safety

2. **Wrong type annotation**
   - Check: Are you using the correct module path?
   - Fix: `Network.Actions.FeatureName.ActionName` for constants
   - Fix: Controller actions should use `action: string` type

3. **Type mismatch in function parameters**
   - Check: Does your typed parameter match the expected type?
   - Fix: Controller: `action: string`
   - Fix: View Observe callback: `function(data) ... end` (Bolt handles typing)

### CollectionService Tag Not Found (Workspace Views)

**Symptoms:** Workspace view setup never runs, tagged objects not found

**Note:** This section applies to workspace views only. HUD views use react-luau and do not use CollectionService tags.

**Common causes:**

1. **Tag not added in Studio**
   - Check: Select object in Explorer → View → Tags window
   - Fix: Add the exact tag name (case-sensitive!) to your Part/Model

2. **Tag name typo**
   - Check: Does TAG constant match Studio tag exactly?
   - Fix: Tags are case-sensitive: "CashMachine" ≠ "cashmachine"

3. **Instance not replicated to client**
   - Check: Is the tagged object in a client-visible location?
   - Fix: 3D objects must be in Workspace or another replicated container

### HUD View Not Rendering (react-luau)

**Symptoms:** Component doesn't appear, UI missing from screen

**Common causes:**

1. **Component not added to HudApp**
   - Check: Is the component required and rendered in `HudApp.client.luau`?
   - Fix: Add `require()` for your component and include it in the `React.createElement` tree

2. **useBoltState returns default value**
   - Check: Is Network.State.YourModel registered in Network.luau?
   - Fix: The hook will use the default you provide until the server sends real state

3. **Hook called conditionally or in wrong scope**
   - Check: React hooks must be called at the top level of a function component, never inside `if` blocks or loops
   - Fix: Move the `useBoltState` call to the top of the component function

4. **ModuleScript not returning a function**
   - Check: Does your view `.luau` file return a function component?
   - Fix: Ensure the file ends with `return YourComponent` (a function, not a table)

### "Attempt to Index Nil" Errors

**Symptoms:** Script errors, "attempt to index nil value"

**Common causes:**

1. **WaitForChild on wrong path**
   - Check: Print the parent to verify it exists first
   - Fix: Verify exact path in Explorer
   - Example: `ReplicatedStorage:WaitForChild("IntentActions")`

2. **Model.get() returning nil**
   - Check: Is the model initialized?
   - Fix: User-scoped models initialize on PlayerAdded - ensure player has joined
   - Fix: Server-scoped models need manual get: `Model.get("SERVER")`

3. **WaitForChild timeout / infinite yield**
   - Check: Does the child exist with that exact name in the correct location?
   - Fix: Verify the instance hierarchy and ensure the child is being created server-side before the client tries to access it

### General Debugging Tips

1. **Add print statements liberally**
   ```lua
   print("View initialized")
   print("Button clicked")
   print("Sending intent:", action)
   print("Controller received:", action, player.Name)
   print("Model updated:", self.property)
   ```

2. **Check Output window constantly**
   - Errors appear here
   - Warnings appear here
   - Your print statements appear here

3. **Use Studio's Script Analysis**
   - View → Script Analysis
   - Shows warnings and potential issues

4. **Test incrementally**
   - Add one feature at a time
   - Test after each addition
   - Don't add multiple components before testing

5. **Verify structure with MCP**
   - Ask Claude to check object hierarchy
   - Verify attributes are set correctly
   - Confirm Network.luau is synced to ReplicatedStorage

## Why This Approach?

### Benefits:
- **Version Control**: All code is tracked in git with full history
- **Editor Freedom**: Use your preferred editor with all its features
- **Studio Strengths**: Build UI and world content with Studio's visual tools
- **Clean Separation**: Clear boundary between code (git) and content (Studio)
- **Collaboration**: Team members can work on code without conflicts over place files
- **AI Integration**: Claude can access and modify code through MCP without touching place files
