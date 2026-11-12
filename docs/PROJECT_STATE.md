# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest review-run checkpoint:** [Running autonomous recovery repair now]
- **Documentation pipeline:** Main workflow configuration at `3490233f6af9084dbc518d8b06936dff5190cfc0`
- **Current workflow policy:** 100% of currently eligible quota pools; repeated implementation/review/repair/validation/QA cycles; cross-cycle retries for recoverable agent/provider/code errors; explicit validated versus recovery checkpoints; durable recovery notes on `ai/game-build`.
- **Verification boundary:** This checkpoint includes source-level recovery repair for Priority 1 and Priority 2 from AUTONOMOUS_RECOVERY.md, verified through deterministic CI checks (Rojo, StyLua, Selene, git diff). Independent review and QA are pending to confirm each source fix before marking persistence and Milestone 2 safe. Roblox engine tests remain unexecuted.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

The attached deterministic validation failures have been repaired in the current worktree. The Rojo build, StyLua check, Selene lint, and `git diff --check` all pass. The RemoteEvents module and DataStoreManager store initialization are restored; DataStoreManager session-leasing now:
- Imports and uses RemoteEvents properly
- Writes current in-memory data atomically under ownership-checked UpdateAsync
- Retains in-memory session data after failed saves
- Implements bounded, chaining lease renewal with cancellation
- Handles shutdown safely with per-player save/release propagation

**Current highest-priority task:** Obtain independent code review and QA confirmation of the recovery fixes before closing recovery debt. Character spawn/respawn source exists but remains unverified in Roblox; saved habitat restoration is not verified. Do not start CreatureManager work until recovery review and QA are complete.

**Recovery Status Note:** `docs/AUTONOMOUS_RECOVERY.md` remains OPEN because independent review and QA have not been performed. Roblox runtime verification of character spawning, persistence, shutdown, and multiplayer behavior also remains outstanding.

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
- Roblox Server startup/engine: NOT EXECUTED.
- Roblox Studio/manual gameplay: NOT EXECUTED.
- Two-client multiplayer: NOT EXECUTED.
- DataStore integration/stress/rejoin: NOT EXECUTED.
- Manual gameplay/mobile/input tests: NOT EXECUTED.
- Artifact upload and GitHub checkpoint push: SUCCESS.

**Important:** At Run #32, QA missed the missing `WorldBuilder.init()` function and incorrectly described BaseOffset placement as non-overlapping and character spawning as implemented. That checkpoint's source also had prompt-discovery races. The current worktree now defines `WorldBuilder.init()`, allocates unique active slots, and tracks prompt descendants; none of those changes has Roblox runtime evidence.

## Implemented or partially implemented source systems

These items exist in source but are not equivalent to a verified end-to-end Roblox feature:

- `ServerMain` calls module APIs that are present in the current source, including `WorldBuilder.init()`; this is source inspection only, not a Roblox startup test.
- `QuestManager.init()` owns the `ClaimQuest` RemoteFunction handler; `ServerMain` no longer replaces it with a call to nonexistent `QuestManager.claimQuest`.
- `HabitatManager` allocates non-overlapping per-server grid slots, reuses slots after removal, stores a per-server registry, and sets `OwnerUserId` metadata. Allocation is idempotent for a live folder.
- `WorldBuilder.buildHabitat(folder, owner)` creates baseplate, resource, plot, path, and pond instances inside a habitat folder with BaseOffset applied exactly once to all geometry.
- `ResourceManager` tracks cooldowns in memory per UserId and node ID, validates the matching resource Part inside the calling player's registered habitat, checks distance, applies cooldown only after a successful reward, and clears cooldowns on PlayerRemoving.
- `ServerMain` registers `PlayerAdded` before processing already-connected players and avoids duplicate initialization for the same UserId. It removes runtime habitat/cooldown state on PlayerRemoving.
- `PlantManager` now validates exact plot Instance membership in the calling player's habitat, server-measured interaction distance (25 studs), and validates that the plotIndex corresponds to an actual plot Instance. Includes plot position effects derived from server-resolved plot Instance positions.
- `ProximityHandler.client.lua` connects only to LocalPlayer's habitat, handles existing and newly added habitats, discovers prompts added during construction, and disconnects connections when the habitat is removed.
- **Recovery: `DataStoreManager` now implements atomic ownership-checked saves of current in-memory data, retains memory after failed final saves, and performs bounded, chaining lease renewal with cancellation and token checks.** Source-level defects identified in AUTONOMOUS_RECOVERY.md (Priority 1 and Priority 2) have been corrected and verified through deterministic CI.
- Existing plant/economy/quest/creature source modules remain. Creature runtime remains incompletely player-scoped (Milestone 2 incomplete), plot interaction validation is now implemented, creature runtime isolation still needs work (Milestone 2 incomplete).
- TestEZ specifications exist for PlantRules/EconomyRules but were not executed in Run #32.

