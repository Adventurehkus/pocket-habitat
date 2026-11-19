# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their actual results.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test.
- A workflow handoff or recovery checkpoint is not a validated development cycle.

## Latest workflow execution — Run 153 (2026-11-19)

[Run 153](https://github.com/Adventurehkus/pocket-habitat/actions/runs/XXXXXX) executed vertical slice validation (Task QSA-101: Quest-Feature Integration with Server Authority Checks).

- Recovery status: RESOLVED
- Task: QSA-101
- Goal: Source-level validation of Quest feature integration vertical slice with server-authority checks
- Run documentation: docs/TASK_QUEST_SERVER_AUTHORITY.md and docs/AUTONOMOUS_RECOVERY.md

### Static validation (Pass)
- Toolchain installation and Rojo build: PASS
- Rojo build: `rojo build default.project.json -o /tmp/pocket-habitat.rbxmx` — PASS (valid 75,838-byte artifact)
- StyLua format check: `stylua --check src` — PASS
- Selene linter: `selene src` — PASS (0 errors, 0 warnings, 0 parse errors)
- Diff hygiene: `git diff --check` — PASS (no trailing whitespace, no uncommitted merges)
- Independent review, repair, QA, and runtime testing: NOT RUN (environment constraints block TestEZ/Roblox runtime)
- Gameplay source diff: NONE (source validation only)
- Validated development cycles: 0 (source-level pass only; runtime verification pending)

## Context-budget mitigation (CI-verified in Run #152)

- Shortened docs/AUTONOMOUS_AGENT_GUIDE.md and AGENTS.md to reduce repeated startup context.
- Agents are instructed to inspect only relevant sections of docs/TECHNICAL_ARCHITECTURE.md and other large docs rather than loading full documents by default.
- OpenCode config sets Gemma input caps to 12,000 tokens, Groq input caps to 6,000 tokens, a 32,768 context limit for those routes, and automatic compaction with a 2,000-token retained tail.
- The main workflow continuation prompt now directs agents to use focused architecture reads and validates the new config values.
- CI-verified successful in Run #152; no need for further compaction before testing against TestEZ/Roblox execution.

## Earlier static verification — historical checkpoint

Run 148 and earlier checkpoints recorded:
- Rojo build: PASS.
- StyLua check on src/: PASS.
- Selene on src/: PASS.
- Diff hygiene: PASS.
- Continuation-policy tests: PASS.
These historical passes do not validate the run-146 recovery diff. Run #152 provides current static validation for the recovery-focused source.

## Outstanding tests

- TestEZ execution: NOT RUN; no compatible runner available in Linux environment (requires Roblox runtime).
- Roblox Studio server startup and gameplay: NOT RUN; requires Roblox deployment.
- Two-client multiplayer/habitat/resource/creature isolation: NOT RUN; requires Roblox multiplayer environment.
- DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown: NOT RUN; requires Roblox runtime and persistence layer.
- Mobile/device input and performance: NOT RUN; requires target deployment platform.

Note: Recovery status is RESOLVED for source-level automation-check observations (Rojo, stylua, selene, git diff, token merging investigation). Runtime verification gaps remain explicit and will be addressed when a runnable Roblox environment becomes available.

## Standard deterministic checks

1. Validate project JSON and relevant manifests.
2. Build: rojo build default.project.json -o build/pocket-habitat.rbxl.
3. Format: stylua --check src.
4. Lint: selene src.
5. Diff hygiene: git diff --check.
6. Continuation-policy tests: bash .github/scripts/test-continuation-policy.sh.
7. Inspect working tree: git status --short.
8. Execute manager/shared-rule TestEZ specs only through a compatible runner.

## Studio testing procedure

1. Habitat allocation: separate, non-overlapping floating islands.
2. Resource cooldowns and idempotent rewards.
3. DataStore save/rejoin without data loss.
4. Creature isolation and habitat-scoped interactions.
5. Cross-player request rejection and ownership isolation.
6. Join/respawn, gathering-to-harvest, quests, upgrades, and player-facing feedback.
