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

**Status: SOURCE FLOW IMPLEMENTED; PLAYABILITY AND SAVE/RESTORE RUNTIME-UNVERIFIED.**

Source modules contain resource gathering, planting/watering/harvesting, inventory/currency, quests, creature discovery, and client prompt handling. However:
- `ServerMain` disables automatic character loading, acquires player data before habitat allocation, and spawns/restores a character from the loaded session. Roblox server startup has not been tested.
- Respawn is requested by the client on Humanoid death and validated/cooldown-limited on the server. Roblox behavior has not been tested.
- No Roblox engine or Studio test has been run for this recovery pass.
- Do not call this prototype playable until client interactions work end to end, two clients can play without interference, and save/rejoin is verified.

Acceptance criteria:
- [ ] Server starts without runtime errors; all server systems/remotes/player lifecycle handlers initialize. (Source wiring exists; engine test pending)
- [ ] A new player joins and spawns correctly. (Source flow exists; engine test pending)
- [ ] A player can gather, plant, water, harvest, earn rewards, and receive feedback in Roblox Studio. (Source paths exist; runtime unverified)
- [ ] All actions are server-authoritative and fail safely. (Several source checks exist; full audit and runtime validation pending)
- [ ] Full-inventory and failed-reward cases do not produce cooldown-only failures, item loss, or duplicate rewards. (Runtime/concurrency tests pending)
- [ ] Quest and upgrade actions reflect real server-side gameplay. (Source exists, not yet verified)
- [ ] The experience works in a two-client server. (Not yet tested)
- [ ] Save/rejoin behavior is verified without overwriting data. (DataStore lease/save code exists but runtime verification pending)

## Milestone 2 — Personal habitats and multiplayer/data reliability

**Status: HISTORICAL SOURCE RECOVERY RESOLVED; GAMEPLAY RUNTIME VERIFICATION PENDING.**

Habitat allocation and source-level ownership validation exist. The Run #40 cycle-1 recovery entry reports review, QA, and deterministic validation passed for the listed historical session/shutdown/cooldown repairs. Current source and static checks have been reverified. TestEZ, Roblox runtime, multiplayer, and DataStore integration testing remain outstanding. New quest progression changes are a separate unreviewed source slice and are not covered by the recovery resolution.

This milestone establishes the defining Pocket Habitat experience: every player has an independent, persistent world.

### DataStore Manager and Session Lifecycle
**Status: HISTORICAL RECOVERY SOURCE REPAIRED AND REVIEW/QA REPORTED PASSED; RUNTIME VERIFICATION PENDING**

The DataStoreManager module now implements:
- [x] RemoteEvents import and usage is present in source.
- [x] `loadPlayerData` atomically acquires an owner-token lease with `UpdateAsync`; `getSession` does not fabricate data when no session exists.
- [x] Failed loads, live locks, malformed records, user-id mismatches, and future schema versions fail closed instead of creating defaults.
- [x] Saves and lease renewals write current in-memory data only when the stored owner token matches.
- [x] `releaseSession` atomically persists current data and clears the lock only after a confirmed update; transient failures retain memory and schedule up to three release-only retries (5/15/30 seconds) without renewing the departing lease. (Static checks pass; runtime unverified)
- [x] Lease renewal recurs every 120 seconds with a five-minute lease and bounded retries before expiry.
- [x] PlayerRemoving and BindToClose call per-player release; shutdown retries are attempted synchronously within one absolute deadline after normal cleanup (runtime behavior unverified).
- [x] Gameplay defaults include the current four-plot/quest/economy/discovery schema; legacy `currency` and spawn-vector shapes are normalized.
- [x] Character spawn data is periodically refreshed in memory, stored as numeric tables, and restores Euler orientation consistently.
- [x] The client handles both session-load payloads and direct gameplay data updates.
- [x] Run #40 cycle-1 recovery entry reports review/QA for the historical session/shutdown/cooldown source repairs.
- [ ] Roblox DataStore/runtime tests verify contention, renewal, save/rejoin, failure handling, and shutdown.

The preceding source-level recovery items have review/QA evidence recorded by the Run #40 cycle-1 recovery entry. Runtime-specific acceptance remains:
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
- [ ] Verify characters spawn at their own habitat and every respawn uses the existing habitat. (Source flow implemented; runtime test pending)
- [x] **Restore plots/plants/upgrades/world state from validated saved data before the player can interact. (Fixed in WorldBuilder: resolves the actual `GardenPlots` folder before restoring planted seeds, growth stage, and water count from session data; runtime-unverified)**
- [x] Route BindToClose cleanup through the absolute shutdown deadline rather than ordinary release retries first. (Implemented in ServerMain; engine behavior unverified)
- [ ] Ensure leave and BindToClose cleanup disconnects/destroys only that player's runtime objects and handles failed final saves safely. (Source path exists; final cleanup behavior verified by runtime test pending)

