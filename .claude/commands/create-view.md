---
description: Create a new Roblox view with automatic pattern detection
allowed-tools: Bash(find, cat, grep, ls), Read, Write, Edit, Glob
model: sonnet
---

I'll guide you through creating a new Roblox view with automatic pattern detection (A, B, C, or B+C). This project has two distinct view types that follow different architectures.

## Project View Architecture

This project has **two types of views**:

### HUD Views (ScreenGui/UI) — react-luau components
- **File type**: ModuleScript (`.luau`) in `Source/ReplicatedFirst/views/`
- **Architecture**: React components mounted by `HudApp.client.luau` into a single ScreenGui
- **State observation**: `useBoltState` hook bridges Bolt RemoteProperty into React state
- **Modal coordination**: React state in HudApp (`activeModal` / `setActiveModal`)
- **Interactions**: `React.Event.Activated` on TextButton elements
- **Examples**: StatusBarView, FavoursView, CandlesView

### Workspace Views (3D parts/models) — imperative LocalScripts
- **File type**: LocalScript (`.client.luau`) in `Source/ReplicatedFirst/views/`
- **Architecture**: Imperative scripts using CollectionService to find tagged instances
- **State observation**: `Network.State.{Model}:Observe()` directly (no React)
- **Interactions**: ProximityPrompt.Triggered, ClickDetector, etc.
- **Examples**: BazaarView, CandleView, CashMachineView, ShrineView

### Three interaction patterns (apply to both types):
- **Pattern A**: Pure client-side feedback (particles, sounds, animations) — no server communication
- **Pattern B**: Intent-based with server validation (send actions to controllers via Network.Intent)
- **Pattern C**: State observation (observe model state changes via Network.State)
- **Pattern B+C**: Combination (send intents AND observe state)

## Reference Files

Before generating code, I will read these stable reference files to ensure accuracy:
- `Source/ReplicatedStorage/Network.luau` — Network configuration to validate controllers and states
- `Source/ReplicatedFirst/views/HudApp.client.luau` — HUD entry point (for wiring new HUD views)
- `Source/ReplicatedFirst/views/hooks/useBoltState.luau` — Custom hook for state in React views

## Interactive View Creation Wizard

Let's begin creating your view step by step!

### Step 1: View Name

What should your view be named?

**Requirements**:
- Must end with "View" (e.g., ShopView, StatusBarView, HealthBarView)
- Must use PascalCase (e.g., TreasureChestView)
- No underscores or special characters

**Examples**:
- ShopView — Manages shop UI interactions
- HealthBarView — Displays player health
- TreasureChestView — Handles treasure chest interactions

### Step 1.5: View Type

**Is this a HUD/UI view or a Workspace/3D view?**

| HUD View | Workspace View |
|---|---|
| ScreenGui elements (buttons, labels, frames) | 3D parts, models, ProximityPrompts |
| Rendered in PlayerGui overlay | Exists in Workspace |
| React component (ModuleScript `.luau`) | Imperative LocalScript (`.client.luau`) |
| Mounted by HudApp.client.luau | Runs standalone via CollectionService |
| Examples: StatusBarView, FavoursView, CandlesView | Examples: BazaarView, ShrineView, CandleView |

**View type** (HUD / Workspace):

---

## HUD View Path

*Only shown if view type is HUD*

### Step 2H: Modal or Always-Visible?

Is this view a **modal window** (opens/closes, only one at a time) or **always-visible** (like the status bar)?

**Modal examples**: FavoursView, CandlesView, ShopView, InventoryView
**Always-visible examples**: StatusBarView, HealthBarView, MinimapView

**Modal or always-visible?**:

### Step 3H: User Actions (Pattern B Detection)

Does this view need to send user actions to the server?

**Examples that send actions**:
- Shop UI with purchase buttons — Sends "BuyItem" to ShopController
- Equipment menu with equip buttons — Sends "EquipItem" to InventoryController

