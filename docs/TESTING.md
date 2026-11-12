# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their real result.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test. Dependency installation is not test execution.
- Do not infer multiplayer, persistence, or security guarantees from a successful Rojo build.
- Keep historical results, but label them by run and do not present them as the current baseline.

## Standard deterministic checks

Run the checks supported by the environment:

1. Validate project JSON and relevant manifests.
2. Install the toolchain pinned by rokit.toml through Rokit.
3. Install Wally dependencies where required.
4. Build: rojo build default.project.json -o build/pocket-habitat.rbxl
5. Format check: stylua --check src
6. Lint: selene src
7. Diff hygiene: git diff --check
8. Inspect working tree: git status --short

Format/lint only project-owned Luau files under src/. Never format the repository root or vendored DevPackages source.

## TestEZ and production logic

src/shared/PocketHabitat.spec.lua contains TestEZ specifications for production PlantRules and EconomyRules logic. It covers interaction validation, seed selection/ownership, watering and growth constraints, harvest eligibility, malformed state, inventory capacity, and invalid inventory data.

These specs have not been executed by a compatible Roblox/TestEZ runner as of the latest verified gameplay run. The CI workflow installs TestEZ as a dependency but does not currently invoke a TestEZ runner. Do not report TestEZ as passed until a real test execution result is available.

Expand tests around production logic for:
- Habitat allocation and owner isolation.
- Plot/resource ownership and independent cooldowns.
- Concurrent interaction and duplicate reward prevention.
- Quest action progress and idempotent claims.
- Upgrade purchase/effect consistency.
- Save schema validation and migration.
- Cross-server session token, lease expiry, renewal, save, and release.
- Load failure, save failure, shutdown, and rejoin handling.

Use mocks for external Roblox service boundaries, not for the production business rules being tested.

## Roblox engine and manual tests

These require a supported Roblox engine runner or Studio. They are not replaced by static validation or TestEZ pure-rule tests.

- Server startup and player lifecycle.
- Client/server RemoteFunction and RemoteEvent signatures.
- ProximityPrompt interactions and server-side distance/ownership checks.
- Two or more simultaneous players attempting equivalent resource/plot actions.
- Habitat allocation, respawn, cleanup, and no cross-player interference.
- DataStore load/save, session contention, lease expiration, crash recovery, and rejoin.
- UI input on mouse/keyboard, touch, and gamepad where supported.
- Performance, memory, connection cleanup, and mobile device behavior.

Use a dedicated test place and test data. Never use production player data for experiments. Record execution IDs, output, errors, and actual completion status where a cloud runner is used. Cloud Luau execution does not prove full client rendering or input behavior.

## Current worktree verification — 2026-11-12

Source inspection confirmed the `WorldBuilder.init()` definition/call match, and verified the current `InvokeServer` sites do not pass `LocalPlayer` as an explicit argument. It also found that ServerMain replaced QuestManager's valid claim handler with a call to nonexistent `QuestManager.claimQuest`; that override was removed. ResourceManager's Part lookup could not find NodeId when the builder set it only on the prompt; the builder now sets it on the resource Part as well. Per-server habitat slot allocation and local-player prompt lifecycle handling were also corrected.

Checks actually run:

- `rojo build default.project.json -o /tmp/pocket-habitat-validation.rbxl`: PASS; verified the output was non-empty and removed it.
- `stylua --check src`: PASS.
- `selene src`: PASS (0 errors, 0 warnings, 0 parse errors).
- `git diff --check`: FAIL because the pre-existing added `temp_test.lua` contains trailing whitespace. That unrelated scratch file was not modified.
- Roblox engine/Studio, multiplayer, DataStore, TestEZ, and manual tests: NOT RUN.

The requested `/home/runner/work/_temp/opencode-qa-14.log` and `/home/runner/work/_temp/pocket-habitat-validation.log` could not be read with the available tools (permission denied); their claims were not independently inspected.

## Latest verified gameplay pipeline run

### Run #32 — 2026-11-11

- Run ID: 43119650837.
- Workflow URL: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43119650837
- Gameplay commit persisted to `ai/game-build`: `1af27d2aade0922f57ec4333bf5d5331366d7b9b`.
- Workflow branch/head: `main` at `b37935206db380e99731d4082c2f9f803954a76e`.
- Implementation: SUCCESS (Cohere North Mini Code).
- Independent review: SUCCESS (Google Gemini 3.5 Flash Lite).
- Repair: SUCCESS (Cohere Command A+).
- Validation repair: SUCCESS (GitHub Copilot Auto).
- QA: SUCCESS (Google Gemini 3.1 Flash Lite; QA_BLOCKER: NO).
- Review fallback: NOT RUN; QA repair: NOT RUN.
- Rojo build: PASSED; `build/pocket-habitat.rbxl` was included in the artifact.
- StyLua `--check src`: PASSED; 0 errors, 0 warnings, 0 parse errors.
- Selene `src`: PASSED.
- `git diff --check`: repair-agent log reports PASS after formatting.
- TestEZ: NOT EXECUTED.
- Roblox server startup/engine: NOT EXECUTED.
- Roblox Studio/manual gameplay: NOT EXECUTED.
- Two-client multiplayer: NOT EXECUTED.
- DataStore integration, contention, save/rejoin, and shutdown tests: NOT EXECUTED.
- Artifact: `pocket-habitat-pipeline-32`, 77,705 bytes, upload SUCCESS.
- Gameplay checkpoint push: SUCCESS.

