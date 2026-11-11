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

## Latest verified gameplay pipeline run

### Run #30 — 2026-11-11

- Run ID: 43098662842.
- Gameplay checkpoint persisted: 21386b54aa0432c1f5fdb796411c30a41d060350.
- Implementation: SUCCESS.
- Independent review: SUCCESS.
- Conditional repair: SUCCESS.
- QA: SUCCESS.
- Rojo build: PASSED.
- StyLua check src: PASSED, zero errors/warnings/parse errors.
- Selene src: PASSED.
- TestEZ: NOT EXECUTED.
- Roblox Studio/gameplay: NOT EXECUTED.
- Multiplayer: NOT EXECUTED.
- DataStore integration/stress: NOT EXECUTED.
- Artifact upload: SUCCESS; artifact was pocket-habitat-pipeline-30.

This run supersedes Run #27's failed Selene result for the checkpoint it validated. Preserve Run #27 below as historical evidence, not the current baseline.

### Run #27 — historical failure

- Run ID: 43083640009.
- Rojo and StyLua passed; Selene failed due to an unused PLOT_POSITIONS local.
- Reviewer output omitted its required decision header; repair was skipped.
- The run persisted a checkpoint and uploaded an artifact but failed overall.
- Subsequent source changes were checked by Run #30.

## Adaptive model/provider retry behavior

The GitHub Actions workflow on main was updated after Run #30. Its latest retry-policy commit is 36c16722d6ebc2a4bd66433ec5e9ec15ee17b7fa.

The updated router now classifies and handles separately:
- Explicit shared daily/monthly quota exhaustion.
- Model-specific daily quota exhaustion.
- Request size/context incompatibility.
- Authentication and permission failures.
- Unavailable/retired models.
- Model-level RPM/TPM limits.
- Provider-shared rate limits.
- Temporary provider/model capacity, 5xx, and network failures.

For recoverable temporary failures it reads retry hints/Retry-After where available, otherwise uses bounded exponential backoff. It cools down the affected model or provider, tries other eligible routes, and resumes the same stage automatically when a route becomes eligible.

Committed policy at the time of this document:
- Four attempts per model per stage.
- At most 50 model calls per stage.
- Up to two hours of automatic waiting per stage.
- Up to four hours of automatic waiting across the workflow.
- Workflow job timeout: 350 minutes.

Daily/shared quota exhaustion, invalid credentials, unavailable models, and oversized requests are not pointlessly retried. The workflow records attempt classifications, cooldowns, waits, and quota events in its usage log/report.

**Verification status:** these retry changes are committed but have not yet been exercised by a fresh live workflow run. Their startup classifier/retry-delay fixtures are part of the workflow and will execute on the next run before the model stages. They do not query live provider balances and cannot guarantee that every provider remains available.

Free-tier policies and provider quotas change. Do not hard-code current quota counts into reusable prompts. Use opencode.json for configured routes and workflow logs for what actually happened during a run. Provider dashboards are the authority for remaining account balance.

## Running the autonomous development workflow

1. Open GitHub Actions.
2. Select Autonomous Roblox Builder.
3. Dispatch the workflow on branch main.
4. Enter either a specific task or the reusable generic continuation handoff.
5. Review the run summary and uploaded artifact.

The workflow checks out ai/game-build. It runs implementation, independent review, conditional repair, Rojo/StyLua/Selene validation, independent QA, conditional final repair, and persistence to the gameplay branch.

A configured model is only a possible route; it is not proof of available quota or successful invocation. The workflow's bounded retry/time budgets can still be exhausted if all candidates are unavailable or daily quotas are gone.

## Historical pipeline notes

- Earlier runs encountered unavailable model IDs, Gemini per-minute token limits, transient high-demand responses, malformed reviewer output, and runner-temporary file access issues.
- The workflow was subsequently improved with a pinned toolchain preflight, safe command exit-status capture, review-format fallback, and inline validation-log attachment for Copilot repair.
- These are historical workflow developments. Use the current main branch workflow and latest run logs for current behavior.

## Data and privacy

Repository instructions and relevant code/diff content are sent to whichever external provider the workflow selects. Never place secrets, tokens, private credentials, or confidential user data in prompts or source files. Treat third-party free model routes as external processing; follow provider privacy terms and do not assume free endpoints are private or local.