# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their real result.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test. Dependency installation is not test execution.
- Do not infer multiplayer, persistence, or security guarantees from a successful Rojo build.

## Latest workflow execution — Run 139 (2026-11-17; failed before review/QA)

Run 139 completed with failure and 0 validated development cycles.

- Initial toolchain Rojo build: PASS.
- OpenCode model-registry preflight: PASS.
- Continuation-policy preflight test: PASS (the pre-fix test suite in effect during Run 139).
- Implementation stage: FAILED to produce source changes. Four eligible routes (two Google Gemma models and two Groq models) were attempted; nine of thirteen quota pools were held.
- Model calls: 23; automatic cooldown waits: 410 seconds.
- Google: free-tier input-token-per-minute limits were reached.
- Groq: Qwen 3.8 27B hit ITPM 7,000 / requested 9,026 and OTPM 1,000 / requested 1,242; GPT-OSS 20B hit TPM 8,000 with requests from 9,016 to 11,292.
- Stop reason: no implementation progress after two consecutive zero-cycle runs. Review, QA, and the main Rojo/StyLua/Selene source-validation stage were NOT RUN in Run 139. No gameplay changes were committed by this run.

Workflow fixes committed afterward on `main` (`faba3c85437bdaf742ffbc0f0262cbe826bee71c)): explicit request-size classification before generic TPM retry classification, 800-token output caps for Groq Qwen/GPT-OSS, compaction of the known evergreen task input, and a five-run bounded no-progress continuation limit. The updated classifier fixtures were exercised locally and passed. The new GitHub Actions model-registry assertion and continuation-policy tests, as well as a full workflow run with these changes, remain NOT YET EXECUTED.

Run 137's prior independent-QA evidence gap remains open and must be rechecked; a successful handoff or zero-change run does not satisfy it.

## Verification checkpoint — 2026-11-17 (Independent QA pending)

Verified current repository source and autonomous recovery state on 2026-11-17:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS.
- `stylua --check src`: PASS.
- `selene src`: PASS.
- `git diff --check`: PASS.
- `.github/scripts/test-continuation-policy.sh`: PASS.
- TestEZ: NOT RUN (no compatible runner).
- Roblox Studio, multiplayer, DataStore, and runtime playtesting: NOT RUN.

Active recovery status remains OPEN. Run 137, cycle 4 recorded a successful independent code review but no valid `QA_BLOCKER: YES/NO` decision from either QA route. Its compact recovery summary records a 0-byte implementation diff and a 201-byte validation log; the exact QA provider error cannot be confirmed from that summary. The workflow configuration now retains both QA transcripts, the last attempted provider/model, and parsed stage outcomes in future recovery checkpoints. The original run-137 summary omitted those QA route details, so its exact provider-side failure remains unconfirmed. Do not treat the absence of a reported QA blocker as a QA pass.

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
