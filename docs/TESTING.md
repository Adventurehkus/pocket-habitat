# Pocket Habitat — Testing and Verification Strategy

## Principles
- Record only checks that actually ran and their real result.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test.

## Latest workflow execution — Run 147 (2026-11-18)

- Rojo build: PASS.
- Static checks (StyLua, Selene, diff hygiene): PASS.
- Continuation-policy tests: PASS.
- TestEZ execution: NOT RUN (no compatible runner in environment).
- Roblox Studio/multiplayer/DataStore playtesting: NOT RUN.

## Standard deterministic checks

1. Validate project JSON and relevant manifests.
2. Build: rojo build default.project.json -o build/pocket-habitat.rbxl: PASS.
3. Format: stylua --check src: PASS.
4. Lint: selene src: PASS.
5. Diff hygiene: git diff --check: PASS.
6. Continuation policy tests: PASS.
7. Inspect working tree: Clean.
8. Manager TestEZ specs: Syntactically verified; execution pending compatible environment.

## Studio testing procedure (Outstanding)

1. Habitat Allocation (isolation/non-overlap).
2. Resource Cooldowns (per-node/per-player idempotency).
3. DataStore Save/Rejoin (restoration/crash handling).
4. Creature Isolation (habitat-scoped).
5. Multiplayer Isolation (request rejection/instance resolution).