**Examples that DON'T send actions**:
- Status bar showing gold/treasure — Read-only display
- Favours panel — Only displays data

**Send user actions to server?** (Yes/No):

**If Yes**:

Which controller will handle these actions?

I will read Network.luau to validate this controller exists and show you available options.

**Controller name** (without "Controller" suffix):

**Action details**:

For each action this view will send:
1. **Action name** (e.g., "Purchase", "Equip", "Donate")
2. **What triggers it?** (button click, toggle, etc.)
3. **Parameters** (if any — name and type for each)

How many actions will this view send? (1-5):

[For each action, ask: Action name, trigger, parameters]

### Step 4H: State Observation (Pattern C Detection)

Does this view need to display or react to server state changes?

**Examples that observe state**:
- Status bar — Observes Inventory state to show gold/treasure
- Favours panel — Observes Favours state (UserEntity dictionary)

**Examples that DON'T observe state**:
- Pure cosmetic animation panel — No server data

**Observe server state?** (Yes/No):

**If Yes**:

Which model's state will this view observe?

I will read Network.luau to validate this state exists and show you available options.

**State name** (without "State" suffix):

**What is the model's scope?**

**IMPORTANT**: The state format depends on the model scope AND its syncScope:
- **User, syncScope="owner"** (default, e.g., InventoryModel) — Single state object, sent to owner only
- **User, syncScope="all"** (e.g., PowerUpModel) — Dictionary `{ [ownerId]: State }`, broadcast to all players. Index by `tostring(localPlayer.UserId)` to get the local player's state.
- **Server** (e.g., ShrineModel) — Single state object, broadcast to all
- **UserEntity** (e.g., FavoursModel) — Dictionary `{ [entityId]: State }`, sent to owner only
- **ServerEntity** (e.g., CandlesModel) — Dictionary `{ [entityId]: State }`, broadcast to all

**Model scope** (User/Server/UserEntity/ServerEntity):

**If User scope: Does it use syncScope="all"?** (Yes/No):

**Which properties from this state will you use?**

I will show you the available properties from Network.luau.

**Properties** (comma-separated):

### Step 4.5H: Animation Needs

Does this view need animation? (spring transitions, drag, number springs)

**Examples that use animation**:
- Currency display that rolls up/down — useSpringNumber
- Panel that slides in — useSpring on Position
- Modal with enter/exit animation — AnimatedModal wrapper + useTransition
- Draggable sticker or item — useDrag

**Needs animation?** (Yes/No):

**If Yes**:

Which animation hooks does this view need?

| Hook | Use case |
|---|---|
| `useSpring` | Animate properties (Position, Size, Transparency) toward targets with spring physics |
| `useSpringNumber` | Animate numeric displays (gold, health, score) — re-renders only when displayed digit changes |
| `useTransition` | Enter/exit animations for items appearing/disappearing, supports stagger via `trail` |
| `useDrag` | Make an element draggable with momentum and spring-back |

**Selected hooks** (comma-separated):

**Note**: If this is a **modal view** that needs enter/exit animation, use the `AnimatedModal` wrapper pattern in `Source/ReplicatedFirst/views/components/AnimatedModal.luau` rather than calling useTransition directly in the view.

### Step 5H: Props Definition

Based on the patterns detected, what props will this component receive from HudApp?

Note: If this is a **modal**, it will be wrapped in a `ModalWindow` component by HudApp. The view itself only receives its **body content props** (data to display).

If this is **always-visible**, it will be a direct child of the HudApp ScreenGui and receives its props directly.

### Step 6H: Review & Confirm

I'll display a comprehensive summary showing:
- View name and file location
- **View type**: HUD (react-luau component)
- **Modal/Always-visible** status
- **Detected Pattern**: A, B, C, or B+C with explanation
- Actions to send (if Pattern B)
- States to observe (if Pattern C) with model scope and state format
- Props definition
- HudApp wiring instructions

**Proceed with generation?** (Yes/No/Edit)

