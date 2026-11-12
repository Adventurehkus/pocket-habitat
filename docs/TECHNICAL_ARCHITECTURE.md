# Pocket Habitat — Technical Architecture

## Architecture principles

Pocket Habitat uses a Roblox client/server architecture. The server owns gameplay state, player progression, rewards, ownership, and persistence. The client provides input, presentation, UI, and feedback. Treat every client request and every client-supplied value as untrusted.

This document separates the **current source architecture** from the **target architecture**. A target design must not be described as implemented until it exists in source and is verified.

## Current source layout

The project uses a compact Rojo mapping rather than the older proposed Systems/Data/Network folder tree.

### Server modules

- src/server/ServerMain.server.lua — server startup and player lifecycle orchestration.
- src/server/HabitatManager.lua — per-server UserId-to-habitat-folder registry and allocation/removal helpers (not yet a complete spawn/restore lifecycle).
- src/server/WorldBuilder.lua — creates world instances beneath a supplied habitat folder; Run #32 removed the former init() API without updating ServerMain.
- src/server/ResourceManager.lua — resource node interactions and rewards.
- src/server/PlantManager.lua — plot interactions, planting, watering, and harvesting.
- src/server/EconomyManager.lua — inventory, Bells, spending, and upgrades.
- src/server/QuestManager.lua — quest state, objectives, and rewards.
- src/server/CreatureManager.lua — discovery checks and runtime creature instances.
- src/server/DataStoreManager.lua — player data loading, in-memory session table, and save behavior.

### Shared modules

- src/shared/Constants.lua — item, plant, creature, quest, and upgrade definitions.
- src/shared/PlantRules.lua — production plant/plot interaction validation.
- src/shared/EconomyRules.lua — production inventory and capacity validation.
- src/shared/PocketHabitat.spec.lua — TestEZ specifications for shared production rules.

### Client modules

- src/client/ProximityHandler.client.lua — client-side ProximityPrompt interaction wiring and remote invocation. Inspect current source for other client controllers before extending the client architecture.

### Project and tooling

- default.project.json — Rojo project mapping.
- rokit.toml and wally.toml — pinned toolchain and package dependencies.
- opencode.json — provider/model registry for the autonomous development pipeline.
- DevPackages — installed/vendored dependencies; do not edit or format dependency source.

## Current runtime architecture and known limitations

Run #32 committed checkpoint `1af27d2aade0922f57ec4333bf5d5331366d7b9b`. Its static checks passed, but no Roblox runtime/Studio test ran. The current source is not verified playable and has a source-confirmed server-startup blocker. See `project-state/run-32-audit.md` for the complete issue register.

Current source facts:

- `HabitatManager` creates a Workspace.Habitats folder and tracks `Habitat_<UserId>` folders in a per-server table. It sets a BaseOffset attribute and exposes allocate/get/remove functions. It does not spawn characters, handle CharacterAdded, restore saved plot/world state, or use a collision-free slot allocator.
- `ServerMain.server.lua` still invokes `WorldBuilder.init()`, but the current `WorldBuilder.lua` defines only `buildHabitat(folder, owner)`. This is a P0 startup API mismatch: execution is expected to fail at that call before subsequent system initialization and player lifecycle connections. The old WorldBuilder version had init(); Run #32 removed it and failed to update the caller.
- The current BaseOffset formula advances by 0.1 studs along the X=Z diagonal for UserId modulo 1000. Each baseplate is 100×100 studs, so habitats overlap heavily and positions repeat. Some geometry adds offsets twice (tree leaves, berries, plot borders); paths use world origin inconsistently.
- `ServerMain` allocates a habitat after data load and calls `HabitatManager.removeHabitat` on PlayerRemoving. The allocation does not receive the loaded data. There is no character spawn/respawn placement.
- `ResourceManager` now stores cooldowns by UserId and node ID, which removes the old single global cooldown table. However, the remote accepts a nodeId and derives a static template position instead of validating an exact resource Instance in the caller's registered habitat. Missing habitat lookup falls back to zero offset. The cooldown is set before the reward is granted, so an inventory-full failure still starts the cooldown.
- `PlantManager` validates player data and numeric plot interaction rules, but does not resolve the actual plot Instance beneath the caller's habitat or check server-measured distance. Client calls can invoke remotes directly. Effect positions use fixed unoffset coordinates.
- `ProximityHandler.client.lua` listens for habitat folders and scans prompts. The global ChildAdded path is not filtered to the LocalPlayer's own habitat and may scan before descendant prompts are added. The separate LocalPlayer helper is only called from a Players.PlayerAdded listener; there is no unconditional initial lookup when the LocalScript starts after the local Player exists.
- `CreatureManager` runtime state and movement are still not fully player/habitat-scoped; inspect the current module before modifying it.
- `DataStoreManager` still uses GetAsync/SetAsync and an in-memory activeSessions table. There is no atomic cross-server UpdateAsync lease/token. Its removeSession path clears activeSessions after calling save even when save retries fail, so the only in-memory copy can be discarded after a failed final save.
- Run #32 changed source, but did not execute TestEZ, Roblox engine/Studio, multiplayer, DataStore integration/stress, or manual tests. A generated .rbxl file is not runtime verification.

Run #32 QA reported QA_BLOCKER: NO but missed the startup API mismatch and asserted that offset placement and spawning were complete. Those claims are contradicted by source. Its review also reported some stale findings: final ServerMain does include PlayerRemoving habitat-folder cleanup and final ProximityHandler uses Players.PlayerAdded (not LocalPlayer.PlayerAdded). The real remaining prompt issue is the startup/ownership/descendant race described above.

Re-check all facts against the current source before making changes. The canonical source audit and ordered repair plan are in `project-state/run-32-audit.md`.

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

The existing data key is PocketHabitat_v2_PlayerData. Preserve compatibility.

The target session protocol must use an atomic UpdateAsync operation to acquire an owner token and expiring lease. Each live server has a unique session token. Saves must confirm that token/lease ownership inside an atomic update; stale servers must not overwrite a newer session. Lease renewal and release must verify the token. Use bounded retry/backoff and distinguish:
- A successfully read missing key (new player).
- A successfully read valid existing record.
- A malformed/incompatible record.
- A read request failure or throttling.
- A lock held by another live session.
- A lost/expired lease.
- A failed save/release operation.

Only the first case may initialize default player data. Add explicit schema validation and migrations; never serialize Roblox Instances or other non-serializable runtime objects.

## Remote and interaction boundaries

- Roblox supplies Player automatically as the first OnServerInvoke callback argument for RemoteFunction:InvokeServer calls. Do not send LocalPlayer as an ordinary client argument.
- Roblox supplies Player automatically as the first OnServerEvent callback argument for RemoteEvent:FireServer calls.
- ProximityPrompt.Triggered provides playerWhoTriggered. Use the event signature and validate the request on the server.
- Validate types, ranges, session, ownership, target ancestry/registry membership, server-measured distance, cooldown, request rate, inventory, and current gameplay state before mutation.
- Client UI, hidden prompts, attributes, or local state are never authorization.

## Test boundaries

Pure shared rules should be tested directly through their production modules. External Roblox services and engine Instances should be isolated behind narrow adapters so service boundaries can be mocked without mocking the gameplay rules themselves.

TestEZ specifications exist for PlantRules and EconomyRules, but they have not been executed by a compatible Roblox/TestEZ runner. Run #32 passed Rojo, StyLua, and Selene only; it did not run Roblox engine, Studio, multiplayer, or DataStore integration tests. Never report those as passing without actual evidence.