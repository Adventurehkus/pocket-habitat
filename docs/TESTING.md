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

`src/shared/Tests/CharacterSpawn.spec.lua` is also in the TestEZ `describe`/`it` format and checks the production default-data API plus the shared spawn-coordinate serializer's round-trip and invalid-value handling. Neither spec suite has been executed by a compatible Roblox/TestEZ runner in this environment. The CI workflow installs TestEZ but does not invoke a runner. Do not report TestEZ as passed until a real test execution result is available.

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

## Current recovery source pass — 2026-11-12

The current worktree implements the Run #38 QA repairs: it disables automatic character loading, spawns only after a successful leased data load and habitat allocation, validates and rate-limits dead-character respawn requests (including initial-spawn concurrency), captures position/orientation in memory, serializes spawn vectors as numeric tables, and saves live data during lease renewal and final release. Loads fail closed on service errors, active foreign leases, malformed records, or unsupported envelope versions. Independent pipeline review/QA and Roblox runtime evidence remain pending; the recovery marker is OPEN.

Checks actually run on the current source:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS; generated `build/pocket-habitat.rbxl`.
- `stylua --check src`: PASS.
- `selene src`: PASS (0 errors, 0 warnings, 0 parse errors).
- `git diff --check`: PASS on the current source and documentation state.
- TestEZ suite: NOT RUN. No compatible runner (`run-in-roblox`, `luau`, or `lune`) was available.
- Roblox engine/Studio, multiplayer, DataStore contention/failure/rejoin, shutdown, and manual playtests: NOT RUN.

These are static/source checks only; they do not prove the Roblox runtime path works.

## Recovery follow-up — 2026-11-13

An additional inspection found that `ServerMain.server.lua` reset a five-second nested deadline on every shutdown-loop iteration, delaying checks of the nominal 25-second overall cap. The nested loop is replaced with a wait bounded by the remaining time to one absolute deadline. This is source-level validation only; Roblox `BindToClose` behavior remains untested.

Checks run after that source correction:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS; generated locally.
- `stylua --check src`: PASS.
- `selene src`: PASS (0 errors, 0 warnings, 0 parse errors).
- `git diff --check`: PASS after the source and documentation updates.
- TestEZ: NOT RUN; no compatible runner is installed.
- Independent review/QA and Roblox engine/Studio, multiplayer, DataStore, shutdown, and manual tests: NOT RUN.

The existing recovery follow-up also found that the persisted source had not acquired a lease before exposing a session, could fabricate defaults after failed reads, and lacked atomic lock release/recurring renewal. The DataStore and spawn persistence work remains awaiting valid independent review/QA and runtime testing.

Source inspection of the cycle-5 checkpoint found that the documented lease flow was not connected to the join path: `loadPlayerData` used `GetAsync`, exposed defaults after errors, and created an in-memory session without calling `acquireSession`; `getSession` also fabricated default data, saves did not require a matching stored lock, and release left the persistent lock in place. The follow-up rewrote the manager around atomic `UpdateAsync` acquisition/renewal/save/release, strict record normalization, active-session-only lookups, schema-compatible gameplay defaults, and numeric spawn serialization. Character orientation storage/restoration now uses the same Euler-angle representation, and client data sync handles both session and gameplay payloads.

Checks actually run after the source changes:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS; generated `build/pocket-habitat.rbxl`.
- `stylua --check src`: PASS.
- `selene src`: PASS (0 errors, 0 warnings, 0 parse errors).
- `git diff --check`: PASS after final source and documentation edits.
- TestEZ: NOT RUN; no compatible `run-in-roblox`, `luau`, or `lune` executable is installed.
- Independent review/QA: NOT RUN for this follow-up; the latest recorded cycle-5 review route failed and did not return an approval. The prior QA's CFrame-callsite finding does not match the inspected cycle-5 source.
- Roblox engine/Studio, multiplayer, DataStore contention/failure/rejoin, shutdown, and manual tests: NOT RUN.

The recovery marker remains OPEN. Static source checks are not runtime evidence.

## Recovery follow-up — bounded failed-release retries — 2026-11-13

Source inspection found that a failed final session release restarted periodic lease renewal for a departing player. A live server could therefore renew an orphaned lease indefinitely and prevent that user from reacquiring a session. `DataStoreManager` now retains the session data and schedules up to three release-only retries after transient failures (5, 15, and 30 seconds); it does not renew the departing lease. If the stored token has already been replaced, the stale in-memory session is discarded without writing. Exhausted retries leave the lease to expire naturally. This behavior is source-level only.

