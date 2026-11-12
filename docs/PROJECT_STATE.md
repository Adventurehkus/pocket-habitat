# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest gameplay checkpoint:** `1af27d2aade0922f57ec4333bf5d5331366d7b9b`
- **Latest completed autonomous workflow:** Run #32, ID `43119650837`
- **Workflow URL:** https://github.com/Adventurehkus/pocket-habitat/actions/runs/43119650837
- **Workflow configuration branch:** main
- **Workflow head used by Run #32:** `b37935206db380e99731d4082c2f9f803954a76e`
- **Latest workflow configuration commit on main:** `658bb50bad7060dc0ae99760ac673c748684cac4`
- **Current workflow policy:** multi-cycle implementation/review/QA with round-robin model reuse, 75% explicit quota-pool exhaustion target, per-cycle checkpoint pushes, and hard call/time/no-progress caps.
- **Verification boundary:** the new multi-cycle router is committed but has NOT yet been exercised by a new workflow run. Run #32 tested only the old one-pass stage orchestration.
- **Run #32 artifact:** `pocket-habitat-pipeline-32` (77,705 bytes, includes Rojo .rbxl build and stage/usage logs)
- **Run #32 result:** workflow completed successfully; implementation, review, repair, validation repair, QA, persistence, and artifact upload succeeded.
- **Current source warning:** Run #32 introduced a source-confirmed server-startup blocker: ServerMain calls `WorldBuilder.init()`, but the current WorldBuilder module no longer defines that function. See `project-state/run-32-audit.md`.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

Pocket Habitat is **not currently verified as a playable Roblox game**. Run #32 passed static build, formatting, and lint checks, but no Roblox engine, Studio, multiplayer, DataStore, or manual playtest ran. The committed source has a startup API mismatch that is expected to stop ServerMain before its runtime initialization and player event handlers are registered.

Milestone 2 (personal habitats, multiplayer isolation, and safe persistence) remains **IN PROGRESS and NOT COMPLETE**. Do not claim non-overlapping habitats, character spawn/respawn routing, save restoration, or full player ownership validation.

**Current highest-priority task:** fix the WorldBuilder/ServerMain startup API mismatch, then make habitat spatial placement/geometry internally consistent and validate the join-to-interaction path before proceeding to deeper persistence work.

## Latest workflow — Run #32

- Run ID: `43119650837`; completed successfully.
- Gameplay checkpoint persisted: `1af27d2aade0922f57ec4333bf5d5331366d7b9b`.
- Implementation: SUCCESS (Cohere North Mini Code).
- Independent review: SUCCESS (Google Gemini 3.5 Flash Lite).
- Conditional repair: SUCCESS (Cohere Command A+).
- Validation repair: SUCCESS (GitHub Copilot Auto).
- QA: SUCCESS (Google Gemini 3.1 Flash Lite; QA_BLOCKER: NO).
- Rojo build: PASSED; artifact contains `build/pocket-habitat.rbxl`.
- StyLua check src: PASSED; zero errors, warnings, or parse errors.
- Selene src: PASSED.
- `git diff --check`: repair-agent log reports PASS after formatting.
- TestEZ execution: NOT EXECUTED.
- Roblox Studio/server startup: NOT EXECUTED.
- Two-client multiplayer: NOT EXECUTED.
- DataStore integration/stress/rejoin: NOT EXECUTED.
- Manual gameplay/mobile/input tests: NOT EXECUTED.
- Artifact upload and GitHub checkpoint push: SUCCESS.

**Important:** The QA report missed the missing `WorldBuilder.init()` function and incorrectly described the BaseOffset scheme as non-overlapping and character spawning as implemented. Audit final source rather than relying on those specific QA statements. The reviewer also reported a stale PlayerAdded issue and missing cleanup; the final committed source uses `Players.PlayerAdded` and does call `HabitatManager.removeHabitat(player)` on PlayerRemoving. The remaining prompt-discovery race is documented in `project-state/run-32-audit.md`.

## Implemented or partially implemented source systems

These items exist in source but are not equivalent to a verified end-to-end Roblox feature:

- Server startup and remote registration modules exist, but the current `WorldBuilder.init()` call is unresolved and blocks successful startup.
- `HabitatManager` creates a `Workspace.Habitats` folder, allocates `Habitat_<UserId>` folders, stores a per-server registry, and can remove a player's folder.
- `WorldBuilder.buildHabitat(folder, owner)` creates baseplate, resource, plot, path, and pond instances inside a habitat folder.
- `ResourceManager` now tracks cooldowns in memory per UserId and node ID. It does not yet validate an exact server-owned resource instance or restore resource availability from saved data.
- `ServerMain` invokes habitat allocation after data load and removes the habitat folder on PlayerRemoving.
- Existing plant/economy/quest/creature source modules remain. Plot interaction still lacks actual owned-plot instance and distance validation; creature runtime remains incompletely player-scoped.
- TestEZ specifications exist for PlantRules/EconomyRules but were not executed in Run #32.

## Current autonomous workflow behavior (not yet live-tested)

