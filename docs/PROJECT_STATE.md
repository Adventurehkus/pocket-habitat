# Pocket Habitat — Project State

## Snapshot and source of truth

- **Gameplay repository:** Adventurehkus/pocket-habitat
- **Gameplay branch:** ai/game-build
- **Source baseline checkout:** `c386349` (Run #40 cycle 2). The current working tree contains the quest-progression recovery fixes; the workflow persists changes to `ai/game-build`.
- **Documentation pipeline:** Main workflow configuration includes bounded cross-run continuation and quota-pool carry-forward; the provider-reset cutoff experiment was reverted (main workflow rollback: `647b5bd885d673dca3e31bb5b518e8b8da746800`).
- **Current workflow policy:** 100% of currently eligible quota pools across bounded fresh-run handoffs; repeated implementation/review/repair/validation/QA cycles; per-run counters reset between continuations while confirmed daily-quota exhaustion is carried forward; explicit validated versus recovery checkpoints; durable recovery notes on `ai/game-build`. No provider-reset calendar or pre-reset model-call cutoff is applied.
- **Verification boundary:** Run #40 cycle-1 review/QA and deterministic validation covered the historical recovery repairs. This continuation repaired two cycle-2 quest findings and adjudicated the malformed-progress finding as correctly fail-closed. Rojo, StyLua, Selene, and diff checks pass locally; focused TestEZ specs have not run, and these latest source edits have not received a separate pipeline review/QA decision. Roblox engine tests remain unexecuted.

This document is the live project snapshot. Re-read the actual branch head and inspect source before relying on any statement below. Run-specific facts are historical evidence, not a substitute for current source inspection.

## Current project status

The current source implements a server-owned join flow: automatic character loading is disabled, a DataStore session lease and saved data are acquired before habitat allocation, and the character is spawned/restored before client data is synchronized. Respawn requests are rate-limited and accepted only for a connected player with an active session and habitat whose character is dead or absent. Saved spawn coordinates are kept in memory as `Vector3`, encoded as numeric tables for DataStore compatibility, refreshed from the character during play, and bounded to the player's habitat when restored. The client can consume both initial session payloads and direct gameplay data updates.

`DataStoreManager` uses `UpdateAsync` for session acquisition, lease renewal, saving, and release. A failed operation, active foreign lease, malformed record, or unsupported schema does not expose a fabricated default session. The five-minute lease is renewed every two minutes with current session data. Existing legacy fields are normalized to the live gameplay schema; spawn vectors are serialized as numeric tables. Per-player resource cooldowns are now part of session data, schema-validated, and saved with the player's next periodic/final save; cooldown reservations occur before reward mutation and are rolled back when the reward is rejected. A crash before the next save can still lose the newest cooldown state. Final release is atomic and bounded. If it fails transiently, the in-memory session is retained and up to three release-only retries are scheduled at 5, 15, and 30 seconds; the departing session is not renewed indefinitely. A stale-token release is discarded because the server no longer owns that data. Shutdown now makes bounded synchronous release attempts against the absolute deadline to avoid retry tasks surviving process exit. Resource gathering requires an active session and living character, is server-rate-limited, and validates the owned node and interaction distance. These are source-level changes only; Roblox engine and actual DataStore behavior have not been tested.

**Current recovery status:** `docs/AUTONOMOUS_RECOVERY.md` is RESOLVED for the Run #38/39 and Run #40 cycle-2 automation-resolvable source findings. The cycle-2 quest progress bound and resource sync ordering fixes pass static validation; focused TestEZ specs and Roblox runtime gaps remain unverified.

**Current highest-priority task:** Execute the production-backed quest/resource TestEZ specs in a compatible runner, then verify progression, habitat isolation, and DataStore save/rejoin/contention in Roblox Studio. This environment has no compatible TestEZ runner or Roblox runtime.

The quest source now defines a single ten-quest order, migrates old sessions with no current quest to the next incomplete quest, and records gather, plant, water, harvest, discovery, and upgrade progress in backward-compatible session data. Upgrade progress is bounded by the matching upgrade definition. Resource reward sync now follows quest-progress recording, avoiding an intermediate client snapshot. Claims validate actual harvests, the specific Leafling discovery, and current upgrade levels; item rewards are capacity-checked and committed with Bells and quest completion without yielding between mutations. Completing the first-creature quest awards the Sun Petal seed required by the following quest. These are source-level changes; gameplay and the new TestEZ cases remain unverified in Roblox.

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
- `QuestRules` stores validated, server-recorded quest action counters. `QuestManager` uses the full ten-entry order; quest progress is backward-compatible in saved sessions, and objective checks no longer infer gather/plant/water/harvest progress from inventory or current plot state. Upgrade completion checks the saved level, and the Leafling objective checks that specific discovery.
- The first-creature quest awards a Sun Petal seed, making the next Sun Petal harvest objective obtainable; quest item rewards are capacity-checked and rolled back if reward delivery fails before claim completion.
- `HabitatManager` allocates non-overlapping per-server grid slots, reuses slots after removal, stores a per-server registry, and sets `OwnerUserId` metadata. Allocation is idempotent for a live folder.
- `WorldBuilder.buildHabitat(folder, owner, sessionData)` creates baseplate, resource, plot, path, and pond instances inside a habitat folder with BaseOffset applied exactly once to all geometry. **Restores saved plot state (planted seeds, growth stage, water count) from sessionData when provided.**
- `ResourceManager` stores independent node cooldowns in each player's session data, uses `ResourceRules.tryGrantReward` to reserve a cooldown before a reward mutation and roll it back if the reward is rejected, throttles gather requests per player, and validates session, living character, habitat node membership, and distance. The production helper has TestEZ coverage for rejected rewards and cooling-down nodes; TestEZ has not run. Cooldowns persist on the next session save, not immediately on each gather.
- `ServerMain` registers `PlayerAdded` before processing already-connected players and avoids duplicate initialization for the same UserId. It removes runtime habitat/cooldown state on PlayerRemoving.
- `PlantManager` now validates exact plot Instance membership in the calling player's habitat, server-measured interaction distance (25 studs), and validates that the plotIndex corresponds to an actual plot Instance. Includes plot position effects derived from server-resolved plot Instance positions.
- `ProximityHandler.client.lua` connects only to LocalPlayer's habitat, handles existing and newly added habitats, discovers prompts added during construction, and disconnects connections when the habitat is removed.
- **Recovery: `DataStoreManager` uses atomic lease acquisition/renewal/save/release, rejects failed or malformed loads without creating defaults, periodically saves the current in-memory session, serializes spawn coordinates as numeric tables, and retains in-memory state after a failed final release.** The Run #39 cycle-2 recovery record includes independent review/QA and validation evidence; runtime remains unverified.
- **Resource cooldowns:** Independent per-player/per-node timestamps are validated in shared production rules, persisted in the existing player-data envelope, and protected by a per-player request throttle. Production-backed TestEZ cases cover timestamp validity, cooldown expiry, rejected reward rollback, and requests to a cooling-down node; none have run. A crash before the next save may lose the latest cooldown.
- **New: `CreatureManager` scopes creature instances, behavior loops, and cleanup to the owning habitat/UserId. Each habitat has its own Creatures folder. Creatures have distinct models per type (bunny, sprite, leafling, tortoise, finch) with unique appearance and movement. Movement is bounded to habitat bounds. Discovered creatures are restored from session data on rejoin. Cleanup destroys only the leaving player's creatures.**
- Existing plant/economy/quest/creature source modules remain. Creature runtime is now fully player-scoped (Milestone 2 progress).
- TestEZ specifications exist for PlantRules/EconomyRules but were not executed in Run #32.

**Important:** The game is **NOT currently verified as a playable Roblox game**. Static gates do not establish server startup, character, multiplayer, or persistence behavior. Milestone 2 remains **IN PROGRESS and NOT COMPLETE**. Spawn/respawn and position restore now exist in source, but saved plot/world restoration, creature runtime isolation, and runtime verification of session leases remain.

## Autonomous workflow status

The `main` workflow supports a bounded cross-run continuation chain. When a run stops because of per-run model-call caps/cooldowns or the explicit total-call/round budget, it may queue a fresh workflow run if eligible quota pools remain. The child run checks out the latest `ai/game-build` checkpoint and reuses the original task and recovery note; run-local counters/cooldowns reset while confirmed exhausted quota pools are carried forward. The chain is limited to 8 additional runs or 24 hours.

The provider-reset cutoff experiment was reverted by main workflow commit `647b5bd885d673dca3e31bb5b518e8b8da746800`. The workflow no longer calculates provider reset boundaries, terminates model calls ahead of an expected reset, or prevents continuation because a reset window is approaching. The 100% eligible-pool quota target and ordinary bounded continuation/run safety limits remain active.

The shared continuation policy helper/tests are stored under `.github/scripts/` on `ai/game-build`. The reset-schedule functions and related test cases have been removed; the remaining tests cover bounded continuation and carrying forward confirmed exhausted quota-pool IDs. No reset-time cutoff is part of current workflow behavior.

Do not confuse the workflow-policy rollback with gameplay verification. The shutdown/session source fixes have prior review evidence. The recovery marker is RESOLVED for the enumerated source findings; latest quest changes have no separate pipeline review/QA decision, and Roblox runtime gaps remain open. Changes are local and not yet persisted by the workflow.

## Run #32 findings and current status

The historical source audit is `project-state/run-32-audit.md`; its findings describe the Run #32 checkpoint and are not all current source facts. In the current worktree, the startup API mismatch and stale quest-handler override are resolved, active habitat slots do not repeat, resource IDs are present on the server-owned Parts searched by `ResourceManager`, and prompt discovery watches existing and subsequently added prompts under only the local player's habitat. These fixes have not been exercised in Roblox.

Character startup/respawn and session persistence have been repaired in current source after Run #38 findings. The cycle-5 QA callsite claim was not applicable to the checked-in source; this follow-up also corrected DataStore acquisition, fail-closed loads, session lookup, lease renewal, atomic release, gameplay defaults, and client sync handling. Deterministic validation was rerun after the documentation edits and passed. Roblox runtime behavior and persistence isolation remain unverified.

Current remaining risks and gaps:

1. Character lifecycle, lease contention/renewal, persistence, and shutdown have no Roblox runtime verification; release retry timing and lease expiry are untested in-engine.
2. TestEZ has not been executed; production cooldown transaction and persistence/concurrency specs still need execution and broader coverage.
3. Resource cooldown state is saved on the next periodic or final write; a crash before that write can allow an early repeat gather after recovery.
4. **Source-level: Saved plot/world progression is now restored from session data on habitat load (implemented in WorldBuilder). Runtime verification pending.**
5. **Source-level: Creature runtime is now fully scoped to each player's habitat with distinct models and bounded movement (implemented in CreatureManager). Runtime verification pending.**

Do not mark checklist items complete based on a folder, helper module, static build, reviewer assertion, or generated .rbxl. Require source verification and runtime evidence at the appropriate level.

## Current next-task sequence

1. Execute TestEZ, especially the new production `ResourceRules` cooldown cases, in a compatible runner; `run-in-roblox`, `luau`, and `lune` are unavailable here.
2. Verify two-client gathering, independent cooldowns, character spawn/respawn, and habitat ownership in Roblox Studio.
3. Verify DataStore cooldown save/rejoin, lease contention, failed requests, and shutdown in Studio with test data.
4. Add and execute production-backed tests for session schema normalization and duplicate concurrent gather requests; rejected reward rollback now has a production-helper spec but remains unexecuted.

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

## Historical recovery checkpoint — Run #39 status (superseded)

At this historical checkpoint, Run #39 cycle 2 recorded independent review/QA and deterministic validation for the earlier recovery fixes. The cycle-5 independent review reported no findings for the cooldown transaction repair, but its QA stage did not produce a trustworthy decision, so recovery remained open then. The Run #40 cycle-1 recovery entry subsequently reports review, QA, and deterministic validation passed for these listed source repairs; see the current recovery status above. TestEZ and Roblox runtime tests remain unexecuted. Do not manually commit or push this work.