# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest gameplay/source checkpoint from Run #34:** `8c9c2fa8cfc06f0b85fd5fae781b81cb14ed6d66`.
- **Latest dispatched autonomous workflow:** Run #34, ID `43131314450` (failed final deterministic validation; this was not a quota-target stop).
- **Workflow URL:** https://github.com/Adventurehkus/pocket-habitat/actions/runs/43131314450
- **Workflow configuration branch:** `main`.
- **Workflow head used by Run #34:** `8b3deb6716370644c4167557f2bc3e9ffca25965`.
- **Latest workflow configuration commit on main:** `d3240908cfb2e3e89e816c97e084b9e750e5236e`.
- **Current workflow policy:** 100% of currently eligible quota pools; repeated implementation/review/repair/validation/QA cycles; cross-cycle retries for recoverable agent/provider/code errors; explicit validated versus recovery checkpoints; durable recovery notes on `ai/game-build`.
- **Verification boundary:** Run #34 executed and passed the 100% quota-accounting preflight fixtures, but stopped at 33% quota exhaustion because final StyLua/Selene validation still failed. The newer cross-cycle error-recovery changes on `main` are committed but have NOT yet been live-tested.
- **Run #32 artifact:** `pocket-habitat-pipeline-32` (77,705 bytes, includes Rojo .rbxl build and stage/usage logs)
- **Run #32 result:** workflow completed successfully; implementation, review, repair, validation repair, QA, persistence, and artifact upload succeeded.
- **Current source warning:** The Run #32 `WorldBuilder.init()` mismatch is fixed in the current worktree. This run also removed a stale `QuestManager.claimQuest` override and fixed resource-node lookup, habitat-slot collisions, and prompt-discovery lifecycle; Roblox runtime behavior remains unverified.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

Pocket Habitat is **not currently verified as a playable Roblox game**. Run #34 generated a Rojo `.rbxl` artifact but failed final StyLua/Selene validation; Run #32's earlier static success is historical. No Roblox engine, Studio, multiplayer, DataStore, or manual playtest has run. Server startup and actual gameplay still require Roblox runtime verification.

Milestone 2 (personal habitats, multiplayer isolation, and safe persistence) remains **IN PROGRESS and NOT COMPLETE**. The source allocates non-overlapping active slots per server and contains an attempted cross-server lease implementation, but current DataStoreManager has source-level correctness gaps and is NOT safe/complete. Character spawn/respawn routing, saved habitat restoration, full player ownership validation, and Roblox runtime verification remain outstanding.

**Current highest-priority task:** first repair Run #34's deterministic validation findings in `src/server/ServerMain.server.lua`: call `game:BindToClose(onBindToClose)`, remove unused `Workspace`/`Constants` imports, and format the file with StyLua. Then audit/fix `DataStoreManager.lua` before marking persistence implemented: it references `RemoteEvents` without requiring `src/shared/RemoteEvents.lua`; its save path reads the stored record and writes the old `record.data` instead of changed in-memory session data; the GetAsync/SetAsync sequence is not atomic; release clears `activeSessions` even when saving fails; and lease renewal is scheduled only once rather than recurring. Do not mark persistence safe until these defects are fixed and failure/rejoin/lease tests pass. Then implement character spawn/respawn and saved habitat restoration.

## Historical workflow — Run #32

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

**Important:** The game is **NOT currently verified as a playable Roblox game**. Run #34's Rojo build succeeded, but its final StyLua/Selene gate failed. `src/server/ServerMain.server.lua` still needs `game:BindToClose(onBindToClose)` instead of property-style `game.BindToClose(onBindToClose)`, removal of unused `Workspace` and `Constants` locals, and StyLua formatting. `DataStoreManager.lua` also has unresolved correctness gaps: missing RemoteEvents import, writes old persisted data instead of the current session state, uses non-atomic GetAsync/SetAsync, clears in-memory state after failed save, and does not recur lease renewal. No Roblox runtime, Studio, multiplayer, DataStore, or manual playtests have been executed. Milestone 2 remains **IN PROGRESS and NOT COMPLETE**. Character spawn/respawn, saved-world restoration, creature runtime isolation, and runtime verification of session leases remain.

## Current autonomous workflow behavior (recovery changes committed; live verification pending)

The workflow on `main` continues beyond the first successful implementation/review/QA pass. It repeats coherent implementation, independent review, conditional repair, deterministic validation, and QA cycles. Later cycles continue the original task if unfinished; otherwise they use the live project state and roadmap to advance to the next unfinished priority. Recoverable implementation, repair, review-format, QA-format/availability, and deterministic validation failures are now carried through fallback models and later cycles rather than immediately terminating the job.

