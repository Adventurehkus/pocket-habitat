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

**Status: SOURCE EXISTS; PLAYABILITY NOT VERIFIED; CURRENT STARTUP BLOCKER FOUND.**

Source modules contain resource gathering, planting/watering/harvesting, inventory/currency, quests, creature discovery, and client prompt handling. However:
- Current `ServerMain.server.lua` calls `WorldBuilder.init()`, which does not exist in the current `WorldBuilder.lua`. This is a P0 startup blocker.
- No Roblox engine or Studio test was run in Run #32.
- Do not call this prototype playable until the server starts, client interactions work end to end, two clients can play without interference, and save/rejoin is verified.

Acceptance criteria:
- [ ] Server starts without runtime errors; all server systems/remotes/player lifecycle handlers initialize.
- [ ] A new player joins and spawns correctly.
- [ ] A player can gather, plant, water, harvest, earn rewards, and receive feedback in Roblox Studio.
- [ ] All actions are server-authoritative and fail safely.
- [ ] Full-inventory and failed-reward cases do not produce cooldown-only failures, item loss, or duplicate rewards.
- [ ] Quest and upgrade actions reflect real server-side gameplay.
- [ ] The experience works in a two-client server.
- [ ] Save/rejoin behavior is verified without overwriting data.

## Milestone 2 — Personal habitats and multiplayer/data reliability

**Status: IN PROGRESS; NOT COMPLETE. Current implementation has a startup blocker and significant isolation/lifecycle gaps.**

This milestone establishes the defining Pocket Habitat experience: every player has an independent, persistent world.

### Habitat allocation, geometry, and lifecycle
- [x] Server-side HabitatManager module creates per-player named folders and tracks them in a per-server registry.
- [x] PlayerRemoving calls the habitat-folder cleanup helper in the final Run #32 source.
- [ ] Fix ServerMain's call to the missing WorldBuilder.init() API; verify complete server startup.
- [ ] Replace the 0.1-stud UserId-modulus diagonal offset with non-overlapping habitat slot/grid allocation and safe slot ownership.
- [ ] Apply the habitat transform exactly once to baseplate, resource nodes, leaves/berries, plot parts/borders, paths, pond, and all future instances.
- [ ] Add server-owned OwnerUserId metadata for diagnostics; authorization must still use server registry/Player identity.
- [ ] Make allocation idempotent and safe against duplicate folders/registry entries.
- [ ] Spawn characters at their own habitat and handle every respawn.
- [ ] Restore plots/plants/upgrades/world state from validated saved data before the player can interact.
- [ ] Ensure leave and BindToClose cleanup disconnects/destroys only that player's runtime objects and handles failed final saves safely.

### Prompt, plot, and resource ownership
- [ ] Make LocalScript prompt discovery connect only to the local player's habitat, including an unconditional initial lookup and later DescendantAdded/removed handling.
- [ ] Validate plot Instance membership in the calling player's habitat, plot index, active session, character, and server-measured interaction distance before any mutation.
- [ ] Derive plot effect positions from the server-resolved plot Instance instead of fixed shared-world coordinates.
- [ ] Resolve each resource node from the calling player's registered habitat; do not trust node positions/owners supplied by clients or accept a bare template ID without server-side instance membership validation.
- [x] Resource cooldown bookkeeping is now per UserId and node ID in memory.
- [ ] Update cooldown only after successful reward grant (or safely roll back on failure); test full inventory and duplicate requests.
- [ ] Decide whether resource cooldown/availability persists across rejoin and implement/document the intended behavior.
- [ ] Prevent cross-player reward, inventory, cooldown, or habitat mutation.
- [ ] Add concurrency/idempotency protection against simultaneous duplicate requests.

### Creature isolation
- [ ] Scope creature instances, registries, behavior loops, movement bounds, discoveries, restoration, and cleanup to the owning habitat/UserId.
- [ ] Prevent one player's creatures from spawning, moving, or being cleaned up in another player's habitat.

### Persistence safety
- [ ] Atomic cross-server session ownership using UpdateAsync and a server-specific token.
- [ ] Expiring lease, renewal, and safe recovery from crashed servers.
- [ ] Writes and releases rejected when the server no longer owns the session.
- [ ] Explicit schema validation/migration while preserving PocketHabitat_v2_PlayerData.
- [ ] Failed reads never initialize defaults over inaccessible or malformed existing data.
- [ ] Failed final saves do not clear the only in-memory copy of the player's state.
- [ ] Bounded save, release, and shutdown behavior.

**Milestone acceptance:** at least two simultaneous players can build independently, leave/rejoin safely, and retain correct worlds and progression. Automated tests cover core ownership/session rules, and Roblox Studio tests verify real behavior. Static build success alone is insufficient.

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

**Status: IN PROGRESS; ENGINE-LEVEL VERIFICATION OUTSTANDING.**

- [ ] Add a CI/source check that catches calls to missing module functions such as the Run #32 WorldBuilder.init regression.
- [ ] Execute the existing TestEZ suite in a supported Roblox runner.
- [ ] Add tests for habitat slot allocation/geometry transforms, ownership, independent cooldowns, full-inventory behavior, quest progress, reward idempotency, persistence locks, and concurrency.
- [ ] Add integration coverage for remotes and player lifecycle.
- [ ] Complete two-client multiplayer testing.
- [ ] Test save/rejoin, failed DataStore reads/writes, lock expiry, server shutdown, and crash recovery.
- [ ] Test mobile touch and low-end device performance.
- [ ] Verify cleanup, memory, and connection lifecycles.
- [ ] Keep security tests focused on client/server trust boundaries.

### Run #32 verification record

Run #32 (ID 43119650837) passed Rojo, StyLua, and Selene and uploaded an .rbxl artifact. TestEZ, Roblox runtime, multiplayer, DataStore, and manual testing did not run. The QA agent reported no blocker, but the final source contains a missing WorldBuilder.init() call and other issues documented in project-state/run-32-audit.md. Do not treat QA_BLOCKER: NO as proof that the source is correct.

## Milestone 6 — Release preparation

**Status: PLANNED.**

- [ ] Balance and polish the complete game loop.
- [ ] Decide optional monetization while preserving enjoyable free progression.
- [ ] Configure real product IDs only through Creator Dashboard, with idempotent server receipt handling.
- [ ] Prepare thumbnails, icon, screenshots, and trailer.
- [ ] Complete a release checklist and readiness review.
- [ ] Do not publish without explicit user authorization.

## Current focus

Fix the P0 WorldBuilder/ServerMain API mismatch first. Then implement and verify correct habitat slot placement and one-time geometry transforms, followed by local-player prompt discovery and server-side plot/resource instance ownership checks. Consult docs/PROJECT_STATE.md and project-state/run-32-audit.md for exact source evidence and subsequent priorities. Do not advance the milestone checkboxes based on static CI alone.