---

## Workspace View Path

*Only shown if view type is Workspace*

### Step 2W: CollectionService Tag

What CollectionService tag will this view target?

**Important**: This tag will be applied to instances in Roblox Studio. Tags are **case-sensitive**!

**Examples**:
- BazaarView — Tag: "Bazaar"
- ShrineView — Tag: "Shrine"
- CashMachineView — Tag: "CashMachine"

**Tag name**:

### Step 3W: Target Instance Type

What type of instance will be tagged?

**Common types**:
- **Part** — Single 3D part
- **Model** — Group of parts
- **Other** — Specify custom type

**Instance type**:

### Step 4W: User Actions (Pattern B Detection)

Does this view need to send user actions to the server?

**Examples that send actions**:
- Bazaar with proximity prompt — Sends "BuyTreasure" to BazaarController
- Shrine with donate prompt — Sends "Donate" to ShrineController

**Examples that DON'T send actions**:
- Candle spawner — Only observes state, spawns visuals

**Send user actions to server?** (Yes/No):

**If Yes**:

Which controller will handle these actions?

I will read Network.luau to validate this controller exists and show you available options.

**Controller name** (without "Controller" suffix):

**Action details**:

For each action this view will send:
1. **Action name** (e.g., "Purchase", "Donate", "Interact")
2. **What triggers it?** (ProximityPrompt, ClickDetector, touch, etc.)
3. **Parameters** (if any — name and type for each)

How many actions will this view send? (1-5):

[For each action, ask: Action name, trigger, parameters]

### Step 5W: State Observation (Pattern C Detection)

Does this view need to display or react to server state changes?

**Examples that observe state**:
- Bazaar — Observes Inventory to enable/disable prompt based on gold
- CandleView — Observes Candles (ServerEntity) to spawn/remove models
- Shrine — Observes Shrine state for donation feedback AND Inventory for afford check

**Examples that DON'T observe state**:
- One-shot particle effect — Just plays particles, no state to track

**Observe server state?** (Yes/No):

**If Yes**:

Which model's state will this view observe?

I will read Network.luau to validate this state exists and show you available options.

**State name** (without "State" suffix):

**What is the model's scope?**

**IMPORTANT**: The state format depends on the model scope AND its syncScope:
- **User, syncScope="owner"** (default, e.g., InventoryModel) — Single state object, sent to owner only
- **User, syncScope="all"** (e.g., PowerUpModel) — Dictionary `{ [ownerId]: State }`, broadcast to all
- **Server** (e.g., ShrineModel) — Single state object, broadcast to all
- **UserEntity** (e.g., FavoursModel) — Dictionary `{ [entityId]: State }`, sent to owner only
- **ServerEntity** (e.g., CandlesModel) — Dictionary `{ [entityId]: State }`, broadcast to all

**Model scope** (User/Server/UserEntity/ServerEntity):

**If User scope: Does it use syncScope="all"?** (Yes/No):

**Which properties from this state will you use?**

**Properties** (comma-separated):

### Step 6W: Immediate Feedback (Pattern A Detection)

Does this view need immediate visual or audio feedback (particles, sounds, animations)?

**Examples**:
- Particle burst when clicking a button
- Sound effect on proximity prompt trigger
- Tween animation on shrine surface GUI

**Immediate feedback?** (Yes/No):

**If Yes**:
- **Feedback types**: particles, sound, tween, other (comma-separated)
- **When triggered**: (e.g., "on proximity prompt", "when state changes")

### Step 7W: Expected Children

What child instances does this view expect to find under the tagged instance?

**Important**:
- The ROOT instance gets the CollectionService tag
- Children are accessed by name using WaitForChild()
- Names must match EXACTLY (case-sensitive)

For each child:
1. **Child name** (exact name as it will appear in Studio)
2. **Child type** (ProximityPrompt, Sound, ParticleEmitter, Part, etc.)

**How many children?** (0-10):

[For each child, ask: name and type]

