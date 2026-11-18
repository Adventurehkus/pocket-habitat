# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their real result.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test. Dependency installation is not test execution.
- Do not infer multiplayer, persistence, or security guarantees from a successful Rojo build.

## Latest workflow execution — Run 142 (2026-11-18; single-cycle pass)

Run 142 completed with a single meaningful cycle:
- Initial toolchain Rojo build: PASS.
- OpenCode model-registry preflight: PASS.
- Continuation-policy preflight test: PASS.
- Implementation: Updated `src/shared/Tests/Managers.spec.lua` with improved Luau type safety and session structure.
- Static check: tylua src + selene src: PASS.
- Roblox Studio/multiplayer/DataStore and TestEZ execution: NOT RUN in this environment.

## Verification checkpoint — 2026-11-17

Verified current repository source and autonomous recovery state:
- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS.
- `stylua --check src`: PASS.
- `selene src`: PASS (1 pre-existing warning unrelated to new manager spec).
- `git diff --check`: PASS.
- `.github/scripts/test-continuation-policy.sh`: PASS.
- **TestEZ: NOT RUN** (no compatible runner in this environment; spec file present and syntactically correct).
- **Roblox Studio, multiplayer, DataStore, and runtime playtesting: NOT RUN**.
- **Fixes:** Cleaned up `ClientMain.client.lua` for `stylua` compatibility.

Independent-QA gate: RUN 141 review accepted the manager-level TestEZ specs; the gate remains OPEN because runtime evidence is outstanding. The next run must execute TestEZ and provide a valid QA_BLOCKER: YES/NO first line; otherwise the gate remains OPEN until runtime evidence is gathered.

## Standard deterministic checks

Run the checks supported by the environment:
1. Validate project JSON and relevant manifests.
2. Build: `rojo build default.project.json -o build/pocket-habitat.rbxl`
3. Format check: `stylua --check src`
4. Lint: `selene src`
5. Diff hygiene: `git diff --check`
6. Continuation policy tests: `bash .github/scripts/test-continuation-policy.sh`
7. Inspect working tree: `git status --short`
8. **NEW**: Manager TestEZ specs: If TestEZ runner is available, run tests from `src/shared/Tests/Managers.spec.lua` and `src/shared/PocketHabitat.spec.lua` and record results verbatim.

## Studio testing procedure for habitat/multiplayer

1. **Habitat Allocation:** Verify separate, non-overlapping floating islands for multiple players.
2. **Resource Cooldowns:** Verify individual cooldowns per node/player and reward idempotency.
3. **DataStore Save/Rejoin:** Verify restoration of plant/growth/plot state; test crash-handling behavior.
4. **Creature Isolation:** Verify creatures are habitat-scoped and not visible/interactable by others.
5. **Multiplayer Isolation:** Ensure cross-player request rejection and correct server-side instance resolution.

## TestEZ runner status

- 2026-11-17: TestEZ provided in `DevPackages/TestEZ.lua`, but no TestEZ-compatible runner installed in the current environment. Specs present and valid; execution pending TestEZ runner and Roblox environment access.

## What will actually run in a workflow that we're targeting

When the workflow includes TestEZ:
- Run `pocket-habitat-tests` from TestEZ against `PocketHabitat.spec.lua` and `Managers.spec.lua`.
- Record test pass/fail results verbatim in the action output logs.
- If failure, examine stack traces and rule source lines.
- Keep dataset focused on production rules and bounded logic; external services mocked behind narrow adapters.