Checks actually run after the code change:

- `rojo build default.project.json -o build/pocket-habitat.rbxl`: PASS; generated locally.
- `stylua --check src`: PASS.
- `selene src`: PASS (0 errors, 0 warnings, 0 parse errors).
- `git diff --check`: PASS after the final documentation edits.
- TestEZ: NOT RUN; no compatible `run-in-roblox`, `luau`, or `lune` runner is installed.
- Independent review/QA of this change: NOT RUN in this implementation pass; the recovery report has no trustworthy approval for the current accumulated diff.
- Roblox engine/Studio, multiplayer, DataStore failure/rejoin/contention, shutdown, and manual tests: NOT RUN.

Keep recovery OPEN. The generated Rojo artifact and static checks do not prove the retry behavior works in Roblox or DataStore runtime.

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

## 100% quota policy, recovery verification, and checkpoint persistence

The workflow on `main` has evolved through these changes:
- Multi-cycle router, model rotation, and checkpointing: `d5e4a14b3d433f40fbb16e233533b98ee1dd9858`.
- Regression/checkpoint and wait-budget fixes: `519de8cea3df3fdf3e719399ec7d7e804c01a4e3`, `658bb50bad7060dc0ae99760ac673c748684cac4`.
- 100% eligible-pool exhaustion target: `649d6137cb0221bccac914f337754b3db1bf59a8`.
- Cross-cycle validation/QA recovery, recovery checkpoints, durable recovery state, per-cycle temporary-route reset, and unknown-error retries: `a84e1e48a323b649f380930bc9f72ba6588fb1f2`.
- Bounded checkpoint-push retries, ambiguous-push verification, concurrent-branch rebase handling, and inline regression fixtures: current main workflow head `3490233f6af9084dbc518d8b06936dff5190cfc0`.

### Current behavior

- The quota target is **100% of currently eligible quota pools**, based on explicit daily/monthly quota errors. Provider balances are not queried; this is quota-scope evidence, not an exact remaining-token/request meter.
- Each autonomous cycle runs implementation, independent review, conditional repair, deterministic validation, and independent QA.
- Candidate models rotate by role. A model used in one role is excluded from other roles during that cycle, then can be reused in later cycles unless a run-wide quota/call restriction applies.
- Temporary RPM/TPM limits, transient capacity/5xx/timeouts, and unclassified model/tool errors receive bounded cooldown/retry attempts. Per-stage temporary-failure exclusions reset at the start of each later cycle, so these routes can be revisited. Confirmed daily/shared quota exhaustion, authentication failures, unavailable models, request-size incompatibility, per-model call counts, and global budgets remain in force.
- Deterministic validation can receive up to 5 repair-model attempts per cycle. QA blockers can receive up to 3 repair/re-check attempts per cycle. If a failure remains, the next cycle must prioritize the exact recovery report instead of abandoning the run.
- If implementation cannot complete, the pipeline retries eligible routes in a later cycle. If review or QA is unavailable or malformed after fallback, it saves an explicitly unreviewed or QA-pending recovery checkpoint. Deterministic validation failures are also saved as recovery work after independent review/QA have inspected the diff.
- Recovery debt is persisted in `docs/AUTONOMOUS_RECOVERY.md` on `ai/game-build`. A later workflow run loads it automatically and must resolve it before unrelated features. Recovery commits are explicitly labelled as needing follow-up; they are never counted as validated checkpoints. The recovery record must be explicitly marked `RECOVERY_STATUS: RESOLVED` with evidence after independent review, QA, and deterministic validation pass. It is retained in Git as audit evidence and automatically re-opened if a future recovery event occurs.
- A successful review/QA/validation cycle is pushed as a validated checkpoint. Recovery work is pushed separately and visibly labelled. Both use `push_checkpoint_with_retry`: up to five push attempts with exponential backoff, fetch-based verification when a push response is ambiguous, and safe rebase/retry when another run advances `ai/game-build`. The helper never force-pushes; authentication/permission/branch-policy failures, unrelated history, and rebase conflicts stop safely. A final persistence safety-net step uses the same helper.
- The workflow runs local bare-Git regression tests before model work. They simulate a transient server-side rejection on the first push and a concurrent branch update; both must recover without losing either commit. If persistence still fails after bounded attempts, the pipeline stops rather than pretending the changes were saved or proceeding with uncheckpointed work.
- Hard limits remain 8 calls per model per run, 120 total model calls, 30 cycles, 2 hours aggregate temporary-limit waiting, two consecutive no-progress cycles, and the 350-minute GitHub Actions timeout. The pipeline also stops if all quota pools are exhausted while recovery debt remains, if there is no safe/meaningful work or eligible route, or if required runner/toolchain setup or repository persistence is unavailable.

