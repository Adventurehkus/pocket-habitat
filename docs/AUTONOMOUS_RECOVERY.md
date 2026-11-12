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
- Keep this file until both priorities are fixed and their required verification is recorded. Remove it only as part of a reviewed, QA-inspected, deterministically validated checkpoint.
- When all automation-resolvable items are genuinely fixed, update the first status line to exactly `RECOVERY_STATUS: RESOLVED` and append a dated/run-specific evidence section with the CI commands/results and review/QA evidence. Keep any engine/runtime gaps explicitly outstanding in the project state. Never mark RESOLVED merely because one validator turned green.
- Do not start unrelated features, claim Milestone 2 persistence complete, or claim the experience release-ready while this note remains open.
- Never modify vendored `DevPackages/`, publish to Roblox, alter secrets/provider configuration, or weaken safety/validation checks.
