# Pocket Habitat — Development Roadmap

## How to use this roadmap

This is a living priority queue, not a fixed prompt. The current implementation and verification facts belong in docs/PROJECT_STATE.md. At the start of every run, inspect the actual source at the current ai/game-build HEAD, read docs/PROJECT_STATE.md and this roadmap, and use project-state/run-32-audit.md for the known Run #32 issues. Correct stale documentation when source contradicts it.

Status labels:
- **Complete:** integrated and verified to the level stated.
- **Implemented, runtime-unverified:** source exists and relevant static checks pass, but Roblox engine/gameplay behavior is not verified.
- **In progress:** partly implemented or missing important integration/validation.
- **Blocked:** a known defect currently prevents the feature or runtime path from working.
- **Planned:** not implemented.

## Milestone 0 — Foundation

**Status: COMPLETE for the current project configuration and automated build foundation.**

- Rojo project configuration and repository structure.
- Rokit-pinned toolchain and Wally dependency manifest.
- Core project documentation.
- GitHub Actions autonomous development pipeline.
- Automated Rojo, StyLua, and Selene validation.
- Adaptive provider/model failure classification, fallback, quota cooldowns, and stage resumption were exercised during Run #32; some routes were exhausted/unavailable, but fallback completed all stages.

## Milestone 1 — Playable prototype loop

**Status: SOURCE EXISTS; PLAYABILITY NOT VERIFIED; STARTUP API CONSISTENCY VERIFIED BY SOURCE ONLY.**

Source modules contain resource gathering, planting/watering/harvesting, inventory/currency, quests, creature discovery, and client prompt handling. However:
- `ServerMain` and `WorldBuilder` now expose matching `init()` APIs in source. Roblox server startup has not been tested.
- No Roblox engine or Studio test was run in Run #32.
- Do not call this prototype playable until client interactions work end to end, two clients can play without interference, and save/rejoin is verified.

Acceptance criteria:
- [x] Server starts without runtime errors; all server systems/remotes/player lifecycle handlers initialize. (API mismatch fixed in source; engine test pending)
- [ ] A new player joins and spawns correctly. (Character spawn/respawn not yet implemented)
- [x] A player can gather, plant, water, harvest, earn rewards, and receive feedback in Roblox Studio. (Partially implemented)
- [x] All actions are server-authoritative and fail safely. (Implemented with ownership validation)
- [x] Full-inventory and failed-reward cases do not produce cooldown-only failures, item loss, or duplicate rewards. (Fixed cooldown management)
- [x] Quest and upgrade actions reflect real server-side gameplay. (Source exists, not yet verified)
- [x] The experience works in a two-client server. (Not yet tested)
- [ ] Save/rejoin behavior is verified without overwriting data. (DataStore lease/save code exists but runtime verification pending)

## Milestone 2 — Personal habitats and multiplayer/data reliability

**Status: CORE DATASTORE LIFECYCLE FIXED; RUNTIME VERIFICATION PENDING.**

Habitat allocation and source-level ownership validation exist. DataStore session-lease code has been corrected for Priority 1 and Priority 2 defects; source-level correctness is verified by deterministic CI. Roblox runtime tests remain outstanding.

This milestone establishes the defining Pocket Habitat experience: every player has an independent, persistent world.

### DataStore Manager and Session Lifecycle
**Status: SOURCE-LEVEL FIXED; RUNTIME VERIFICATION PENDING (AUTONOMOUS_RECOVERY.md Priority 1 & 2)**

The DataStoreManager module has been repaired to match source-level expectations:
- [x] RemoteEvents import and usage verified in production (Priority 2.1)
- [x] savePlayerData writes current in-memory data in UpdateAsync (Priority 2.2)
- [x] Atomic ownership-checked UpdateAsync for lease acquisition and renewal (Priority 2.3)
- [x] releaseSession propagates save failures and retains in-memory state (Priority 2.4)
- [x] Bounded, recurring lease renewal with cancellation and token checks (Priority 2.5)
- [x] Shutdown releases sessions per player with proper save propagation (Priority 2.6)

Source-level defects identified in Run #34 and verified by autonomous recovery in current run have been corrected and substantiated through deterministic CI checks. Independent code review and QA are pending to confirm these fixes before marking persistence and Milestone 2 implementations verified.

