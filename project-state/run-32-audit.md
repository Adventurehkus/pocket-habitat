# Run #32 audit — actual status, blockers, and next work

> Historical audit of Run #32's committed checkpoint (`1af27d2aade0922f57ec4333bf5d5331366d7b9b`). Its source findings and "current" labels apply to that checkpoint, not the current worktree. See `docs/PROJECT_STATE.md` for current status.

## Executive status

- Workflow: **completed successfully**.
- Gameplay milestone 2 (personal habitats, multiplayer isolation, and reliable persistence): **NOT COMPLETE**.
- Playable Roblox runtime: **NOT VERIFIED; the Run #32 source had a startup blocker**.
- Run #32 did not stop because every model was exhausted. Several routes were unavailable, but fallback models completed every required stage.
- Do not use the Run #32 QA summary or the older `project-state/milestone-2-fixes.md` claims as the source of truth without checking the source. The QA output missed a critical startup defect and made incorrect claims about habitat placement/spawning.

Run details:
- Workflow run: #32, ID `43119650837`.
- Run URL: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43119650837
- Workflow head: `main` at `b37935206db380e99731d4082c2f9f803954a76e`.
- Gameplay branch checkpoint: `ai/game-build` commit `1af27d2aade0922f57ec4333bf5d5331366d7b9b` (`AI staged development checkpoint 32`).
- Artifact: `pocket-habitat-pipeline-32`, 77,705 bytes; includes `build/pocket-habitat.rbxl` (49,722 bytes), stage logs, agent report, and model usage TSV.
- CI: Rojo build passed; StyLua `--check src` passed with 0 errors/warnings/parse errors; Selene passed; `git diff --check` was run by the repair agent and passed after formatting. TestEZ and Roblox runtime tests were not run.

## What Run #32 actually changed

The gameplay commit changed:
- `src/server/HabitatManager.lua` (new): creates a `Workspace.Habitats` folder, allocates `Habitat_<UserId>` folders, sets a BaseOffset attribute, and tracks a per-server UserId-to-folder table.
- `src/server/WorldBuilder.lua`: adds `buildHabitat(folder, owner)` and constructs a habitat beneath its folder.
- `src/server/ServerMain.server.lua`: requires HabitatManager and calls allocation after data load; calls habitat removal on PlayerRemoving.
- `src/server/ResourceManager.lua`: replaces the old shared cooldown state with an in-memory per-UserId/per-node cooldown table.
- `src/client/ProximityHandler.client.lua`: changes prompt discovery to work with a Habitats folder.
- `docs/PROJECT_STATE.md`, `docs/ROADMAP.md`, and this project-state directory received documentation changes.

The per-player cooldown table and PlayerRemoving habitat-folder cleanup are present in the committed source. They are partial improvements, not proof of complete resource isolation or a correct habitat lifecycle.

## Verified source defects and incomplete requirements

### P0 — Server startup calls a missing function

- `src/server/ServerMain.server.lua` calls `WorldBuilder.init()` near the beginning of the startup script.
- The Run #32 version of `src/server/WorldBuilder.lua` defines `WorldBuilder.buildHabitat(folder, owner)`, but no longer defines `WorldBuilder.init()`.
- The parent commit's WorldBuilder did define `init()`; Run #32 removed it without updating ServerMain.
- Result inferred directly from source: the startup script attempts to call nil and stops before the subsequent ResourceManager/QuestManager/PlantManager/HabitatManager initialization and PlayerAdded/PlayerRemoving connections. No Roblox runtime execution was performed, so describe this as a source-confirmed startup blocker, not as a runtime log observed in Studio.
- Fix by establishing one consistent API: remove the obsolete call if no global world initialization is needed, or add a correct init function. Then verify startup under Roblox, including all remote handlers and player lifecycle subscriptions.

### P1 — Habitat placement is not non-overlapping

