# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest gameplay checkpoint:** `1af27d2aade0922f57ec4333bf5d5331366d7b9b`
- **Latest completed autonomous workflow:** Run #32, ID `43119650837`
- **Workflow URL:** https://github.com/Adventurehkus/pocket-habitat/actions/runs/43119650837
- **Workflow configuration branch:** main
- **Workflow head used by Run #32:** `b37935206db380e99731d4082c2f9f803954a76e`
- **Latest workflow configuration commit on main:** `649d6137cb0221bccac914f337754b3db1bf59a8`.
- **Current workflow policy:** multi-cycle implementation/review/QA with round-robin model reuse, 100% explicit exhaustion target across currently eligible quota pools, per-cycle checkpoint pushes, and hard call/time/no-progress caps.
- **Verification boundary:** the new multi-cycle router is committed but has NOT yet been exercised by a new workflow run. Run #32 tested only the old one-pass stage orchestration.
- **Run #32 artifact:** `pocket-habitat-pipeline-32` (77,705 bytes, includes Rojo .rbxl build and stage/usage logs)
- **Run #32 result:** workflow completed successfully; implementation, review, repair, validation repair, QA, persistence, and artifact upload succeeded.
- **Current source warning:** The Run #32 `WorldBuilder.init()` mismatch is fixed in the current worktree. This run also removed a stale `QuestManager.claimQuest` override and fixed resource-node lookup, habitat-slot collisions, and prompt-discovery lifecycle; Roblox runtime behavior remains unverified.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

Pocket Habitat is **not currently verified as a playable Roblox game**. Run #32 passed static build, formatting, and lint checks, but no Roblox engine, Studio, multiplayer, DataStore, or manual playtest ran. The current worktree has a matching `WorldBuilder.init()` definition and call, but server startup still needs engine verification.

Milestone 2 (personal habitats, multiplayer isolation, and safe persistence) remains **IN PROGRESS and NOT COMPLETE**. The source now allocates non-overlapping active slots per server, but multiplayer isolation is unverified. Character spawn/respawn routing, save restoration, and full player ownership validation are not complete.

**Current highest-priority task:** implement cross-server persistence ownership and failure-safe save/release semantics, then add character spawn/respawn and restore saved habitat state before enabling interactions.

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

**Important:** At Run #32, QA missed the missing `WorldBuilder.init()` function and incorrectly described BaseOffset placement as non-overlapping and character spawning as implemented. That checkpoint's source also had prompt-discovery races. The current worktree now defines `WorldBuilder.init()`, allocates unique active slots, and tracks prompt descendants; none of those changes has Roblox runtime evidence.

## Implemented or partially implemented source systems

These items exist in source but are not equivalent to a verified end-to-end Roblox feature:

- `ServerMain` calls module APIs that are present in the current source, including `WorldBuilder.init()`; this is source inspection only, not a Roblox startup test.
- `QuestManager.init()` owns the `ClaimQuest` RemoteFunction handler; `ServerMain` no longer replaces it with a call to a nonexistent `QuestManager.claimQuest`.
- `HabitatManager` allocates non-overlapping per-server grid slots, reuses slots after removal, stores a per-server registry, and sets `OwnerUserId` metadata. Allocation is idempotent for a live folder.
- `WorldBuilder.buildHabitat(folder, owner)` creates baseplate, resource, plot, path, and pond instances inside a habitat folder with BaseOffset applied exactly once to all geometry.
- `ResourceManager` tracks cooldowns in memory per UserId and node ID, validates the matching resource Part inside the calling player's registered habitat, checks distance, applies cooldown only after a successful reward, and clears cooldowns on PlayerRemoving.
- `ServerMain` registers `PlayerAdded` before processing already-connected players and avoids duplicate initialization for the same UserId. It removes runtime habitat/cooldown state on PlayerRemoving.
- `PlantManager` now validates exact plot Instance membership in the calling player's habitat, server-measured interaction distance (25 studs), and validates that the plotIndex corresponds to an actual plot Instance. Includes plot position effects derived from server-resolved plot Instance positions.
- `ProximityHandler.client.lua` connects only to LocalPlayer's habitat, handles existing and newly added habitats, discovers prompts added during construction, and disconnects connections when the habitat is removed.
- Existing plant/economy/quest/creature source modules remain. Creature runtime remains incompletely player-scoped (Milestone 2 incomplete), plot interaction validation is now implemented, creature runtime isolation still needs work (Milestone 2 incomplete).
- TestEZ specifications exist for PlantRules/EconomyRules but were not executed in Run #32.