**Important test interpretation:** Run #32 is a successful CI/pipeline execution, not a playable-game or Milestone 2 pass. At that checkpoint, ServerMain called `WorldBuilder.init()` but the module did not define it; that source-confirmed startup mismatch was missed by QA. The current worktree now defines `WorldBuilder.init()`, but has not been tested in Roblox. Other habitat placement, geometry, plot/resource ownership, restoration, spawn, and persistence gaps from that checkpoint are documented in `project-state/run-32-audit.md`. The QA report's claims that BaseOffset solved overlap and spawning was wired were contradicted by the checkpoint source.

### Run #30 — 2026-11-11 (historical)

- Run ID: 43098662842.
- Gameplay checkpoint persisted: 21386b54aa0432c1f5fdb796411c30a41d060350.
- Implementation, independent review, conditional repair, and QA: SUCCESS.
- Rojo build: PASSED.
- StyLua check src: PASSED, zero errors/warnings/parse errors.
- Selene src: PASSED.
- TestEZ: NOT EXECUTED.
- Roblox Studio/gameplay, multiplayer, and DataStore integration/stress: NOT EXECUTED.
- Artifact upload: SUCCESS; artifact was `pocket-habitat-pipeline-30`.

This run is historical and is superseded by the Run #32 source checkpoint. Preserve it as history, not as the current baseline.

## Adaptive model/provider retry behavior

The updated workflow on `main` (including commit `b37935206db380e99731d4082c2f9f803954a76e`) classifies:
- Explicit shared daily/monthly quota exhaustion.
- Model-specific daily quota exhaustion.
- Request size/context incompatibility.
- Authentication and permission failures.
- Unavailable/retired models.
- Model-level RPM/TPM limits.
- Provider-shared rate limits.
- Temporary provider/model capacity, 5xx, and network failures.

For recoverable temporary failures it reads retry hints/Retry-After where available, otherwise uses bounded backoff. It cools down the affected model or provider, tries other eligible routes, and resumes the same stage automatically when a route becomes eligible. Daily/shared quota exhaustion, invalid credentials, unavailable models, and oversized requests are not pointlessly retried.

### Live verification in Run #32

The adaptive fallback behavior was exercised in a real workflow run and completed every required stage:
- 20 models were configured.
- The report records 3 daily/shared quota-exhaustion events.
- There were 4 classified temporary-limit events and 0 seconds of automatic wait.
- The implementation stage encountered Google rate limits/model quota exhaustion and Cloudflare shared quota exhaustion, then succeeded using Cohere North Mini Code.
- Review succeeded using Google Gemini 3.5 Flash Lite.
- Repair succeeded using Cohere Command A+.
- Validation repair skipped oversized Groq routes and exhausted OpenRouter shared quota, then succeeded using GitHub Copilot Auto.
- QA succeeded using Google Gemini 3.1 Flash Lite.
- Review fallback and QA repair were not needed.
- Workflow status, all required stages, artifact upload, and gameplay commit push were SUCCESS.

**Conclusion:** Run #32 did not terminate because all configured models were exhausted. Several model/provider routes were exhausted or unavailable, but fallback routes completed all stages. This does not mean all 20 models were attempted, and it does not reveal remaining account balances after the run. Provider dashboards remain authoritative for balances.

The original one-pass retry policy used four temporary failures per model/stage, up to 50 calls per stage, 2 hours of waiting per stage, and 4 hours of aggregate waiting. That was the policy exercised by Run #32. The current main-branch policy is documented below and supersedes those limits for new runs.

## 100% quota policy and cross-cycle error recovery — committed; recovery live test pending

The workflow on `main` has evolved through these changes:
- Multi-cycle router, model rotation, and checkpointing: `d5e4a14b3d433f40fbb16e233533b98ee1dd9858`.
- Regression/checkpoint and wait-budget fixes: `519de8cea3df3fdf3e719399ec7d7e804c01a4e3`, `658bb50bad7060dc0ae99760ac673c748684cac4`.
- 100% eligible-pool exhaustion target: `649d6137cb0221bccac914f337754b3db1bf59a8`.
- Cross-cycle validation/QA recovery, recovery checkpoints, durable recovery state, per-cycle temporary-route reset, and unknown-error retries: current main head `d3240908cfb2e3e89e816c97e084b9e750e5236e`.

### Current behavior