The workflow on `main` now continues beyond the first successful implementation/review/QA pass. It repeats coherent implementation, independent review, conditional repair, deterministic validation, and QA cycles. Later cycles continue the original task if unfinished; otherwise they use the live project state and roadmap to advance to the next unfinished priority.

The router rotates eligible models across cycles and allows previously successful models to be reused in later cycles. It aims to stop after explicit daily/monthly quota errors have exhausted at least 75% of eligible quota pools. Google/Groq routes are counted per model; Cohere, OpenRouter, Cloudflare, and Copilot routes are grouped by provider/account. Quota exhaustion is reactive to provider error messages, not a live balance measurement.

Safety limits are 8 calls per model, 120 calls total, 30 cycles, 2 hours of aggregate temporary-limit wait, two consecutive no-progress cycles, and the GitHub Actions 350-minute job timeout. Each reviewed and validated cycle is checkpointed to `ai/game-build` before another cycle begins. Review, QA, validation, or checkpoint-persistence failure stops the run rather than allowing unchecked work to accumulate.

This behavior is documented in `docs/AUTONOMOUS_AGENT_GUIDE.md` and `docs/TESTING.md`. A new workflow dispatch is required to exercise it. Provider account billing cannot be inspected by CI; call-count caps are not dollar-spend caps. Check provider free-tier status and spending limits before long runs.

## Confirmed Run #32 blockers and gaps

The canonical source audit is `project-state/run-32-audit.md`. Key points:

1. **P0 startup blocker:** ServerMain calls missing `WorldBuilder.init()`; WorldBuilder only defines `buildHabitat`.
2. **Habitat overlap:** BaseOffset advances by only 0.1 studs on both X/Z and is bounded to a 0–99.9 diagonal range, while every baseplate is 100×100 studs; IDs wrap every 1,000.
3. **Incorrect geometry offsets:** leaves/berries and plot borders add BaseOffset twice; paths target world origin rather than consistently using the local habitat origin.
4. **No character spawn/respawn placement:** HabitatManager allocates folders but does not move characters; ServerMain has no CharacterAdded habitat-spawn wiring.
5. **No saved-world restoration:** loaded data is not passed into habitat construction; plant/plot/upgrade/resource/creature runtime instances are not reconstructed from validated save data.
6. **Plot remote is insufficiently bound to the world:** numeric plotIndex/action is checked against player data, but no exact plot Instance under that player's habitat or server-measured proximity is verified. Effects use fixed unoffset positions.
7. **Resource remote needs exact ownership validation:** cooldowns are per-player, but remote accepts a nodeId template and does not prove membership in the player's registered habitat; missing habitat falls back to zero offset. Cooldown is set before the reward succeeds, so full inventory causes a no-reward cooldown.
8. **Client prompt discovery has races/over-broad folder handling:** no unconditional initial own-habitat lookup; global ChildAdded path scans any habitat folder and may run before descendants/prompts exist. Connect only to local player's habitat and observe prompt descendants.
9. **Persistence remains unsafe across servers:** GetAsync/SetAsync and local activeSessions are not a cross-server lease. A failed final save can still be followed by clearing the only in-memory session data.
10. **Creature runtime still requires per-habitat scoping:** verify current CreatureManager and isolate runtime instances, registries, movement bounds, and cleanup.
11. **Lifecycle/idempotency:** prevent duplicate habitat allocation, remove per-player runtime/cooldown/connection state, and test disconnect/shutdown/rejoin behavior.

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

1. Fix the missing WorldBuilder startup API and add a startup smoke test/check that catches unresolved module calls where feasible.
2. Replace UserId-modulus placement with a collision-free deterministic habitat slot/grid; apply one consistent transform to all geometry.
3. Make prompt wiring local-player-only and race-safe; validate actual owned plot/resource instances, session, character, and distance on the server.
4. Implement character spawn/respawn placement and restore plots/world state from validated player data.
5. Implement cross-server DataStore session leases and failure-safe save/release semantics.
6. Scope CreatureManager runtime to each player's habitat.
7. Add and execute production-rule/integration tests; run Roblox Studio with at least two clients and test persistence/rejoin.
8. Reassess milestone acceptance only after these checks.

## Workflow and model/provider routing status

Run #32 exercised the adaptive fallback system live:
- 20 models were configured.
- 3 daily/shared quota-exhaustion events were recorded.
- 4 classified temporary-limit events incurred 0 seconds of automatic waiting.
- Some Google routes were model-daily-quota exhausted or rate-limited; Cloudflare Workers AI and OpenRouter were marked shared quota exhausted; some Groq routes were skipped because the request was too large.
- Other routes completed implementation, review, repair, validation repair, and QA successfully.
- All required stages completed. This is not evidence that all 20 models were exhausted; the workflow did not stop for lack of models.
- Provider balances after the run were not checked. A configured model does not prove a provider currently has remaining account quota.

See `docs/TESTING.md` and the artifact usage TSV for stage-by-stage details. Keep quota data run-specific; never hard-code live free-tier quota counts into reusable agent prompts.