- `HabitatManager.allocateHabitat` computes `BaseOffset = Vector3.new((UserId % 1000) * 0.1, 0, (UserId % 1000) * 0.1)`.
- Each habitat baseplate is 100 by 100 studs.
- This places habitats only 0.1 studs apart along the X=Z diagonal, within a 0–99.9 stud span, and repeats every 1,000 UserIds. It cannot isolate 100-stud habitats and will cause substantial overlap.
- Replace this with a deterministic slot/grid allocator that uses actual habitat bounds plus generous spacing, handles slot collisions and server capacity, and does not reuse a slot while an active habitat owns it. Do not use a UserId modulus as the sole slot allocator.

### P1 — WorldBuilder applies offsets inconsistently

In `src/server/WorldBuilder.lua`:
- Resource node base parts are passed positions that already include BaseOffset, but tree leaves and berry parts add BaseOffset a second time. Those decorations will be displaced from their resource nodes.
- Plot positions already include BaseOffset, but plot borders add BaseOffset again.
- Path segment positions and CFrame look-at targets are computed around world origin rather than consistently around the owning habitat's local origin/offset.
- Refactor to calculate all geometry in local habitat coordinates and apply the habitat transform exactly once. Prefer a Model/pivot or one explicit origin transform rather than scattered offset additions. Validate every descendant's world position against the same origin.

### P1 — Character spawn/respawn is not implemented

- `HabitatManager.lua` only allocates, looks up, and destroys folders. It does not place/position a character.
- `ServerMain.server.lua` does not connect CharacterAdded or move the character to a spawn point inside the player's habitat.
- The previous Run #32 docs falsely marked correct spawn/respawn handling as complete. Mark it incomplete until implemented and tested.
- Add server-owned spawn placement after the habitat is built and on every respawn; handle characters that spawn before/after habitat creation without racing or teleporting into another player's plot.

### P1 — Saved world state is not restored

- `ServerMain.server.lua` loads player data, but calls `HabitatManager.allocateHabitat(player)` without passing the loaded data.
- `WorldBuilder.buildHabitat` constructs starter resources and plots; it does not restore saved plot/plant states, resource states, purchased expansion geometry, or creature state.
- The current saved default data shows two plot entries while WorldBuilder creates four plot parts; reconcile the data/schema and actual world plot count rather than assuming they match.
- Implement schema-validated data-to-world reconstruction before syncing the player into a usable habitat. Do not overwrite existing progress with default world state.

### P1 — Plot remotes do not verify the actual owned plot or player distance

- `PlantManager.handleInteraction` validates the Player session and calls PlantRules using a numeric plotIndex/action, but it does not resolve that index to a plot Instance inside the caller's registered habitat.
- It does not validate that the character is within interaction distance of the actual plot.
- A client can invoke the RemoteFunction directly without using the corresponding prompt; server-side rules must remain authoritative.
- Add HabitatManager lookup, exact plot membership/owner validation, character/root-part checks, server-measured distance, and session checks before mutating plot data.
- `PlantManager` uses fixed `PLOT_POSITIONS` for effects, with no habitat offset. Effects will appear at the old shared-world coordinates for offset habitats; derive effects from the server-resolved plot Instance position.

### P1 — Resource remote is not bound to the exact server-owned node

- `ResourceManager` now has per-UserId/per-node cooldown tracking; this part is present.
- The remote accepts only a nodeId string and resolves a static template/position. It does not receive or validate an exact resource Instance from the caller's own registered habitat, nor does it validate that the habitat lookup succeeded before falling back to a zero offset.
- The server must resolve the node itself from the calling player's registered habitat, confirm node identity and ownership, verify the character is close to that exact instance, and verify the session is active. Never trust a client-supplied OwnerUserId or position.
- Cooldown is currently assigned before `EconomyManager.addItem` succeeds. If inventory is full, the player receives no reward but still receives the cooldown. Move the cooldown update after a successful reward transaction, or roll it back safely on failure.
- Cooldowns are in-memory only and are not persisted. Decide/document whether that is intended; do not claim resource availability restoration is complete.