### Step 8W: Review & Confirm

I'll display a comprehensive summary showing:
- View name and file location
- **View type**: Workspace (imperative LocalScript)
- CollectionService tag and instance type
- **Detected Pattern**: A, B, C, or B+C with explanation
- Actions to send (if Pattern B)
- States to observe (if Pattern C) with model scope and state format
- Immediate feedback (if Pattern A)
- Expected hierarchy with children
- Studio setup requirements

**Proceed with generation?** (Yes/No/Edit)

---

## Implementation Details (Internal)

When generating the view, I will:

### 1. Read Reference Files

Use Read tool on:
- **Network.luau** to:
  - Validate controller exists in NetworkConfig.Controllers
  - Validate state exists in NetworkConfig.States
  - Extract available actions for the controller
  - Extract available properties for the state
  - Generate type-safe Network.Actions and Network.State references
- **HudApp.client.luau** (HUD path only) to:
  - Understand current wiring of existing views
  - Determine where to add the new view require and element

### 2. Pattern Detection

Determine pattern based on user responses:

```lua
if (sendsActions AND observesState):
    pattern = "B+C" -- Combination
    description = "Sends intents to controller AND observes model state"
elif (sendsActions):
    pattern = "B" -- Intent-Based
    description = "Sends intents to controller for server validation"
elif (observesState):
    pattern = "C" -- State Observation
    description = "Observes model state changes and updates UI"
else:
    pattern = "A" -- Pure Client-Side
    description = "Pure client-side feedback with no server communication"
```

### 3. Generate View File

#### HUD View — React Component

**Location**: `Source/ReplicatedFirst/views/{ViewName}.luau` (ModuleScript, NOT `.client.luau`)

**Template**:

```lua
--!strict

--[[
    {ViewName}

    Pattern: {DetectedPattern}
    Purpose: {HighLevelDescription}

    Props:
        {propName}: {propType}
        ...
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

{If Pattern C and state is consumed directly in this component (not passed as props):}
local useBoltState = require(script.Parent:WaitForChild("hooks"):WaitForChild("useBoltState"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

{If Pattern B:}
local Network = require(ReplicatedStorage:WaitForChild("Network"))
local {controller}Intent = Network.Intent.{Controller}

export type Props = {
    {propName}: {propType},
    ...
}

local function {ViewName}(props: Props)
    {If Pattern C with useBoltState:}
    local stateData = useBoltState(Network.State.{Model}, {defaultValue})

    {If Pattern B - button handler:}
    local function on{Action}()
        {controller}Intent:FireServer(Network.Actions.{Controller}.{Action}{, params})
    end

    return e("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, {
        {-- child elements}
    })
end

return {ViewName}
```

**If animation hooks are needed**, add the relevant imports and usage:

```lua
{If useSpring:}
local useSpring = require(script.Parent:WaitForChild("hooks"):WaitForChild("useSpring"))

-- In the component body:
local springProps = useSpring({
    Position = if isOpen then UDim2.new(0.5, 0, 0.5, 0) else UDim2.new(0.5, 0, 1.5, 0),
    BackgroundTransparency = if isOpen then 0 else 1,
}, {
    force = 200,
    dampening = 20,
})

-- Bind spring values directly to element properties:
return e("Frame", {
    Position = springProps.Position,
    BackgroundTransparency = springProps.BackgroundTransparency,
})

{If useSpringNumber — for currency/number displays:}
local useSpringNumber = require(script.Parent:WaitForChild("hooks"):WaitForChild("useSpringNumber"))

-- In the component body:
local displayGold = useSpringNumber(props.gold, {
    force = 120,
    dampening = 14,
})

return e("TextLabel", {
    Text = `Gold: {displayGold}`,
})
```

**Note**: Modal views that need enter/exit animation should follow the `AnimatedModal` pattern in `Source/ReplicatedFirst/views/components/AnimatedModal.luau` — this wrapper uses `useTransition` to manage mount/unmount animations and keeps the view mounted during the exit phase.