**Important:** While static CI checks pass and the source now includes significant security and validation improvements, the game is **NOT currently verified as a playable Roblox game**. No Roblox runtime, Studio, multiplayer, DataStore, or manual playtests have been executed. Milestone 2 (personal habitats, multiplayer isolation, and safe persistence) remains **IN PROGRESS and NOT COMPLETE**. Server startup no longer has the API mismatch, but character spawn/respawn, world state restoration, DataStore session management, creature runtime isolation, and persistence safety across servers still require implementation and verification.

## Current autonomous workflow behavior (not yet live-tested)

The workflow on `main` now continues beyond the first successful implementation/review/QA pass. It repeats coherent implementation, independent review, conditional repair, deterministic validation, and QA cycles. Later cycles continue the original task if unfinished; otherwise they use the live project state and roadmap to advance to the next unfinished priority.

The router rotates eligible models across cycles and allows previously successful models to be reused in later cycles. The quota target is now 100% of currently eligible pools: every pool still usable in this run must return an explicit daily/monthly quota-exhaustion error before quota-target completion. Google/Groq routes are counted per model; Cohere, OpenRouter, Cloudflare, and Copilot routes are grouped by provider/account. Permanently ineligible routes are excluded from the eligible denominator but are not counted as quota-exhausted. When no pools are measurable, the report shows 0% and does not claim the target. Quota exhaustion is reactive to provider error messages, not a live balance measurement.

Safety limits are 8 calls per model, 120 calls total, 30 cycles, 2 hours of aggregate temporary-limit wait, two consecutive no-progress cycles, and the GitHub Actions 350-minute job timeout. Each reviewed and validated cycle is checkpointed to `ai/game-build` before another cycle begins. Review, QA, validation, or checkpoint-persistence failure stops the run rather than allowing unchecked work to accumulate.

This behavior is documented in `docs/AUTONOMOUS_AGENT_GUIDE.md` and `docs/TESTING.md`. A new workflow dispatch is required to exercise it. The 100% target and quota-accounting regression fixtures were committed to `main` in `649d6137cb0221bccac914f337754b3db1bf59a8`; they have not yet been exercised by a new workflow dispatch. Provider account billing cannot be inspected by CI; call-count caps are not dollar-spend caps. Check provider free-tier status and spending limits before long runs.

## Run #32 findings and current status

The historical source audit is `project-state/run-32-audit.md`; its findings describe the Run #32 checkpoint and are not all current source facts. In the current worktree, the startup API mismatch and stale quest-handler override are resolved, active habitat slots do not repeat, resource IDs are present on the server-owned Parts searched by `ResourceManager`, and prompt discovery watches existing and subsequently added prompts under only the local player's habitat. These fixes have not been exercised in Roblox.

DataStore session leases and failure-safe save/release semantics are now implemented. Character spawn/respawn placement and saved-world restoration remain to be completed. Per-habitat creature runtime isolation still needs work. Plot state/schema count consistency and concurrent interaction behavior also need dedicated verification.

Current remaining risks and gaps:

1. Character spawn/respawn placement and saved-world restoration are not implemented.
2. DataStore sessions now have cross-server leases and failure-safe save/release semantics.
3. Creature runtime is not fully scoped to each player's habitat.
4. Plot state/schema count consistency and concurrent interaction behavior need dedicated verification.
5. Roblox startup, multiplayer isolation, persistence, and manual gameplay remain untested.

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

✅ COMPLETED: Atomic cross-server DataStore session leases and failure-safe save/release semantics implemented
2. Add character spawn/respawn routing and reconstruct saved habitat state before interactions are enabled.
3. Scope CreatureManager runtime to each player's habitat and clean it up with the player session.
4. Add and execute production-rule/integration tests; run Roblox Studio with at least two clients and test persistence/rejoin.
5. Reassess milestone acceptance only after these checks.

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
