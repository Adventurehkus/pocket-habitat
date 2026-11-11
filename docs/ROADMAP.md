# Pocket Habitat — Development Roadmap

## How to use this roadmap

This is a living priority queue, not a fixed prompt. The current implementation and verification facts belong in docs/PROJECT_STATE.md. At the start of each run, verify the current source and choose the highest-priority unfinished acceptance item below. After meaningful progress, update statuses and the next task so the next run can continue without a rewritten handoff.

Status labels:
- **Complete:** integrated and verified to the level stated.
- **Implemented, runtime-unverified:** source exists and relevant static checks pass, but Roblox engine/gameplay behavior is not verified.
- **In progress:** partly implemented or missing important integration/validation.
- **Planned:** not implemented.

## Milestone 0 — Foundation

**Status: COMPLETE for the current project configuration and automated build foundation.**

- Rojo project configuration and repository structure.
- Rokit-pinned toolchain and Wally dependency manifest.
- Core project documentation.
- GitHub Actions autonomous development pipeline.
- Automated Rojo, StyLua, and Selene validation.

The pipeline's adaptive temporary-limit retry changes are committed on main but still require a fresh workflow run to validate their live behavior.

## Milestone 1 — Playable prototype loop

**Status: IMPLEMENTED IN SOURCE; ROBLOX RUNTIME NOT VERIFIED.**

Source contains world construction, resource gathering, planting, watering, harvesting, inventory/currency, quests, creature discovery, and client prompt handling. PlantRules and EconomyRules centralize important production validations.

Acceptance criteria before calling the prototype reliably playable:
- A new player can join, spawn, gather, plant, water, harvest, earn rewards, and receive feedback in Roblox Studio.
- All actions are server-authoritative and fail safely.
- Full-inventory and failed-reward cases do not lose or duplicate items.
- Quest and upgrade actions reflect real server-side gameplay.
- The experience works in a two-client server.
- Save/rejoin behavior is verified without overwriting data.

## Milestone 2 — Personal habitats and multiplayer/data reliability

**Status: HIGHEST PRIORITY; IN PROGRESS.**

This milestone establishes the defining Pocket Habitat experience: every player has an independent, persistent world.

### Habitat lifecycle
- [x] Server-owned allocation and registry keyed by server-known UserId.
- [x] One isolated habitat per player, with non-overlapping placement.
- [x] Correct spawn and respawn handling.
- [ ] Safe restoration from validated player data.
- [ ] Cleanup on leave and shutdown without duplicate instances.
- [ ] Ownership validation on every plot/resource/creature action.

### Independent resources, plants, and creatures
- [ ] Per-habitat resource nodes and cooldowns.
- [ ] Player-specific plot state and world instances.
- [ ] Player-specific creature registries, discovery, restore, behavior, and cleanup.
- [ ] No cross-player reward, inventory, cooldown, or habitat mutation.
- [ ] Concurrency protection against simultaneous duplicate requests.

### Persistence safety
- [ ] Atomic cross-server session ownership using UpdateAsync and a server-specific token.
- [ ] Expiring lease and safe recovery from crashed servers.
- [ ] Writes rejected when the server no longer owns the session.
- [ ] Explicit schema validation/migration while preserving PocketHabitat_v2_PlayerData.
- [ ] Failed reads never initialize defaults over inaccessible existing data.
- [ ] Bounded save, release, and shutdown behavior.

**Milestone acceptance:** at least two simultaneous players can build independently, leave/rejoin safely, and retain correct worlds and progression. Automated tests should cover the core ownership/session rules; Roblox Studio testing is still required.

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

- [ ] Execute the existing TestEZ suite in a supported Roblox runner.
- [ ] Add tests for habitat allocation/ownership, independent cooldowns, quest progress, reward idempotency, persistence locks, and concurrency.
- [ ] Add integration coverage for remotes and player lifecycle.
- [ ] Complete two-client multiplayer testing.
- [ ] Test save/rejoin, failed DataStore reads/writes, lock expiry, server shutdown, and crash recovery.
- [ ] Test mobile touch and low-end device performance.
- [ ] Verify cleanup, memory, and connection lifecycles.
- [ ] Keep security tests focused on client/server trust boundaries.

## Milestone 6 — Release preparation

**Status: PLANNED.**

- [ ] Balance and polish the complete game loop.
- [ ] Decide optional monetization while preserving enjoyable free progression.
- [ ] Configure real product IDs only through Creator Dashboard, with idempotent server receipt handling.
- [ ] Prepare thumbnails, icon, screenshots, and trailer.
- [ ] Complete a release checklist and readiness review.
- [ ] Do not publish without explicit user authorization.

## Current focus

Build a server-owned personal-habitat allocation/lifecycle vertical slice. Use docs/PROJECT_STATE.md for the precise next task and known source gaps. Re-evaluate the next task after each meaningful implementation checkpoint rather than keeping a fixed milestone inside a reusable prompt.