# Pocket Habitat — Technical Architecture

## Architecture principles

Pocket Habitat uses a Roblox client/server architecture. The server owns gameplay state, player progression, rewards, ownership, and persistence. The client provides input, presentation, UI, and feedback. Treat every client request and every client-supplied value as untrusted.

This document separates the **current source architecture** from the **target architecture**. A target design must not be described as implemented until it exists in source and is verified.

## Current source layout

The project uses a compact Rojo mapping rather than the older proposed Systems/Data/Network folder tree.

### Server modules

- src/server/ServerMain.server.lua — server startup and player lifecycle orchestration.
- src/server/CharacterSpawner.lua — post-load character spawn/restore and validated respawn requests.
- src/server/HabitatManager.lua — per-server UserId-to-habitat-folder registry and allocation/removal helpers (not yet a complete spawn/restore lifecycle).
- src/server/WorldBuilder.lua — provides `init()` for the ServerMain startup path and creates world instances beneath each supplied habitat folder.
- src/server/ResourceManager.lua — resource node interactions and rewards.
- src/server/PlantManager.lua — plot interactions, planting, watering, and harvesting.
- src/server/EconomyManager.lua — inventory, Bells, spending, and upgrades.
- src/server/QuestManager.lua — quest state, objectives, and rewards.
- src/server/CreatureManager.lua — discovery checks and runtime creature instances.
- src/server/DataStoreManager.lua — player data loading, in-memory session table, and save behavior.

### Shared modules

- src/shared/Constants.lua — item, plant, creature, quest, and upgrade definitions.
- src/shared/CharacterSpawnData.lua — DataStore-safe spawn vector encoding and validation.
- src/shared/PlantRules.lua — production plant/plot interaction validation.
- src/shared/EconomyRules.lua — production inventory and capacity validation.
- src/shared/QuestRules.lua — validated player quest-action counters, objective progress, and quest ordering.
- src/shared/HabitatRules.lua — expansion-level validation, unlocked plot counts, and plot-data partitioning shared by persistence, habitat construction, and plant interaction rules.
- src/shared/PocketHabitat.spec.lua — TestEZ specifications for shared production rules.
- src/shared/Tests/CharacterSpawn.spec.lua — TestEZ specifications for spawn defaults and coordinate serialization.

### Client modules

- src/client/ProximityHandler.client.lua — client-side ProximityPrompt interaction wiring and remote invocation. Inspect current source for other client controllers before extending the client architecture.
- src/client/CharacterManager.client.lua — requests server respawn after the local Humanoid dies.

### Project and tooling

- default.project.json — Rojo project mapping.
- rokit.toml and wally.toml — pinned toolchain and package dependencies.
- opencode.json — provider/model registry for the autonomous development pipeline.
- DevPackages — installed/vendored dependencies; do not edit or format dependency source.

## Current runtime architecture and known limitations

The Run #40 cycle-1 recovery entry reports independent review, QA, and deterministic validation passed for the historical character-lifecycle, persistence, shutdown, and cooldown source repairs. This continuation adds a separate quest-progression slice that still awaits pipeline review/QA. Static checks do not prove Roblox server, network, or DataStore behavior; Roblox runtime verification remains outstanding.

Current source facts:

- `ServerMain.server.lua` disables `Players.CharacterAutoLoads` before loading modules, initializes resource/plant/quest handlers, acquires saved player data before allocating a habitat, and only then spawns/restores a character and sends session data.
- Its `BindToClose` cleanup passes one absolute 25-second deadline through player cleanup and synchronous release attempts instead of first running the ordinary retry path. When `PlayerRemoving` cleanup is already in progress, shutdown waits only until that deadline and retries release if cleanup completes; a yielding DataStore request itself cannot be cancelled. This source behavior has not been verified in Roblox.
- `CharacterSpawner` loads with `Player:LoadCharacterAsync()`, validates saved position against the assigned habitat bounds, and tracks position/orientation in session memory. The client requests respawn on local Humanoid death; the server requires an active session and habitat, a dead/absent character, a request interval, cooldown, and no active respawn.
- `DataStoreManager` uses the existing `PlayerDataStoreV1` store and `player_<UserId>` keys. `loadPlayerData` atomically acquires an owner-token lease through `UpdateAsync`; a lease lasts 300 seconds and renews with current session data every 120 seconds. Saves and releases verify the stored owner token, and release clears the lease only after persistence succeeds. After a transient release failure, the in-memory session is retained and up to three release-only retries are scheduled at 5, 15, and 30 seconds; a departing session is not renewed indefinitely. During `BindToClose`, `ServerMain` passes the absolute shutdown deadline into cleanup and release instead of running ordinary retries first. If release fails or the deadline expires, the persistent lease may expire; runtime behavior remains unverified. Failed loads, live foreign leases, malformed records, user-id mismatches, and future schema versions fail closed. Legacy `currency` and spawn-vector representations are normalized to the active gameplay data shape.
- `resourceCooldowns` is an optional, backward-compatible per-player map of node IDs to integer Unix ready times. `ResourceRules` validates the map and resolves readiness; its `tryGrantReward` helper owns the reserve/reward/rollback transaction and is called by `ResourceManager`. The TestEZ spec now exercises that production helper for rejected rewards and nodes still on cooldown, but has not run because no compatible runner is installed. Gathering also applies a 0.25-second per-player request throttle. The cooldown reaches persistent storage on the next periodic renewal or final release, so a crash before that write can lose recent cooldown changes.
- `characterSpawnData` remains a pair of `Vector3` values in memory and is encoded as `{x, y, z}` numeric tables before DataStore writes. Orientation is stored/restored as Euler angles; older unit look-vector values are migrated. Saved coordinates are bounded to the player's habitat on restoration. The current design does not save Roblox Instances.
- `getSession` returns no data when a player has no active loaded session; it does not manufacture a mutable default session. New sessions use the live gameplay schema, including four plots, quest state, discovery state, Bells, inventory, and upgrades.
- The initial session sync includes `playerData`; the client also accepts direct gameplay data syncs from economy and interaction modules.
- `HabitatManager` tracks per-server player habitat slots, offsets each habitat, and exposes the server-owned habitat lookup used by interactions.
- `ResourceManager` and `PlantManager` register remote handlers in `init()` and validate player session, habitat membership, and server-measured distance. Resource gathering also requires a living Humanoid and uses saved per-player cooldowns. `QuestManager.init()` owns the claim callback.
- `QuestRules` persists validated action counters in the player session. Gathering, planting, watering, harvesting, discovery, and upgrades record progress only after server-authoritative actions; quest claims validate those counters or the authoritative discovered-creature/upgrade state. `Constants.QUEST_ORDER` includes all ten quests, and session normalization advances legacy players with a nil/completed current quest to their next incomplete quest. The first-creature quest grants the seed required by the later Sun Petal quest. Item capacity is validated before the non-yielding Bells/inventory/claim-state mutation, preventing a repeated claim after a partial grant.
- Upgrade quest-progress values are restricted to defined upgrade IDs and their configured maximum levels, both when loading stored progress and when mutating it. Resource gathering suppresses the inventory helper's intermediate sync and sends the client snapshot only after quest progress is recorded, keeping the visible inventory/progression update coherent.
- `WorldBuilder` builds per-habitat geometry and restores saved plot plant visuals and basic growth/water state from the loaded session. Full upgrade effects and runtime Roblox restoration remain unverified.
- `EconomyManager.init()` owns the `PurchaseUpgrade` RemoteFunction handler. Plot expansion creates a prompt-enabled plot in the player's registered habitat, restores any archived plant state, and commits Bells, upgrade level, quest progress, and active plot data only after world construction succeeds. `PlantRules` rejects indices beyond the unlocked level. Storage expansion changes inventory capacity. Watering-can purchases are enabled and its validated level reduces dewdrop use by charging once per one, two, or three water actions at levels one, two, or three; the plot's persisted `waterCount` determines the next charge. Decorative-tile purchases remain unavailable until the visual effect is implemented.
- `DataStoreManager` imports `Constants` at module initialization with `WaitForChild` and validates saved upgrade IDs/levels against definitions. It fills missing plot records for purchased expansions and preserves supported plots beyond the current unlocked count in `lockedPlots`; those records return to active plot data when unlocked. Duplicate entries and indices beyond the maximum supported plot count fail closed rather than discarding saved state.
- `CreatureManager` scopes runtime instances and movement to each player's habitat and restores discovered creature types from the session; engine lifecycle and multiplayer isolation remain unverified.
- The latest quest and plot-expansion edits have not received a separate pipeline review/QA decision. No TestEZ runner, Roblox Studio/engine, multiplayer, or DataStore integration test has been executed. Current static checks pass; the generated `.rbxl` is only a Rojo build artifact.

Earlier run notes below are historical. The source currently uses `PlayerDataStoreV1`; prior documentation referring to `PocketHabitat_v2_PlayerData` did not match the implementation and must not be used to infer a second store or migration.

## Target player-owned habitat architecture

The desired architecture has one server-owned habitat runtime per player session.

### Ownership and registry