**After generating the component**, provide instructions to wire it into HudApp.client.luau:

**If modal view**:
1. Add `local {ViewName} = require(viewsFolder:WaitForChild("{ViewName}"))` to HudApp imports
2. Add a new `elseif activeModal == "{modalKey}" then` block in the modal content section
3. Wrap in `e(ModalWindow, { ... bodyContent = e({ViewName}, { ... }) })`
4. Add a toggle button to StatusBarView if needed

**If always-visible view**:
1. Add `local {ViewName} = require(viewsFolder:WaitForChild("{ViewName}"))` to HudApp imports
2. Add `{ViewName} = e({ViewName}, { ... })` as a child of the ScreenGui element

#### Workspace View — Imperative LocalScript

**Location**: `Source/ReplicatedFirst/views/{ViewName}.client.luau` (LocalScript)

**Template**:

```lua
--!strict

--[[
    {ViewName}

    Pattern: {DetectedPattern}
    Purpose: {HighLevelDescription}

    {If Pattern B:}
    Sends Intents:
      - Network.Intent.{Controller}:FireServer(Network.Actions.{Controller}.{Action}, params...)

    {If Pattern C:}
    Observes State:
      - Network.State.{Model}:Observe() - Updates when {properties} change

    Expected Hierarchy:
    {RootInstanceType} [{RootInstanceName}] (Tagged: "{TagName}")
    {For each child:}
    +-- {ChildName} ({ChildType})
    {End for}

    Studio Setup:
    1. Create {RootInstanceType} in Workspace
    2. Add children: {ChildNames}
    3. Apply CollectionService tag "{TagName}" to ROOT instance only
    4. Names must match exactly (case-sensitive)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
{If B:}local Players = game:GetService("Players")

{If B or C:}local Network = require(ReplicatedStorage:WaitForChild("Network"))

{If B:}local localPlayer = Players.LocalPlayer
{If B:}local {controller}Intent = Network.Intent.{Controller}
{If C:}local {model}State = Network.State.{Model}

local TAG = "{TagValue}"

{If A with constants:}local {CONSTANT_NAME} = {value}

local function setup{InstanceType}(instance: Instance)
    {For each child:}
    local {childName} = instance:WaitForChild("{ChildName}") :: {ChildType}

    {If B - connect interactions:}
    {trigger}.{Event}:Connect(function({eventParams})
        {If localPlayer check needed:}
        if {param} ~= localPlayer then
            return
        end

        {If A - immediate feedback:}
        -- Immediate visual/audio feedback
        {feedbackCode}

        -- Send intent to server
        {controller}Intent:FireServer(
            Network.Actions.{Controller}.{Action}{, params}
        )
    end)

    {If C - observe state:}
    {model}State:Observe(function(data: Network.{Model}State)
        -- Update visuals with state
        {updateCode}
    end)
end

for _, instance in CollectionService:GetTagged(TAG) do
    task.spawn(setupInstance, instance)
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
    task.spawn(setupInstance, instance)
end)
```

### 4. Pattern-Specific Code Examples

**HUD Pattern A — Pure Client Feedback:**
```lua
local function EffectView(props: Props)
    return e("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, {
        -- Animation or visual-only elements
    })
end
```

**HUD Pattern B — Intent-Based:**
```lua
local Network = require(ReplicatedStorage:WaitForChild("Network"))
local shopIntent = Network.Intent.Shop

local function ShopView(props: Props)
    local function onPurchase()
        shopIntent:FireServer(Network.Actions.Shop.BuyItem, itemId)
    end

    return e("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, {
        BuyButton = e("TextButton", {
            Text = "Buy",
            [React.Event.Activated] = onPurchase,
        }),
    })
end
```

