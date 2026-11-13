# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Last inspected source checkpoint:** `67cb832` (local implementation changes are uncommitted and not persisted).
- **Documentation pipeline:** Main workflow configuration at `3490233f6af9084dbc518d8b06936dff5190cfc0`
- **Current workflow policy:** 100% of currently eligible quota pools; repeated implementation/review/repair/validation/QA cycles; cross-cycle retries for recoverable agent/provider/code errors; explicit validated versus recovery checkpoints; durable recovery notes on `ai/game-build`.
- **Verification boundary:** Run #38 source recovery work is being repaired in this worktree. Independent review/QA and Roblox engine tests are pending; do not treat static checks as runtime proof.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

The current source implements a single server-owned join flow: automatic character loading is disabled, a DataStore session lease and saved data are acquired before habitat allocation, and the character is spawned/restored before client data is synchronized. Respawn requests are rate-limited and accepted only for a connected player with an active session and habitat whose character is dead or absent. Saved spawn coordinates are kept in memory as `Vector3`, encoded as numeric tables for DataStore compatibility, refreshed from the character during play, and bounded to the player's habitat when restored.

`DataStoreManager` now uses `UpdateAsync` to acquire, renew, save, and release a per-user session lease. Read failures, active locks, malformed records, and unsupported schema versions do not create or overwrite default data. Lease renewals also persist the current session every two minutes. Server shutdown attempts concurrent per-player release with a bounded wait. These are source-level changes only; Roblox engine and actual DataStore behavior have not been tested.

**Current recovery status:** `docs/AUTONOMOUS_RECOVERY.md` remains OPEN. This workspace has not run the required independent pipeline review/QA confirmation. The new TestEZ-shaped character-default spec and existing shared-rule specs were not executed because no compatible runner is available. Roblox Studio, multiplayer, save/rejoin, lease contention, failed DataStore calls, and shutdown behavior remain unverified.

**Current highest-priority task:** Execute TestEZ suites with compatible runner and complete independent review/QA of the current lifecycle/persistence recovery fixes. Do not start unrelated feature work or close recovery while that confirmation is pending. After independent review/QA, execute Roblox Studio two-client spawn/respawn, DataStore save/rejoin/contention, and shutdown tests to complete recovery resolution.

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
- **Recovery: `DataStoreManager` uses atomic lease acquisition/renewal/save/release, rejects failed or malformed loads without creating defaults, periodically saves the current in-memory session, serializes spawn coordinates as numeric tables, and retains in-memory state after a failed final release.** These current changes passed this pass's static checks but have not received independent review/QA.
- Existing plant/economy/quest/creature source modules remain. Creature runtime remains incompletely player-scoped (Milestone 2 incomplete), plot interaction validation is now implemented, creature runtime isolation still needs work (Milestone 2 incomplete).
- TestEZ specifications exist for PlantRules/EconomyRules but were not executed in Run #32.

**Important:** The game is **NOT currently verified as a playable Roblox game**. Static gates do not establish server startup, character, multiplayer, or persistence behavior. Milestone 2 remains **IN PROGRESS and NOT COMPLETE**. Spawn/respawn and position restore now exist in source, but saved plot/world restoration, creature runtime isolation, and runtime verification of session leases remain.

## Autonomous workflow status

The workflow policy is described in the guide and historical run records. Do not treat this local implementation pass as an independent review/QA cycle or a persisted validated checkpoint.

The current source worktree must first receive independent review and QA through the authorized pipeline. The current recovery marker stays OPEN until that evidence exists. No manual commit, push, or workflow persistence was performed by this pass.

## Run #32 findings and current status

The historical source audit is `project-state/run-32-audit.md`; its findings describe the Run #32 checkpoint and are not all current source facts. In the current worktree, the startup API mismatch and stale quest-handler override are resolved, active habitat slots do not repeat, resource IDs are present on the server-owned Parts searched by `ResourceManager`, and prompt discovery watches existing and subsequently added prompts under only the local player's habitat. These fixes have not been exercised in Roblox.

Character startup/respawn and session persistence have been repaired in current source after the Run #38 QA findings. Deterministic validation must be re-run after documentation and final source edits. Roblox runtime behavior and persistence isolation remain unverified.

Current remaining risks and gaps:

1. Independent review and QA confirmation of the current lifecycle/persistence changes.
2. Character lifecycle, lease contention/renewal, persistence, and shutdown have no Roblox runtime verification.
3. Saved plot/world progression is not restored before interactions.
4. Creature runtime is not fully scoped to each player's habitat.
5. TestEZ has not been executed; concurrent interaction and plot schema consistency still need test coverage.

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

1. Obtain independent review and QA of the current lifecycle/persistence changes and resolve any source blockers.
2. Execute the TestEZ suites with a compatible runner when one is available; this pass did not execute them.
3. Verify startup, character death/respawn, position restoration, DataStore contention/save/rejoin, and shutdown in Roblox Studio with at least two clients.
4. Restore saved plot/world progression before interactions are enabled; current source only restores character position and session data.
5. Scope CreatureManager instances, movement, and cleanup to each player's habitat.

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

The current worktree repairs the Run #38 QA findings and the actual DataStore/session defects found during source verification. Rojo, `stylua --check src`, and `selene src` pass on the current source; `git diff --check` is rerun after final docs. TestEZ and Roblox runtime tests remain unexecuted. The recovery marker stays OPEN until independent review/QA evidence is recorded. Do not manually commit or push this work.