- The server creates an authoritative habitat record keyed by the Player.UserId obtained from Roblox's Player instance.
- The registry maps each user to exactly one active habitat runtime in that server.
- The habitat root and relevant descendants may expose OwnerUserId attributes for inspection, but attributes are metadata, not authorization. Server registries and server-side comparisons determine ownership.
- Clients never choose their own UserId, habitat owner, plot owner, resource owner, reward, or save key.
- All lookups begin from the server-supplied Player and resolve the target inside that player's registered habitat.

### Lifecycle

1. Player joins.
2. Server acquires cross-server save-session ownership.
3. Server loads, validates, and migrates saved data.
4. Server allocates the player's runtime habitat.
5. Server creates/restores its plots, resources, plants, upgrades, and discovered creatures.
6. Character spawns at that habitat.
7. Server validates and processes player interactions.
8. Session state is saved while the lease is valid.
9. On departure, the server performs a bounded final save, cleans runtime instances/connections, and releases session ownership.
10. BindToClose performs bounded work for remaining sessions.

Character respawns must reuse the existing habitat. A failed load or failed lock acquisition must not create a default save or a partially restored world.

### Resource subsystem

Resource node identity and availability are scoped to an owning habitat/session. A request resolves the node using the calling Player and server registry, then validates node identity, owner, character/root part, interaction distance, current cooldown, inventory capacity, and session state. Mutations and reward grants must be concurrency-safe and idempotent.

### Plant and plot subsystem

Each plot belongs to one habitat. Keep shared validation in PlantRules and extend it rather than duplicating rules in managers. Validate plot membership and ownership using the server registry. Persistent data stores serializable plot state only; runtime Instances and ProximityPrompts are reconstructed from validated data.

### Creature subsystem

Creature discovery progress is stored per player. Runtime instances and behavior loops are parented/scoped to that player's habitat. Registry keys include ownership and creature identity. Movement boundaries derive from the owning habitat rather than fixed global coordinates. Cleanup disconnects loops and destroys only the leaving player's runtime objects.

### Economy, quest, and upgrade subsystems

Economy operations validate finite integer quantities, ownership, balance, capacity, and item definitions. Multi-step reward/purchase operations are ordered or rolled back safely.

Quest progress comes from server-confirmed gameplay actions, not client-supplied counters or unreliable inference from current inventory. Claims are idempotent and persistent.

An upgrade can be purchased only when its effect is implemented. Its effect must be applied to the habitat/runtime and restored from save data on rejoin.

## Persistence architecture

The current source uses the `PlayerDataStoreV1` DataStore and `player_<UserId>` keys. Preserve that current source format unless a deliberate migration is designed and tested.

The implemented session protocol uses atomic UpdateAsync to acquire an owner token and expiring lease. Each server maintains a unique session token per player. Saves and renewals verify that token inside an atomic update; renewal occurs every 120 seconds for a 300-second lease, and release persists data before clearing the lock. Transient final-release failures receive up to three delayed release-only retries without renewing the departing lease; if another server has already acquired the key, the stale local session is discarded rather than written. After retries are exhausted, the in-memory session remains until process teardown and the stored lease can expire. A stale server must not overwrite a newer session. The implementation uses bounded transient renewal retries and distinguishes:
- A successfully read missing key (new player).
- A successfully read valid existing record.
- A malformed/incompatible record.
- A read request failure or throttling.
- A lock held by another live session.
- A lost/expired lease.
- A failed save/release operation.

Only the first case may initialize default player data. The current implementation rejects malformed records and future envelope schema versions, normalizes legacy fields, and encodes spawn coordinates as numeric tables. Broader schema validation/migration, injected DataStore failure tests, and Roblox runtime verification remain outstanding. Never serialize Roblox Instances or other non-serializable runtime objects.

## Remote and interaction boundaries

- Roblox supplies Player automatically as the first OnServerInvoke callback argument for RemoteFunction:InvokeServer calls. Do not send LocalPlayer as an ordinary client argument.
- Roblox supplies Player automatically as the first OnServerEvent callback argument for RemoteEvent:FireServer calls.
- ProximityPrompt.Triggered provides playerWhoTriggered. Use the event signature and validate the request on the server.
- Validate types, ranges, session, ownership, target ancestry/registry membership, server-measured distance, cooldown, request rate, inventory, and current gameplay state before mutation.
- Client UI, hidden prompts, attributes, or local state are never authorization.

## Test boundaries

Pure shared rules should be tested directly through their production modules. External Roblox services and engine Instances should be isolated behind narrow adapters so service boundaries can be mocked without mocking the gameplay rules themselves.

TestEZ specifications exist for PlantRules and EconomyRules, but they have not been executed by a compatible Roblox/TestEZ runner. Run #32 passed Rojo, StyLua, and Selene only; it did not run Roblox engine, Studio, multiplayer, or DataStore integration tests. Never report those as passing without actual evidence.