### Run #37 — 2026-11-12 (validation passed; GitHub checkpoint push failed)

- Run ID: `43315643648`.
- Workflow URL: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43315643648
- Workflow source head: `a84e1e48a323b649f380930bc9f72ba6588fb1f2`.
- Gameplay branch head checked out: `5535a31b19897e17877cceae03b745678669ce66`.
- The run detected and loaded the existing open recovery note, then ran implementation, independent review, repair, validation repair, and QA. The job created local commit `2fb9074` (four files changed), but it never reached the durable gameplay branch.
- Final automated checks after recovery repair: Rojo build PASS; `stylua --check src` PASS; Selene PASS (0 errors, 0 warnings, 0 parse errors); `git diff --check` PASS.
- Independent QA returned `QA_BLOCKER: NO`. TestEZ, Roblox runtime, Studio, multiplayer, and DataStore integration were NOT EXECUTED.
- GitHub rejected the only checkpoint push with `remote: Internal Server Error` (request ID `B048:5D7CD:249E93:542A2E:6AF63AF8`). The workflow stopped with `cycle_checkpoint_persistence_failed` and correctly did not continue to another cycle or mark the checkpoint safe.
- The final `Persist work to GitHub` step was skipped because the pipeline had not confirmed persistence. The artifact `pocket-habitat-pipeline-37` uploaded successfully (artifact ID `13988817790`).
- The `ai/game-build` branch remained at `5535a31b19897e17877cceae03b745678669ce66`. Run #37's local source changes must be reapplied/reverified; do not represent them as part of the durable source.
- The model/provider annotations were not the root cause: Google received temporary rate limits, OpenRouter's shared daily free quota was exhausted, and Groq requests were too large for three models. The workflow classified and skipped/cooled down those routes as designed.

### Checkpoint-push retry regression coverage — local reproduction passed; inline Actions test pending

The new `push_checkpoint_with_retry` helper was added after Run #37:
- transient GitHub/server push failures are retried up to five attempts using bounded exponential backoff;
- after an ambiguous push, the helper fetches the remote ref and treats the checkpoint as persisted if the remote already contains it;
- if another run advanced the same branch, the helper rebases the local checkpoint onto that branch and retries;
- no force-push is used; authentication/permission/policy failures, unrelated histories, and conflicts stop safely;
- validated checkpoints, recovery checkpoints, and the final persistence safety net use the same helper.

A local shell reproduction using the committed helper logic passed three bare-repository scenarios: a deliberately rejected first push, an accepted push whose client received an error (verified by fetching the remote ref), and concurrent branch advancement (rebased without losing either commit). The equivalent inline regression test is also committed in the workflow, but has not yet run in GitHub Actions. A fresh workflow dispatch is still needed to validate that test plus the full YAML/embedded shell integration.
### Run #34 evidence

- Run #34: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43131314450
- The new 100% quota-accounting preflight regression fixtures **passed**.
- The development pipeline then failed final deterministic validation at **33% quota exhaustion**, with stop reason `final_validation_failed`. This was not a quota-target stop.
- The final validation log reported a StyLua formatting diff and Selene findings in `src/server/ServerMain.server.lua`: `game.BindToClose(onBindToClose)` must use `game:BindToClose(onBindToClose)`, and `Workspace` and `Constants` were unused locals.
- The run had only one completed autonomous cycle and 24/120 model calls. It did not verify the new cross-cycle recovery behavior because that behavior was added afterward.
- Push-triggered runs #35 and #36 refer to intermediate workflow-file commits and returned no job records through the available GitHub job listing. They do not establish that the current recovery implementation was executed.

**Verification status:** Run #37 exercised the cross-cycle recovery path. Its temporary worktree passed Rojo, StyLua, Selene, and `git diff --check`; independent review/QA completed and QA returned `QA_BLOCKER: NO`. However, the validated local commit was rejected by GitHub with an HTTP 500, so those source edits were never persisted to `ai/game-build`. The checkpoint-push retry/rebase fix is now committed on `main`; a local shell reproduction passed transient rejection, ambiguous accepted-push response, and concurrent branch advancement. The inline regression function, updated workflow YAML/embedded shell, and GitHub Actions integration still require a fresh dispatch. Do not call the new GitHub push-retry path live-tested until that run completes and its logs/artifacts are inspected.

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