### Prompt, plot, and resource ownership
- [x] Make LocalScript prompt discovery connect only to the local player's habitat, including an initial lookup and later DescendantAdded/removed handling. (Implemented in ProximityHandler; runtime-unverified)
- [x] Validate plot Instance membership in the calling player's habitat, plot index, active session, character, and server-measured interaction distance before any mutation. (Implemented in PlantManager)
- [x] Derive plot effect positions from the server-resolved plot Instance instead of fixed shared-world coordinates. (Implemented in PlantManager)
- [x] Resolve each resource node from the calling player's registered habitat; do not trust node positions/owners supplied by clients or accept a bare template ID without server-side instance membership validation. (NodeId now exists on the exact server-built Part; runtime-unverified)
- [x] Resource cooldowns are isolated per player/node in session data, schema-validated, and included in normal save/release writes. (Crash before the next write may lose the newest cooldown.)
- [x] Reserve cooldown before reward mutation and roll it back when reward grant is rejected.
- [x] Use the production cooldown/reward transaction helper in the rejection rollback spec; TestEZ execution is pending.
- [x] Require active session and living character; throttle gather requests per player.
- [ ] Test full-inventory and duplicate-request behavior.
- [x] Define resource cooldown availability as persistent across rejoin, subject to normal periodic/final save durability.
- [x] Prevent cross-player reward, inventory, cooldown, or habitat mutation. (Source validates registered habitat membership; multiplayer runtime test pending)
- [x] Clear transient per-player request-throttle state and habitat slot ownership on leave.
- [x] Reserve per-node cooldown before reward grant to reject duplicate gather requests during mutation. (Roblox concurrency/runtime verification pending)

### Creature isolation
- [x] **Scope creature instances, registries, behavior loops, movement bounds, discoveries, restoration, and cleanup to the owning habitat/UserId. (Implemented in CreatureManager: per-habitat Creatures folder, distinct models for all 5 types, bounded movement, per-player registry, restore from session data, cleanup on leave; runtime-unverified)**
- [x] **Prevent one player's creatures from spawning, moving, or being cleaned up in another player's habitat. (Implemented: creatures parented to owner's habitat folder, movement bounded to habitat bounds, registry keyed by UserId; runtime-unverified)**

**Milestone acceptance:** at least two simultaneous players can build independently, leave/rejoin safely, and retain correct worlds and progression. Automated tests cover core ownership/session rules; source-level. Roblox Studio tests verify real behavior. Static build success alone is insufficient.

## Milestone 3 — Progression integrity and content completion

**Status: PARTIALLY IMPLEMENTED; quest progression source slice added, independent review and runtime testing pending.**

- [x] Define a single order that reaches all ten quests; old sessions with no current quest advance to the next incomplete quest. (Source implemented; TestEZ/Studio verification pending)
- [x] Replace inventory/current-plot inference for gather, plant, water, and harvest objectives with persisted, server-recorded action counters. (Source implemented; TestEZ/Studio verification pending)
- [x] Validate actual harvest progress, upgrade levels, and the specific Leafling discovery. (Source implemented; runtime pending)
- [x] Award the Sun Petal seed needed for the Sun Petal quest; validate capacity and commit item, Bells, and claim state together. (Source implemented; runtime pending)
- [x] Keep quest reward claims single-use; an incomplete inventory/award transaction does not mark the quest complete. (Source implemented; runtime/test verification pending)
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

**Immediate priority:** Obtain independent pipeline review/QA for the current quest-progression slice and execute focused TestEZ specs in a compatible runner. Then verify quest progression, independent gathering, habitat isolation, save/rejoin, lease contention, and shutdown in Roblox Studio. Historical Run #38/39 recovery source fixes are resolved; current gameplay runtime and TestEZ execution remain outstanding.

**Source-level completed (runtime verification pending):**
- Restore saved plot/world progression from validated session data (WorldBuilder.buildHabitat now restores plant state)
- Scope CreatureManager to each player's habitat (per-habitat Creatures folder, distinct creature models, bounded movement, restoration from discovery data, cleanup on leave)
- Persist each player's resource cooldowns in their validated save data and throttle gather requests
- Reserve and roll back gather cooldowns through production logic shared with focused TestEZ cases (execution pending)
- Record all quest actions in backward-compatible player data; restore the full ten-quest sequence and validate real harvest, upgrade, and discovery objectives

Do not mark persistence or Milestone 2 complete while runtime verification is outstanding. Static CI gates are green, but runtime release readiness requires Roblox Studio/multiplayer/DataStore testing. Consult docs/PROJECT_STATE.md for current facts and docs/AUTONOMOUS_RECOVERY.md for the explicit runtime gaps checklist.