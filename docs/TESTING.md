# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their actual results.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test.
- A workflow handoff or recovery checkpoint is not a validated development cycle.

## Latest workflow execution — Run 151 (2026-11-18)

[Run 151](https://github.com/Adventurehkus/pocket-habitat/actions/runs/44229477999) failed in the staged multi-agent development step.

- Toolchain installation and initial Rojo build: PASS.
- OpenCode model registry preflight: PASS.
- Continuation-policy preflight tests: PASS.
- Implementation: BLOCKED before any source diff. Both eligible Google Gemma models hit the 16,000 input-tokens/minute free-tier limit. Groq routes were skipped/rejected as oversized requests.
- Independent review, repair, QA, and post-implementation deterministic validation: NOT RUN.
- Gameplay source diff from run 151: NONE.
- Validated development cycles: 0.
- The automatic no-progress safety counter reached 5, so no automatic continuation was dispatched.

## Context-budget mitigation (committed, not yet CI-verified)

- Shortened docs/AUTONOMOUS_AGENT_GUIDE.md and AGENTS.md to reduce repeated startup context.
- Agents are instructed to inspect only relevant sections of docs/TECHNICAL_ARCHITECTURE.md and other large docs rather than loading full documents by default.
- OpenCode config sets Gemma input caps to 12,000 tokens, Groq input caps to 6,000 tokens, a 32,768 context limit for those routes, and automatic compaction with a 2,000-token retained tail.
- The main workflow continuation prompt now directs agents to use focused architecture reads and validates the new config values.
- These changes must be exercised by a fresh workflow run; no claim of CI success is made yet.

## Earlier static verification — historical checkpoint

Run 148 and earlier checkpoints recorded:
- Rojo build: PASS.
- StyLua check on src/: PASS.
- Selene on src/: PASS.
- Diff hygiene: PASS.
- Continuation-policy tests: PASS.
These historical passes do not validate the run-146 recovery diff.

## Outstanding tests

- TestEZ execution: NOT RUN; no compatible runner confirmed.
- Roblox Studio server startup and gameplay: NOT RUN.
- Two-client multiplayer/habitat/resource/creature isolation: NOT RUN.
- DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown: NOT RUN.
- Mobile/device input and performance: NOT RUN.

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