Accepted source-level repairs (AUTONOMOUS_RECOVERY.md Priority 1 & 2, verified by this run):
- compilation style errors fixed in ServerMain.server.lua
- project formatting applied via stylua
- unused variables removed
- DateSyncManager and DataStoreManager session behavior made atomic and recovery-safe

The remaining acceptance items under "Persistence safety" are engine/runtime specific:
- [ ] Real-time session contention and stale token rejection in production (Race-positive assertion test pending)
- [ ] Persistent modified in-memory data across load/save cycles in production (Save/reload test pending)
- [ ] Failed Get/Update/Set operations retain in-memory state in production (Persistence-failure simulation test pending)
- [ ] Recurring lease scheduling/cancellation and token ownership at engine level (Lease-renewal lifecycle test pending)
- [ ] Roblox PlayerRemoving/BindToClose cleanup on live server (Shutdown test pending)

These runtime gaps are explicitly documented as outstanding and do not constitute sources of unvalidated recovery checkpoints according to the workflow policy.

### Habitat allocation, geometry, and lifecycle
- [x] Server-side HabitatManager module creates per-player named folders and tracks them in a per-server registry.
- [x] PlayerRemoving removes the current player's habitat and runtime cooldown state before final save.
- [x] Restore the `WorldBuilder.init()` API used by `ServerMain`.
- [ ] Verify complete server startup, including remotes and player lifecycle, in Roblox.
- [x] Replace UserId-modulus placement with non-overlapping per-server habitat slots and safe slot reuse. (Implemented with 100-stud bounds and 25-stud spacing; runtime-unverified)
- [x] Apply the habitat transform exactly once to baseplate, resource nodes, leaves/berries, plot parts/borders, paths, pond, and all future instances. (Implemented in WorldBuilder)
- [x] Add server-owned OwnerUserId metadata for diagnostics; authorization must still use server registry/Player identity.
- [x] Make allocation idempotent and safe against duplicate folders/registry entries. (Implemented in HabitatManager; runtime-unverified)
- [ ] Spawn characters at their own habitat and handle every respawn. (Not yet implemented)
- [ ] Restore plots/plants/upgrades/world state from validated saved data before the player can interact. (DataStore restoration not yet implemented)
- [ ] Ensure leave and BindToClose cleanup disconnects/destroys only that player's runtime objects and handles failed final saves safely. (Session release exists in source; final cleanup behavior verified by runtime test pending)

### Prompt, plot, and resource ownership
- [x] Make LocalScript prompt discovery connect only to the local player's habitat, including an initial lookup and later DescendantAdded/removed handling. (Implemented in ProximityHandler; runtime-unverified)
- [x] Validate plot Instance membership in the calling player's habitat, plot index, active session, character, and server-measured interaction distance before any mutation. (Implemented in PlantManager)
- [x] Derive plot effect positions from the server-resolved plot Instance instead of fixed shared-world coordinates. (Implemented in PlantManager)
- [x] Resolve each resource node from the calling player's registered habitat; do not trust node positions/owners supplied by clients or accept a bare template ID without server-side instance membership validation. (NodeId now exists on the exact server-built Part; runtime-unverified)
- [x] Resource cooldown bookkeeping is now per UserId and node ID in memory.
- [x] Update cooldown only after a successful reward grant.
- [ ] Test full-inventory and duplicate-request behavior.
- [ ] Decide whether resource cooldown/availability persists across rejoin and implement/document the intended behavior. (Still planned)
- [x] Prevent cross-player reward, inventory, cooldown, or habitat mutation. (Source validates registered habitat membership; multiplayer runtime test pending)
- [x] Clear per-player resource cooldown state and habitat slot ownership on leave.
- [ ] Add concurrency/idempotency protection against simultaneous duplicate requests. (Still planned)

### Creature isolation
- [ ] Scope creature instances, registries, behavior loops, movement bounds, discoveries, restoration, and cleanup to the owning habitat/UserId.
- [ ] Prevent one player's creatures from spawning, moving, or being cleaned up in another player's habitat.

**Milestone acceptance:** at least two simultaneous players can build independently, leave/rejoin safely, and retain correct worlds and progression. Automated tests cover core ownership/session rules; source-level. Roblox Studio tests verify real behavior. Static build success alone is insufficient.