- The quota target is **100% of currently eligible quota pools**, based on explicit daily/monthly quota errors. Provider balances are not queried; this is quota-scope evidence, not an exact remaining-token/request meter.
- Each autonomous cycle runs implementation, independent review, conditional repair, deterministic validation, and independent QA.
- Candidate models rotate by role. A model used in one role is excluded from other roles during that cycle, then can be reused in later cycles unless a run-wide quota/call restriction applies.
- Temporary RPM/TPM limits, transient capacity/5xx/timeouts, and unclassified model/tool errors receive bounded cooldown/retry attempts. Per-stage temporary-failure exclusions reset at the start of each later cycle, so these routes can be revisited. Confirmed daily/shared quota exhaustion, authentication failures, unavailable models, request-size incompatibility, per-model call counts, and global budgets remain in force.
- Deterministic validation can receive up to 5 repair-model attempts per cycle. QA blockers can receive up to 3 repair/re-check attempts per cycle. If a failure remains, the next cycle must prioritize the exact recovery report instead of abandoning the run.
- If implementation cannot complete, the pipeline retries eligible routes in a later cycle. If review or QA is unavailable or malformed after fallback, it saves an explicitly unreviewed or QA-pending recovery checkpoint. Deterministic validation failures are also saved as recovery work after independent review/QA have inspected the diff.
- Recovery debt is persisted in `docs/AUTONOMOUS_RECOVERY.md` on `ai/game-build`. A later workflow run loads it automatically and must resolve it before unrelated features. Recovery commits are explicitly labelled as needing follow-up; they are never counted as validated checkpoints. The recovery record must be explicitly marked `RECOVERY_STATUS: RESOLVED` with evidence after independent review, QA, and deterministic validation pass. It is retained in Git as audit evidence and automatically re-opened if a future recovery event occurs.
- A successful review/QA/validation cycle is pushed as a validated checkpoint. Recovery work is pushed separately and visibly labelled. If GitHub persistence itself fails, the pipeline stops rather than pretending the changes were saved.
- Hard limits remain 8 calls per model per run, 120 total model calls, 30 cycles, 2 hours aggregate temporary-limit waiting, two consecutive no-progress cycles, and the 350-minute GitHub Actions timeout. The pipeline also stops if all quota pools are exhausted while recovery debt remains, if there is no safe/meaningful work or eligible route, or if required runner/toolchain setup or repository persistence is unavailable.

### Run #34 evidence

- Run #34: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43131314450
- The new 100% quota-accounting preflight regression fixtures **passed**.
- The development pipeline then failed final deterministic validation at **33% quota exhaustion**, with stop reason `final_validation_failed`. This was not a quota-target stop.
- The final validation log reported a StyLua formatting diff and Selene findings in `src/server/ServerMain.server.lua`: `game.BindToClose(onBindToClose)` must use `game:BindToClose(onBindToClose)`, and `Workspace` and `Constants` were unused locals.
- The run had only one completed autonomous cycle and 24/120 model calls. It did not verify the new cross-cycle recovery behavior because that behavior was added afterward.
- Push-triggered runs #35 and #36 refer to intermediate workflow-file commits and returned no job records through the available GitHub job listing. They do not establish that the current recovery implementation was executed.

**Verification status:** the 100% quota accounting has preflight evidence from Run #34. The newer retry/recovery implementation is committed but still needs a fresh workflow dispatch to verify its YAML, embedded Bash, fallback loops, durable recovery file, and stop conditions. Do not call it live-tested until that run completes and its artifacts/logs are inspected.

**Billing warning:** the 120-call cap is a request-count limit, not a dollar-spend limit. Some API keys can be attached to billable provider accounts. Verify free-tier status and configure spending caps in provider dashboards before dispatching a long quota-focused run.

## Running the autonomous development workflow

1. Open GitHub Actions.
2. Select Autonomous Roblox Builder.
3. Dispatch the workflow on branch main.
4. Enter either a specific task or the reusable generic continuation handoff.
5. Review the run summary and uploaded artifact.

The workflow checks out ai/game-build and, under the current main-branch version, repeats implementation/review/repair/validation/QA cycles until the quota target or a hard stop is reached. Each successful cycle is checkpointed to the gameplay branch.

A configured model is only a possible route; it is not proof of available quota or successful invocation. The workflow's bounded retry/time budgets can still be exhausted if all candidates are unavailable or daily quotas are gone.

## Historical pipeline notes

- Earlier runs encountered unavailable model IDs, Gemini per-minute token limits, transient high-demand responses, malformed reviewer output, and runner-temporary file access issues.
- The workflow was subsequently improved with a pinned toolchain preflight, safe command exit-status capture, review-format fallback, and inline validation-log attachment for Copilot repair.
- These are historical workflow developments. Use the current main branch workflow and latest run logs for current behavior.

## Data and privacy

Repository instructions and relevant code/diff content are sent to whichever external provider the workflow selects. Never place secrets, tokens, private credentials, or confidential user data in prompts or source files. Treat third-party free model routes as external processing; follow provider privacy terms and do not assume free endpoints are private or local.