### P1 — Client prompt discovery has lifecycle and ownership hazards

- `ProximityHandler.client.lua` subscribes to `Habitats.ChildAdded` and calls `ConnectToFolder(child)` for any habitat folder; it does not restrict the folder to `Habitat_<LocalPlayer.UserId>`.
- `ConnectToPlayerHabitat(_player)` is only invoked from a `Players.PlayerAdded` listener filtered to LocalPlayer. LocalPlayer may already have joined before the LocalScript registers the listener; there is no unconditional initial call to discover an already-existing own habitat.
- A folder's ChildAdded callback may scan before WorldBuilder has finished adding descendant prompts; there is no general DescendantAdded connection in the global path. The separate own-habitat helper waits for GardenPlots only if invoked, but the startup race is not resolved.
- Connect only to the local player's habitat, perform an immediate existing-folder lookup during LocalScript initialization, and observe later descendant prompt additions/removals without duplicate connections. Validate all actions on the server regardless of prompt visibility.

### P1 — Persistence is not safe across servers, and failed saves can discard in-memory data

- `DataStoreManager.lua` still uses GetAsync/SetAsync and a process-local `activeSessions` table. There is no atomic UpdateAsync session token/lease, renewal, ownership-checked save, or cross-server lock.
- `removeSession` calls savePlayerData and then clears `activeSessions[userId]` unconditionally. savePlayerData only warns after all retries fail and does not report success to removeSession. Thus a failed final save can be followed by discarding the only in-memory copy.
- Add schema/type validation and safe migrations; preserve `PocketHabitat_v2_PlayerData`. Implement atomic session acquisition, expiring lease, renewals, token-checked save and release, bounded shutdown handling, and failure-safe final save semantics. A failed load must never be treated as a new player.
- Test simultaneous same-user joins across servers, lease expiration/recovery, stale owner writes, throttling, malformed data, save failure, leave, and BindToClose.

### P1 — Creature runtime remains shared

- Run #32 did not refactor `CreatureManager.lua` into per-habitat ownership. The existing project-state/architecture finding remains: runtime folder/registry and movement behavior are not fully scoped to a player habitat.
- Verify current source before implementing; then parent each player's creatures beneath their habitat, key registries by UserId plus creature identity, constrain movement to that habitat, and clean only that player's instances/connections.

### P2 — Additional lifecycle/idempotency concerns

- Make habitat allocation idempotent: do not create a second folder if a player already has one; reject stale/duplicate registry entries safely.
- Set/verify server-owned OwnerUserId metadata for diagnostics, but use the server registry and Player argument for authorization.
- Remove per-player cooldown/connection state on departure.
- Ensure BindToClose saves all active sessions with bounded concurrency and does not clear state before success.
- Test concurrent duplicate resource/plot requests, remote spam, respawn, rejoin, and disconnect during save.

## QA report corrections

The Run #32 QA log said that spawning was wired, that the BaseOffset formula solved overlap, and that prompts were initialized robustly. Source inspection contradicts those claims:
- There is no character spawn/respawn placement in HabitatManager or ServerMain.
- The 0.1-stud diagonal offset cannot separate 100-stud baseplates.
- The startup API mismatch `WorldBuilder.init()` is a blocking regression the QA agent missed.
- The review's claim that cleanup was missing is stale relative to the final committed ServerMain: `HabitatManager.removeHabitat(player)` is called on PlayerRemoving.
- The review's claim of a `LocalPlayer.PlayerAdded` property error is also stale relative to the final committed source, which uses `Players.PlayerAdded`; the real issue is the missing unconditional LocalPlayer habitat discovery call and event-order race described above.
Do not blindly repeat the reviewer findings. Verify against current source and the final committed checkpoint.

## Run #32 model usage and quota interpretation