**HUD Pattern C — State Observation:**
```lua
local useBoltState = require(script.Parent:WaitForChild("hooks"):WaitForChild("useBoltState"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local function HealthView(props: Props)
    local health = useBoltState(Network.State.Health, { current = 100, max = 100 })

    return e("Frame", {
        Size = UDim2.new(health.current / health.max, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 200, 0),
    })
end
```

**HUD Pattern B+C — Combination:**
```lua
local useBoltState = require(script.Parent:WaitForChild("hooks"):WaitForChild("useBoltState"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))
local shopIntent = Network.Intent.Shop

local function ShopView(props: Props)
    local inventory = useBoltState(Network.State.Inventory, { gold = 0 })

    local function onPurchase()
        shopIntent:FireServer(Network.Actions.Shop.BuyItem, itemId)
    end

    return e("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, {
        GoldLabel = e("TextLabel", {
            Text = `Gold: {inventory.gold}`,
        }),
        BuyButton = e("TextButton", {
            Text = "Buy",
            [React.Event.Activated] = onPurchase,
        }),
    })
end
```

**HUD Pattern C — UserEntity Scope (Dictionary):**
```lua
-- Props receive the dictionary from HudApp (which calls useBoltState at top level)
export type Props = {
    favoursData: { [string]: Network.FavoursState },
}

local function FavoursView(props: Props)
    local tiles = {}
    for entityId, data in props.favoursData do
        tiles[entityId] = e(FavourTile, {
            favourType = data.favourType,
        })
    end

    return e("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, tiles)
end
```

**Workspace Pattern A — Pure Client Feedback:**
```lua
local function setupPart(part: Instance)
    local proximityPrompt = part:WaitForChild("ProximityPrompt") :: ProximityPrompt
    local particleEmitter = part:WaitForChild("ParticleEmitter") :: ParticleEmitter
    local sound = part:WaitForChild("Sound") :: Sound

    proximityPrompt.Triggered:Connect(function(player: Player)
        if player ~= localPlayer then
            return
        end
        particleEmitter:Emit(20)
        sound:Play()
    end)
end
```

**Workspace Pattern B — Intent-Based:**
```lua
local function setupMachine(machine: Instance)
    local prompt = machine:WaitForChild("ProximityPrompt") :: ProximityPrompt

    prompt.Triggered:Connect(function(player: Player)
        if player ~= localPlayer then
            return
        end
        machineIntent:FireServer(Network.Actions.Machine.Activate)
    end)
end
```

**Workspace Pattern C — State Observation (ServerEntity Spawner):**
```lua
local candlesState = Network.State.Candles
local candleTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Candle")
local spawnedCandles: { [string]: Model } = {}

type CandlesStateDictionary = { [string]: Network.CandlesState }

local function spawnCandle(entityId: string, data: Network.CandlesState)
    if spawnedCandles[entityId] then
        return
    end
    local candle = candleTemplate:Clone() :: Model
    candle:PivotTo(CFrame.new(data.positionX, data.positionY, data.positionZ))
    candle.Parent = Workspace
    spawnedCandles[entityId] = candle
end

candlesState:Observe(function(allCandles: CandlesStateDictionary)
    for entityId, candleData in allCandles do
        spawnCandle(entityId, candleData)
    end
    for entityId, _ in spawnedCandles do
        if not allCandles[entityId] then
            spawnedCandles[entityId]:Destroy()
            spawnedCandles[entityId] = nil
        end
    end
end)
```

**Workspace Pattern B+C — Combination:**
```lua
local function setupBazaar(bazaar: Instance)
    local base = bazaar:WaitForChild("Base")
    local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
    local sound = base:WaitForChild("Sound") :: Sound

    proximityPrompt.Triggered:Connect(function(player: Player)
        if player ~= localPlayer then
            return
        end
        sound:Play()
        bazaarIntent:FireServer(Network.Actions.Bazaar.BuyTreasure)
    end)

    inventoryState:Observe(function(data: Network.InventoryState)
        proximityPrompt.Enabled = data.gold >= 200
    end)
end
```

### 5. Validation During Generation