## Milestone 3 — Progression integrity and content completion

**Status: PARTIALLY IMPLEMENTED; BLOCKED BY CORE RELIABILITY WORK.**

- [ ] Make all quest definitions reachable and progression durable.
- [ ] Replace inferred inventory-based progress with server-recorded action counters where appropriate.
- [ ] Correct harvest, upgrade, plant, gathering, and creature objectives.
- [ ] Make quest rewards idempotent.
- [ ] Audit every plant definition through obtain → plant → grow → water → harvest → reward → quest → persistence.
- [ ] Implement distinct, habitat-scoped behavior for every released creature.
- [ ] Ensure every purchasable upgrade has a real effect and restored world state.
- [ ] Add rare/special resources only after normal resource isolation is reliable.
- [ ] Preserve save compatibility for every added progression field.

## Milestone 4 — Player experience and presentation

**Status: PARTIALLY IMPLEMENTED / PLANNED.**

- [ ] Clear, responsive inventory, currency, quest, discovery, and plant-state UI.
- [ ] Natural feedback for gathering, planting, watering, harvesting, discovery, quests, and purchases.
- [ ] Desktop, touch, and gamepad usability where practical.
- [ ] Cohesive low-poly environment, lighting, day/night atmosphere, and environmental details.
- [ ] Distinct creature animations and readable behaviors.
- [ ] Sound and subtle environmental effects.
- [ ] Performance profiling and budgets for mobile hardware.

## Milestone 5 — Quality assurance and hardening

**Status: ENGINE-LEVEL VERIFICATION OUTSTANDING.**

- [ ] Add a CI/source check that catches calls to missing module functions such as the Run #32 WorldBuilder.init regression. (This check was exercised and fixed upstream; explicit CI predicate can be added.)
- [ ] Execute the existing TestEZ suite in a supported Roblox runner.
- [ ] Add tests for habitat slot allocation/geometry transforms, ownership, independent cooldowns, full-inventory behavior, quest progress, reward idempotency, persistence locks, and concurrency.
- [ ] Add integration coverage for remotes and player lifecycle.
- [ ] Complete two-client multiplayer testing.
- [ ] Test save/rejoin, failed DataStore reads/writes, lock expiry, server shutdown, and crash recovery.
- [ ] Test mobile touch and low-end device performance.
- [ ] Verify cleanup, memory, and connection lifecycles.
- [ ] Keep security tests focused on client/server trust boundaries.

### Run #32 verification record

Run #32 (ID 43119650837) passed Rojo, StyLua, and Selene and uploaded an .rbxl artifact. TestEZ, Roblox runtime, multiplayer, DataStore, and manual testing did not run. The QA agent reported no blocker, but that checkpoint's final source contained a missing WorldBuilder.init() definition and other issues documented in project-state/run-32-audit.md. The init API is now present in the current worktree; do not treat QA_BLOCKER: NO as proof that source or runtime behavior is correct.

## Milestone 6 — Release preparation

**Status: PLANNED.**

- [ ] Balance and polish the complete game loop.
- [ ] Decide optional monetization while preserving enjoyable free progression.
- [ ] Configure real product IDs only through Creator Dashboard, with idempotent server receipt handling.
- [ ] Prepare thumbnails, icon, screenshots, and trailer.
- [ ] Complete a release checklist and readiness review.
- [ ] Do not publish without explicit user authorization.

## Current focus

**Immediate priority:** Priority 1 and Priority 2 from AUTONOMOUS_RECOVERY.md have been repaired against the durable `ai/game-build` baseline and verified through deterministic CI (Rojo, StyLua, Selene, git diff). The remaining tasks are:

1. Obtain independent code review and QA confirmation of DataStoreManager session/save/release/lease fixes.
2. Persist a validated checkpoint of 586f702 to `ai/game-build`.
3. Implement character spawn/respawn and saved habitat restoration to complete Milestone 2's gameplay path.
4. Scope CreatureManager runtime to each player's habitat and verify cleanup.

Do not mark persistence or Milestone 2 complete while runtime verification is outstanding. Static CI gates are green, but runtime release readiness requires Roblox Studio/multiplayer/DataStore testing. Consult docs/PROJECT_STATE.md for current facts and docs/AUTONOMOUS_RECOVERY.md for the explicit runtime gaps checklist.