The artifact's `_temp/pocket-habitat-model-usage.tsv` and agent report record:
- Models configured: 20.
- Daily/shared quota exhaustion events: 3.
- Automatic temporary-limit wait: 0 seconds across 4 classified events.
- Implementation succeeded with Cohere North Mini Code after several Google rate-limited/model-exhausted routes and Cloudflare shared quota exhaustion.
- Review succeeded with Google Gemini 3.5 Flash Lite.
- Repair succeeded with Cohere Command A+.
- Validation repair succeeded with GitHub Copilot Auto after some Groq request-size skips and OpenRouter shared quota exhaustion.
- QA succeeded with Google Gemini 3.1 Flash Lite.
- All required stages succeeded; review-fallback and qa-repair were not needed.
- This proves the workflow did **not** end because all configured models were exhausted. It does not prove that all 20 configured models were available or attempted, nor does it reveal remaining account balances after the run.

## Required next sequence

1. Fix and test the missing WorldBuilder startup API before any additional gameplay work.
2. Correct habitat slot placement and apply offsets exactly once; verify the full geometry.
3. Make local-player prompt discovery reliable and server-validate exact owned plot/resource instances and distance.
4. Implement spawn/respawn and safe save restoration, then cleanup/idempotency.
5. Implement cross-server DataStore session leases and failure-safe saves.
6. Isolate creature runtime state.
7. Add automated unit/integration tests and execute them in a compatible runner; perform two-client Roblox Studio/DataStore testing.
8. Only then reassess Milestone 2 acceptance.

Do not mark Milestone 2 complete or call the game playable until its acceptance criteria are implemented and verified. No Roblox runtime or Studio test was executed in Run #32.

## Follow-up: why Run #32 stopped and the workflow fix

The Run #32 usage TSV showed the old pipeline's short-circuit behavior:
- Each required stage returned immediately after its first successful model.
- A model that had only hit a temporary RPM/TPM limit was placed on cooldown, but once another model succeeded the stage returned and the cooldowned model was never revisited later in the run.
- Successful models were globally marked attempted, so they could not be reused in a later implementation pass.
- The pipeline had one implementation/review/repair/validation/QA sequence, not a repeated work loop.
- Result: the workflow completed all stages even though additional model routes and quota pools had not been used or exhausted. Some OpenRouter routes were correctly skipped because OpenRouter's shared pool was already exhausted; that is different from an unused provider pool.

The workflow on `main` was subsequently changed:
- Multi-cycle router commit: `d5e4a14b3d433f40fbb16e233533b98ee1dd9858`.
- Round-robin and router fixtures/checkpoint persistence: `519de8cea3df3fdf3e719399ec7d7e804c01a4e3`.
- Aggregate temporary-wait cap set to 2 hours: `658bb50bad7060dc0ae99760ac673c748684cac4` (latest workflow configuration commit at this audit update).
- Later cycles reuse successful models after resetting same-cycle role exclusion, rotate candidates, re-attempt cooled-down routes, and continue meaningful roadmap work.
- The configured stop target is 75% of eligible quota pools confirmed exhausted by explicit daily/monthly quota errors.
- Current hard limits: 8 calls/model, 120 total model calls, 30 cycles, 2 hours aggregate temporary wait, 2 consecutive no-progress cycles, and the 350-minute job timeout.
- Each reviewed and validated cycle is pushed to `ai/game-build` before the next cycle, protecting progress if the run later times out.

**Important limits:** quota-pool count is a routing heuristic, not a precise API balance. Google/Groq are treated as model-scoped; Cohere/OpenRouter/Cloudflare/Copilot are treated as provider/account-scoped. The workflow cannot query providers' real remaining balance. A transient per-minute limit does not count as daily exhaustion. The 120-call cap is a request-count cap, not a money cap; verify provider billing/free-tier settings and spending limits before a long run.

**Verification status:** this new multi-cycle behavior is committed but has not yet been live-tested. Run #32 only tested the previous one-pass implementation/review/repair/QA orchestration. A new dispatch is needed to exercise the loop and its regression fixtures. No new model-consuming run was triggered during this workflow/documentation update.