Before finalizing:
- **Both types**: --!strict pragma at top of file
- **Both types**: Pattern matches user's stated needs
- **Both types**: Controllers and states validated against Network.luau
- **Both types**: Network.Actions constants used for type-safe action dispatch
- **Both types**: Type annotations include Network exported types
- **HUD**: Component is a function returning React elements
- **HUD**: Props type is exported
- **HUD**: useBoltState used correctly (not raw :Observe())
- **HUD**: React.Event used for button interactions (not .Activated:Connect)
- **HUD**: HudApp wiring instructions are complete and correct
- **HUD (animated)**: Verify animations play on state changes (spring targets update when observed state changes)
- **HUD (animated)**: Verify spring settles (no infinite oscillation — dampening must be > 0)
- **HUD (animated, drag)**: Verify `React.Event.InputBegan` fires on the drag target (bind `dragBind.onInputBegan`)
- **Workspace**: CollectionService used directly (NOT AbstractView)
- **Workspace**: GetTagged + GetInstanceAddedSignal pattern used
- **Workspace**: task.spawn wraps setup calls
- **Workspace**: All children accessed via WaitForChild with type annotations

### 6. Testing Instructions

After generation, provide:

#### HUD View Completion Output

```
View Generation Complete!

Created Files:
  Source/ReplicatedFirst/views/{ViewName}.luau

View Type: HUD (react-luau component)
Pattern Detected: {Pattern} ({PatternDescription})
Modal: {Yes/No}

{If Pattern B:}
Network Integration:
  Network.Intent.{Controller} — Bolt ReliableEvent for sending intents
  Network.Actions.{Controller}.{Action} — Type-safe action constants

{If Pattern C:}
Network Integration:
  Network.State.{Model} — Bolt RemoteProperty for state observation
  Network.{Model}State — Type definition for state data
  Observed via: useBoltState hook

HudApp Wiring Required:

  {If modal:}
  1. Add require to HudApp.client.luau imports:
     local {ViewName} = require(viewsFolder:WaitForChild("{ViewName}"))

  2. Add elseif block in modal content section:
     elseif activeModal == "{modalKey}" then
         modalElement = e(ModalWindow, {
             title = "{Title}",
             ...
             bodyContent = e({ViewName}, { ... }),
         })

  3. (Optional) Add toggle button to StatusBarView

  {If always-visible:}
  1. Add require to HudApp.client.luau imports:
     local {ViewName} = require(viewsFolder:WaitForChild("{ViewName}"))

  2. Add as child of ScreenGui in HudApp render:
     {ViewName} = e({ViewName}, { ... }),

  3. Pass required props from HudApp state

Testing:
  1. Start Play mode (F5)
  2. Check that the HUD renders without errors in Output
  {If modal:}
  3. Toggle the modal open/close
  4. Verify only one modal can be open at a time
  {If Pattern C:}
  3. Verify state updates render in the UI
  {If Pattern B:}
  3. Click action buttons and check server Output for controller processing

  {If animated:}
  3. Verify animations play on state changes (e.g., spring moves to new target)
  4. Verify spring settles — no infinite oscillation
  {If drag:}
  5. Verify InputBegan fires on the drag target (element should follow pointer)

Common Issues:

  "Component not rendering"
  - Check: Is it required in HudApp.client.luau?
  - Check: Is it added as a child element in the render function?
  - Check: Does the export type Props match what HudApp passes?

  "useBoltState returns default value"
  - Check: Is the Network.State.{Model} key correct?
  - Check: Has the model synced state to this player?

  {If Pattern B:}
  "Intent not working"
  - Check: Is Network.Intent.{Controller} correct?
  - Check: Are you using Network.Actions.{Controller}.{Action} constant?

  {If modal:}
  "Modal not opening"
  - Check: Is the activeModal key correct in the elseif block?
  - Check: Is onToggleModal being called with the right key?
```

#### Workspace View Completion Output

