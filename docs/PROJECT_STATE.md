# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Latest durable gameplay/source baseline inspected by Run #37:** `5535a31b19897e17877cceae03b745678669ce66`. Subsequent commits on `ai/game-build` in this documentation update are documentation-only; Run #37's source changes were not pushed.
- **Latest dispatched autonomous workflow:** Run #37, ID `43315643648` (validation and QA passed in the temporary worktree; GitHub rejected checkpoint persistence with HTTP 500).
- **Workflow URL:** https://github.com/Adventurehkus/pocket-habitat/actions/runs/43315643648
- **Workflow configuration branch:** `main`.
- **Workflow head used by Run #37:** `a84e1e48a323b649f380930bc9f72ba6588fb1f2`.
- **Latest workflow configuration commit on main:** `3490233f6af9084dbc518d8b06936dff5190cfc0` (bounded checkpoint-push retries, ambiguous-push verification, concurrent-branch rebase handling, and expanded regression fixtures).
- **Current workflow policy:** 100% of currently eligible quota pools; repeated implementation/review/repair/validation/QA cycles; cross-cycle retries for recoverable agent/provider/code errors; explicit validated versus recovery checkpoints; durable recovery notes on `ai/game-build`.
- **Verification boundary:** Run #37 exercised recovery and its temporary worktree passed Rojo, StyLua, Selene, and `git diff --check`; independent review/QA completed with `QA_BLOCKER: NO`. GitHub rejected local commit `2fb9074` with HTTP 500, so those source edits were not persisted. The bounded push-retry helper is committed on `main`. A local shell reproduction using the same helper logic passed three bare-repository scenarios: a transient first-push rejection, an accepted push whose client received an error, and concurrent branch advancement with a safe rebase. The workflow's inline regression tests and GitHub Actions integration still need a fresh run.
- **Run #32 artifact:** `pocket-habitat-pipeline-32` (77,705 bytes, includes Rojo .rbxl build and stage/usage logs)
- **Run #32 result:** workflow completed successfully; implementation, review, repair, validation repair, QA, persistence, and artifact upload succeeded.
- **Current source warning:** The Run #32 `WorldBuilder.init()` mismatch is fixed in the current worktree. This run also removed a stale `QuestManager.claimQuest` override and fixed resource-node lookup, habitat-slot collisions, and prompt-discovery lifecycle; Roblox runtime behavior remains unverified.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

Pocket Habitat is **not currently verified as a playable Roblox game**. Run #37 generated and uploaded a Rojo `.rbxl` artifact and passed static checks in its temporary worktree, but its validated commit was not persisted because GitHub returned an HTTP 500 on push. The durable source branch still contains the unresolved ServerMain and DataStore defects described below. No Roblox engine, Studio, multiplayer, DataStore, or manual playtest has run.

Milestone 2 (personal habitats, multiplayer isolation, and safe persistence) remains **IN PROGRESS and NOT COMPLETE**. The source allocates non-overlapping active slots per server and contains an attempted cross-server lease implementation, but current DataStoreManager has source-level correctness gaps and is NOT safe/complete. Character spawn/respawn routing, saved habitat restoration, full player ownership validation, and Roblox runtime verification remain outstanding.

**Current highest-priority task:** reapply and independently verify the unpersisted Run #37 recovery work against the durable source baseline. In `src/server/ServerMain.server.lua`, change `game.BindToClose(onBindToClose)` to `game:BindToClose(onBindToClose)`, remove unused `Workspace` and `Constants`, and format with StyLua. Then repair `DataStoreManager.lua`: require the existing `RemoteEvents` module; atomically persist the current in-memory data only while `UpdateAsync` confirms the same session token; return and propagate save/release success; retain in-memory session data after any failed final save; and implement recurring lease renewal with cancellation and token checks. Do not mark persistence safe until source-level tests, independent review, deterministic validation, and QA pass. Keep real Roblox DataStore/multiplayer/shutdown tests outstanding. Then implement character spawn/respawn and saved habitat restoration.

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

**Important:** The game is **NOT currently verified as a playable Roblox game**. Run #37's temporary repair workspace passed the static checks, but its local commit was rejected by GitHub and did not reach `ai/game-build`. Direct inspection of the durable source at `5535a31b19897e17877cceae03b745678669ce66` confirms that `ServerMain.server.lua` still needs the `game:BindToClose(onBindToClose)` method call and removal of unused `Workspace`/`Constants` locals. `DataStoreManager.lua` still lacks the `RemoteEvents` import, writes old persisted data rather than current in-memory state through a non-atomic GetAsync/SetAsync sequence, clears in-memory state after failed save, and renews its lease only once. No Roblox runtime, Studio, multiplayer, DataStore, or manual playtests have been executed. Milestone 2 remains **IN PROGRESS and NOT COMPLETE**. Character spawn/respawn, saved-world restoration, creature runtime isolation, and runtime verification of session leases remain.

## Current autonomous workflow behavior (recovery exercised; checkpoint retry update awaiting Actions verification)