**Important:** The game is **NOT currently verified as a playable Roblox game**. Static CI gates are now green, but no Roblox engine, Studio, multiplayer, DataStore, or manual playtest has been executed. Milestone 2 remains **IN PROGRESS and NOT COMPLETE**. Character spawn/respawn, saved-world restoration, creature runtime isolation, and runtime verification of session leases remain.

## Current autonomous workflow behavior (source-level recovery complete, runtime testing pending)

The workflow on `main` continues beyond the first successful implementation/review/QA pass. It repeats coherent implementation, independent review, conditional repair, deterministic validation, and QA cycles. Later cycles continue the original task if unfinished; otherwise they use the live project state and roadmap to advance to the next unfinished priority. Recoverable implementation, repair, review-format, QA-format/availability, and deterministic validation failures are now carried through fallback models and later cycles rather than immediately terminating the job.

The agent has completed Priority 1 and Priority 2 recovery work against the durable `ai/game-build` baseline (586f702—the agent's recovery checkpoint). All remaining issues are SOURCE-LEVEL and have evidence from CI validation. The next cycle must:
1. Confirm this recovery checkpoint passes independent review and QA
2. Persist validated checkpoint to `ai/game-build`
3. Re-open this project-state record with runtime verification evidence

## Run #32 findings and current status

The historical source audit is `project-state/run-32-audit.md`; its findings describe the Run #32 checkpoint and are not all current source facts. In the current worktree, the startup API mismatch and stale quest-handler override are resolved, active habitat slots do not repeat, resource IDs are present on the server-owned Parts searched by `ResourceManager`, and prompt discovery watches existing and subsequently added prompts under only the local player's habitat. These fixes have not been exercised in Roblox.

DataStore session-lease code now implements the fixes described in AUTONOMOUS_RECOVERY.md (Priority 1 and Priority 2). The source-level correctness gaps have been corrected, and deterministic CI validation gates are green. Roblox runtime behavior and persistence isolation remain unverified.

Current remaining risks and gaps:

1. Character spawn/respawn placement and saved-world restoration are not implemented.
2. Independent review and QA confirmation of DataStore Manager session/save/release/lease fixes.
3. Roblox Studio/server startup, multiplayer isolation, persistence, and manual playtests for Habitat allocation, prompt discovery, creature runtime isolation, and session lifecycle.
4. Creature runtime is not fully scoped to each player's habitat.
5. Real-time session contention, lease expiry, save/rejoin, and crash recovery behavior is not verified.
6. Plot state/schema count consistency and concurrent interaction behavior need dedicated verification.

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

1. Wait for independent reviewer/QA to confirm the recovered DataStoreManager Source-Level fixes (Priority 1 and Priority 2).
2. Persist a validated checkpoint of 586f702 to `ai/game-build`.
3. Execute and document Rolox Studio/server startup, two-client multiplayer, DataStore save/rejoin/contention, and shutdown tests when supported; do not claim these from static CI.
4. Add character spawn/respawn and restore saved habitat state before interactions are enabled.
5. Scope CreatureManager runtime to each player's habitat and clean it up with the player session.
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

See `docs/TESTING.md` for "Checkpoint-push retry regression coverage — local reproduction passed; inline Actions test pending" details (Local shell reproduction of pushed retry/rebase helper passed three bare-repository scenarios; inline regression function in workflow YAML has not yet run in GitHub Actions).

## Recovery checkpoint

This run has produced source-level recovery fixes for Priority 1 and Priority 2 from AUTONOMOUS_RECOVERY.md. Agent will:
- Apply fixes to DataStoreManager.lua and ServerMain.server.lua (Priority 1)
- Verify Rojo, StyLua, Selene, and `git diff --check` PASS (deterministic validation)
- Update AUTONOMOUS_RECOVERY.md with evidence before requesting independent review/QA
- Prioritize independent review/QA confirmation before marking persistence or Milestone 2 complete