```
View Generation Complete!

Created Files:
  Source/ReplicatedFirst/views/{ViewName}.client.luau

View Type: Workspace (imperative LocalScript)
Pattern Detected: {Pattern} ({PatternDescription})

{If Pattern B:}
Network Integration:
  Network.Intent.{Controller} — Bolt ReliableEvent for sending intents
  Network.Actions.{Controller}.{Action} — Type-safe action constants

  Actions this view sends:
    {For each action:}
    - {ActionName}({parameters})

{If Pattern C:}
Network Integration:
  Network.State.{Model} — Bolt RemoteProperty for state observation
  Network.{Model}State — Type definition for state data

  Properties observed: {propertyList}

Studio Setup Requirements:

  IMPORTANT: Follow these steps EXACTLY in Roblox Studio

  1. Create the root instance
     - Type: {RootInstanceType}
     - Location: Workspace
     - Name: {SuggestedName} (or any name you prefer)

  2. Add required children

     Expected hierarchy:
     {RootInstanceType} [{ExampleName}]
     {For each child:}
     +-- {ChildName} ({ChildType})
     {End for}

     Child names must match EXACTLY (case-sensitive!)

  3. Apply CollectionService tag
     - Open Tags window: View > Tags (or press Alt+T)
     - Select the ROOT instance only ({RootInstanceType})
     - Add tag: "{TagName}"
     - Tag is case-sensitive! Must be exactly "{TagName}"
     - DO NOT tag the children, only the root instance

  4. Save and test
     - Save the place
     - Start Play mode (F5)
     - Check Output window for:
       "{ViewName}: Initialized"

Testing:
  1. Verify the view initializes (check Output for print message)
  2. Verify tagged instances are found

  {If Pattern B:}
  3. Trigger the action (proximity prompt, click, etc.)
  4. Check server Output for controller processing

  {If Pattern C:}
  3. Change the model state from server
  4. Verify visuals update automatically

  {If Pattern A:}
  3. Trigger the feedback (click, proximity, etc.)
  4. Verify particles, sounds, or animations play

Common Issues:

  "View not initializing"
  - Check: Is the tag spelled exactly "{TagName}"? (case-sensitive)
  - Check: Is the tag on the ROOT instance, not children?
  - Check: Did you save the place after adding the tag?

  "WaitForChild timeout error"
  - This is INTENTIONAL — it means hierarchy is incorrect
  - Check: Do child names match exactly? (case-sensitive)
  - Check: Are children actually present under the tagged instance?

  {If Pattern B:}
  "Intent not working"
  - Check: Is the controller initialized? (check server Output)
  - Check: Are you using Network.Actions.{Controller}.{Action} constant?

  {If Pattern C:}
  "State not updating"
  - Check: Is the model initialized? (check server Output)
  - Check: Is the model calling syncState() after changes?
  - Check: Is Network.State.{Model} available? (check client Output)

  "Observe fires but nothing happens" (Entity-scoped models)
  - Check: Is this a UserEntity or ServerEntity scoped model?
  - Fix: Entity-scoped models send { [entityId]: State } dictionary, not single object
  - Fix: Iterate the dictionary: for entityId, data in allEntities do ... end

  "Observe fires but shows wrong player's data" (User + syncScope="all" models)
  - Fix: User+all models send { [ownerId]: State } dictionary to ALL players
  - Fix: Index by local player: local myState = data[tostring(localPlayer.UserId)]
```

---

## Important Reminders

- Views run on CLIENT — display and feedback only
- NEVER trust client data — server always validates
- Use Network.Actions constants, not magic strings
- **HUD views**: React components (.luau ModuleScripts), wired into HudApp
- **Workspace views**: Imperative LocalScripts (.client.luau), use CollectionService directly
- AbstractView has been removed — do NOT reference it
- Modal coordination is handled by React state in HudApp, not tags

---

## Let's Start!

Please provide the following information to begin:

**1. View Name** (must end with "View"):

**1.5. View Type** (HUD or Workspace):
