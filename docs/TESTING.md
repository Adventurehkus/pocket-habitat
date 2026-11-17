# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their real result.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test. Dependency installation is not test execution.
- Do not infer multiplayer, persistence, or security guarantees from a successful Rojo build.

## Verification checkpoint — 2026-11-17 (Recovery Resolved)

Verified current repository source and autonomous recovery state on 2026-11-17:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS.
- `stylua --check src`: PASS.
- `selene src`: PASS.
- `git diff --check`: PASS.
- `.github/scripts/test-continuation-policy.sh`: PASS.
- TestEZ: NOT RUN (no compatible runner).
- Roblox Studio, multiplayer, DataStore, and runtime playtesting: NOT RUN.

Active recovery status is now RESOLVED per `docs/AUTONOMOUS_RECOVERY.md`.

## Standard deterministic checks

Run the checks supported by the environment:

1. Validate project JSON and relevant manifests.
2. Build: `rojo build default.project.json -o build/pocket-habitat.rbxl`
3. Format check: `stylua --check src`
4. Lint: `selene src`
5. Diff hygiene: `git diff --check`
6. Continuation policy tests: `bash .github/scripts/test-continuation-policy.sh`
7. Inspect working tree: `git status --short`

## Studio testing procedure for habitat/multiplayer

1. **Habitat Allocation:** Verify separate, non-overlapping floating islands for multiple players.
2. **Resource Cooldowns:** Verify individual cooldowns per node/player and reward idempotency.
3. **DataStore Save/Rejoin:** Verify restoration of plant/growth/plot state; test crash-handling behavior.
4. **Creature Isolation:** Verify creatures are habitat-scoped and not visible/interactable by others.
5. **Multiplayer Isolation:** Ensure cross-player request rejection and correct server-side instance resolution.
