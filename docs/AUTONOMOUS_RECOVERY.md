# Pocket Habitat — Autonomous Recovery Required

RECOVERY_STATUS: OPEN

- Source of this recovery debt: Run #34, GitHub Actions run ID `43131314450`
- Run URL: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43131314450
- Gameplay source checkpoint from that run: `8c9c2fa8cfc06f0b85fd5fae781b81cb14ed6d66`
- Status: **OPEN — do not treat the current source as deterministically validated or release-ready.**
- This recovery note is intentionally committed to `ai/game-build` so the autonomous workflow loads it before starting unrelated feature work.

## Priority 1 — Repair the deterministic validation failures

Run #34 produced a Rojo build, but final deterministic validation failed:

1. In `src/server/ServerMain.server.lua`, change `game.BindToClose(onBindToClose)` to the Roblox method call `game:BindToClose(onBindToClose)`.
2. Remove the unused `Workspace` and `Constants` locals reported by Selene, unless a verified implementation need exists for them.
3. Format project-owned source under `src/` using the pinned StyLua toolchain. Do not format the repository root or vendored dependencies.

Required verification before clearing this part of the recovery debt:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`
- `stylua --check src`
- `selene src`
- `git diff --check`

Do not weaken lint configuration, skip checks, or declare success without rerunning the actual commands.

## Priority 2 — Correct DataStoreManager before claiming persistence is safe

Source inspection of `src/server/DataStoreManager.lua` found these additional defects that must be corrected before persistence is marked complete:

1. The module calls `RemoteEvents.SyncData:FireClient` but does not require `src/shared/RemoteEvents.lua`. Verify the module's actual path and initialization before adding the dependency.
2. With a session token, `savePlayerData` currently performs `GetAsync`, reads `record.data`, then `SetAsync` writes that same old stored data. It does not write the changed current in-memory session data. Correct this so the actual current session state is persisted.
3. The `GetAsync` / `SetAsync` ownership check is not atomic. Use an ownership-checked `UpdateAsync` operation that verifies the session token and writes the current in-memory data as one atomic update. A stale server must not overwrite a newer owner's data.
4. `releaseSession` currently clears `activeSessions[userId]` even if `savePlayerData` failed. Make save/release return and propagate success explicitly; retain the only in-memory copy and session ownership state when the final save fails. Do not report a successful release when persistence failed.
5. Lease renewal is scheduled using a one-time `task.delay` in acquisition/request paths. `renewSession` does not schedule the next renewal, so the lease does not recur. Implement a bounded, recurring renewal lifecycle with cancellation/cleanup and token ownership checks.
6. Verify shutdown behavior and avoid clearing session data or releasing ownership unless the final save/release sequence actually succeeds. Handle DataStore errors and shutdown time budgets honestly.

Required verification for the source-level recovery:

- Add/extend tests against the production session/save helpers where the current runner permits.
- Test atomic acquisition contention and rejection of stale session tokens.
- Test persistence of modified in-memory data, not only the previously stored record.
- Test failed Get/Update/Set operations and prove the in-memory state is retained after failure.
- Test recurring lease scheduling/cancellation and token ownership in deterministic tests where possible.
- Run Rojo, StyLua, Selene, and `git diff --check`; independent reviewer and QA must verify each source fix.

Roblox DataStore integration, real multi-server contention, PlayerRemoving/BindToClose under the engine, save/rejoin, and crash recovery may require Roblox Studio or a supported Roblox runtime unavailable in this GitHub runner. Do not claim these passed unless actually executed. Keep those acceptance items unchecked in `docs/PROJECT_STATE.md` and `docs/ROADMAP.md`. Their runtime verification remains required before Milestone 2 or persistence is called complete, but an unavailable engine-level test must not cause the autonomous workflow to loop forever: the recovery note may be marked resolved for its automation-resolvable source fixes once the source is corrected, deterministic CI passes, independent review and QA confirm the fixes, and all unexecuted runtime checks are explicitly recorded as outstanding.

## Agent instructions

- Read `AGENTS.md`, `docs/AUTONOMOUS_AGENT_GUIDE.md`, `docs/PROJECT_STATE.md`, `docs/ROADMAP.md`, `docs/TECHNICAL_ARCHITECTURE.md`, and `docs/TESTING.md` before changing source.
- Fix Priority 1 first so the workflow's deterministic validation gate is green.
- Then address Priority 2 without discarding correct work or changing save-key compatibility.
- Obtain independent code review, run deterministic validation, and obtain independent QA after changes.
- Keep this file as the durable recovery record. When all automation-resolvable items are genuinely fixed, update the first status line to exactly `RECOVERY_STATUS: RESOLVED` and append a dated/run-specific evidence section with CI commands/results and independent review/QA evidence. The workflow retains a resolved record in Git as audit evidence and ignores it on later starts. A new recovery event reopens the same record to `RECOVERY_STATUS: OPEN`.
- Keep any engine/runtime gaps explicitly outstanding in the project state. Never mark RESOLVED merely because one validator turned green.
- Do not start unrelated features, claim Milestone 2 persistence complete, or claim the experience release-ready while this note remains open.
- Never modify vendored `DevPackages/`, publish to Roblox, alter secrets/provider configuration, or weaken safety/validation checks.


## Run #37 — source recovery attempted, but checkpoint was not persisted

- Run: #37, GitHub Actions run ID `43315643648`
- Workflow URL: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43315643648
- Workflow configuration head used by the run: `a84e1e48a323b649f380930bc9f72ba6588fb1f2`
- Durable gameplay branch head checked out by the run: `5535a31b19897e17877cceae03b745678669ce66`
- The recovery record was loaded and the agent attempted Priority 1/2 repairs. Its local report says it adjusted DataStoreManager formatting and changed `releaseSession` to retain in-memory data when the final save fails. The run also reported that ServerMain's BindToClose call/import cleanup and the RemoteEvents import were already corrected in that temporary worktree.
- After targeted validation repair, the job log reports Rojo build PASS, `stylua --check src` PASS, Selene PASS (0 errors, 0 warnings, 0 parse errors), and `git diff --check` PASS. The independent QA response was `QA_BLOCKER: NO` and recorded the remaining Roblox Studio/runtime tests as unexecuted.
- A local validated commit was created (short SHA shown in the log: `2fb9074`; four files changed). The push to `ai/game-build` was rejected by GitHub with `remote: Internal Server Error` (request ID `B048:5D7CD:249E93:542A2E:6AF63AF8`). The pipeline correctly refused to continue without a durable checkpoint.
- At the time of Run #37, `ai/game-build` remained at `5535a31b19897e17877cceae03b745678669ce66`. Subsequent commits on that branch updated documentation only; the source files were rechecked and still contain the open ServerMain/DataStore defects. Therefore the Run #37 local source edits are **not part of the durable branch** and must not be treated as implemented. Reinspect the current source and reapply/reverify the outstanding fixes.

The Run #37 route warnings (temporary Google rate limits, OpenRouter shared quota exhaustion, and Groq request-size incompatibilities) were handled by the existing route cooldown/exclusion logic; they were not the cause of the failed job. Static validation and QA had completed before GitHub rejected the checkpoint push.

The workflow's push handling was subsequently updated on `main` (commits `9fa4a470fbf138be51fb1f4dcf2be510dd1c3c55` and `dd35d65d52f2139bad5bde2f6afad4b409b3b8ab` to retry transient push failures, confirm ambiguous accepted pushes, and rebase over concurrent branch advancement without force-pushing. That change has not yet been exercised by a fresh GitHub Actions run. Keep this recovery record OPEN until the source-level items are genuinely fixed, verified, QA-reviewed, and durably persisted.