The router rotates eligible models across cycles and allows previously successful models to be reused in later cycles. The quota target is now 100% of currently eligible pools: every pool still usable in this run must return an explicit daily/monthly quota-exhaustion error before quota-target completion. Google/Groq routes are counted per model; Cohere, OpenRouter, Cloudflare, and Copilot routes are grouped by provider/account. Permanently ineligible routes are excluded from the eligible denominator but are not counted as quota-exhausted. When no pools are measurable, the report shows 0% and does not claim the target. Quota exhaustion is reactive to provider error messages, not a live balance measurement.

Safety limits remain 8 calls per model, 120 calls total, 30 cycles, 2 hours of aggregate temporary-limit wait, two consecutive no-progress cycles, and the GitHub Actions 350-minute job timeout. Temporary per-stage failure deferrals reset each cycle so rate-limited and unclassified-error routes can be revisited after cooldown; confirmed quota blocks, permanent auth/model incompatibility, cooldown timestamps, and run-wide call budgets persist. Deterministic validation receives up to 5 repair attempts per cycle; QA blockers receive up to 3 repair/re-check attempts per cycle. Review/QA unavailable or malformed responses and unresolved validation are saved as explicitly unvalidated recovery checkpoints, with the issue recorded durably in `docs/AUTONOMOUS_RECOVERY.md` on `ai/game-build`. The next cycle/run prioritizes that file; it is removed only after review, QA, and deterministic validation all pass. Hard stops are limited to documented global budgets/timeouts, two consecutive no-progress cycles, unrecoverable checkpoint-persistence failure, no safe/meaningful work or eligible route, or all quota pools exhausted while recovery debt remains. A recovery checkpoint is never described as validated.

The 100% quota target and accounting fixtures were exercised in Run #34 and passed during preflight. Run #34 subsequently failed final deterministic validation: StyLua formatting remained out of sync, and Selene reported `game.BindToClose` used as a property instead of the `game:BindToClose(...)` method, plus unused `Workspace` and `Constants` locals. Its stop reason was `final_validation_failed` at only 33% quota exhaustion, confirming the quota target was not the cause. The newer recovery behavior and durable recovery file are committed in `main` but need a fresh workflow dispatch. Push-triggered runs #35 and #36 were created for intermediate workflow-file commits and exposed no job records; they are not evidence that the current recovery implementation ran. Provider account billing cannot be inspected by CI; call-count caps are not dollar-spend caps. Check provider free-tier status and spending limits before long runs.

## Run #32 findings and current status

The historical source audit is `project-state/run-32-audit.md`; its findings describe the Run #32 checkpoint and are not all current source facts. In the current worktree, the startup API mismatch and stale quest-handler override are resolved, active habitat slots do not repeat, resource IDs are present on the server-owned Parts searched by `ResourceManager`, and prompt discovery watches existing and subsequently added prompts under only the local player's habitat. These fixes have not been exercised in Roblox.

DataStore session-lease code exists but is not yet safe or complete: it needs an atomic ownership-checked save of current in-memory data, failed-save retention, recurring lease renewal, and its missing `RemoteEvents` dependency. Character spawn/respawn placement and saved-world restoration remain to be completed. Per-habitat creature runtime isolation still needs work. Plot state/schema count consistency and concurrent interaction behavior also need dedicated verification.

Current remaining risks and gaps:

1. Character spawn/respawn placement and saved-world restoration are not implemented.
2. Correct DataStore session ownership/save/release semantics and recurring lease renewal; then verify failure/rejoin/lease behavior.
3. Creature runtime is not fully scoped to each player's habitat.
4. Plot state/schema count consistency and concurrent interaction behavior need dedicated verification.
5. Roblox startup, multiplayer isolation, persistence, and manual gameplay remain untested.

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

1. Repair Run #34's remaining ServerMain validation failures: use `game:BindToClose(onBindToClose)`, remove unused `Workspace`/`Constants`, and format with StyLua.
2. Correct `DataStoreManager.lua`: require `RemoteEvents`, atomically save current in-memory session data only while the server owns the token, retain memory on failed saves, recur lease renewal, and release safely.
3. Add character spawn/respawn routing and reconstruct saved habitat state before interactions are enabled.
4. Scope CreatureManager runtime to each player's habitat and clean it up with the player session.
5. Add and execute production-rule/integration tests; run Roblox Studio with at least two clients and test persistence/rejoin.
6. Reassess milestone acceptance only after these checks.

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