The workflow on `main` continues beyond the first successful implementation/review/QA pass. It repeats coherent implementation, independent review, conditional repair, deterministic validation, and QA cycles. Later cycles continue the original task if unfinished; otherwise they use the live project state and roadmap to advance to the next unfinished priority. Recoverable implementation, repair, review-format, QA-format/availability, and deterministic validation failures are now carried through fallback models and later cycles rather than immediately terminating the job.

The router rotates eligible models across cycles and allows previously successful models to be reused in later cycles. The quota target is now 100% of currently eligible pools: every pool still usable in this run must return an explicit daily/monthly quota-exhaustion error before quota-target completion. Google/Groq routes are counted per model; Cohere, OpenRouter, Cloudflare, and Copilot routes are grouped by provider/account. Permanently ineligible routes are excluded from the eligible denominator but are not counted as quota-exhausted. When no pools are measurable, the report shows 0% and does not claim the target. Quota exhaustion is reactive to provider error messages, not a live balance measurement.

Safety limits remain 8 calls per model, 120 calls total, 30 cycles, 2 hours of aggregate temporary-limit wait, two consecutive no-progress cycles, and the GitHub Actions 350-minute job timeout. Temporary per-stage failure deferrals reset each cycle so rate-limited and unclassified-error routes can be revisited after cooldown; confirmed quota blocks, permanent auth/model incompatibility, cooldown timestamps, and run-wide call budgets persist. Deterministic validation receives up to 5 repair attempts per cycle; QA blockers receive up to 3 repair/re-check attempts per cycle. Review/QA unavailable or malformed responses and unresolved validation are saved as explicitly unvalidated recovery checkpoints, with the issue recorded durably in `docs/AUTONOMOUS_RECOVERY.md` on `ai/game-build`. The next cycle/run prioritizes that file. The agent must mark it `RECOVERY_STATUS: RESOLVED` with evidence after automation-resolvable fixes pass independent review, QA, and deterministic validation; the resolved file is retained as an audit record and reopened automatically if a new recovery event occurs. Hard stops are limited to documented global budgets/timeouts, two consecutive no-progress cycles, unrecoverable checkpoint-persistence failure, no safe/meaningful work or eligible route, or all quota pools exhausted while recovery debt remains. A recovery checkpoint is never described as validated.

Run #37 (ID `43315643648`) exercised the recovery path. After recovery repair, the job log reports Rojo, StyLua, Selene (0 errors, 0 warnings), and `git diff --check` all passed; independent QA returned `QA_BLOCKER: NO`. The workflow created local commit `2fb9074`, but GitHub rejected its push with `remote: Internal Server Error` (request ID `B048:5D7CD:249E93:542A2E:6AF63AF8`). The run stopped with `cycle_checkpoint_persistence_failed`, correctly did not continue with uncheckpointed work, and uploaded artifact `pocket-habitat-pipeline-37` (ID `13988817790`). The durable gameplay branch remained at `5535a31b19897e17877cceae03b745678669ce66`; do not claim Run #37 source changes were persisted. The model routing warnings (temporary Google limits, OpenRouter shared quota exhaustion, and Groq request-size incompatibilities) were handled by existing cooldown/exclusion logic and were not the cause of this run's failure.

The `main` workflow was subsequently updated in `9fa4a470fbf138be51fb1f4dcf2be510dd1c3c55`, `dd35d65d52f2139bad5bde2f6afad4b409b3b8ab`, and `3490233f6af9084dbc518d8b06936dff5190cfc0`: validated and recovery checkpoint pushes plus the final persistence step now share a bounded five-attempt helper with exponential backoff, fetch-based confirmation of ambiguous pushes, and safe rebase for concurrent branch advancement. It never force-pushes. A local shell reproduction of the helper logic passed transient rejection, ambiguous accepted-push response, and concurrent branch advancement scenarios. The workflow's inline regression test function has not yet been executed by GitHub Actions; a fresh dispatch is still required. Provider account billing cannot be inspected by CI; call-count caps are not dollar-spend caps. Check provider free-tier status and spending limits before long runs.

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

1. Reapply Run #37's unpersisted ServerMain and DataStoreManager corrections on the current branch, verifying each against source rather than trusting the temporary agent summary.
2. Add/extend deterministic tests for atomic save of modified in-memory state, stale token rejection, failed-save memory retention, recurring lease renewal, and cancellation; run Rojo, StyLua, Selene, and `git diff --check`.
3. Obtain independent review and QA, then persist a validated checkpoint using the updated workflow push-retry path. Keep `docs/AUTONOMOUS_RECOVERY.md` OPEN until all automation-resolvable source items have evidence.
4. Execute Roblox Studio/server startup, two-client multiplayer, DataStore save/rejoin/contention, and shutdown tests when supported; do not claim these from static CI.
5. Add character spawn/respawn and restore saved habitat state before interactions are enabled.
6. Scope CreatureManager runtime to each player's habitat and clean it up with the player session.
7. Reassess milestone acceptance only after these checks.

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
