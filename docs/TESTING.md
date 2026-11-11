# Pocket Habitat — Testing Strategy

## Principles
- Record only checks that actually ran and their real exit status.
- Separate static repository checks from Roblox-engine tests and manual client playtests.
- Never describe a system as reliable until it has evidence from repeatable tests.

## Local and CI checks
1. Parse `default.project.json` as valid JSON.
2. Install the versions pinned in `rokit.toml` using Rokit.
3. Run `rojo build default.project.json` and verify the generated model.
4. Run StyLua formatting checks on Luau source.
5. Run Selene linting on Luau source.
6. Run unit tests (TestEZ) once test suites exist.

## Roblox engine tests
- Use Roblox Open Cloud Luau Execution for server-side checks that need Roblox engine APIs.
- Keep a dedicated test place and never use production player data for experiments.
- Capture execution IDs, output, errors, and completion status.
- Cloud Luau execution does not replace full client rendering, input, or visual testing.

## Manual playtesting
- Use Roblox Studio on a client-capable machine to test spawn, movement, collection, planting, UI, and touch layouts.
- Test two or more players for data isolation, remote validation, and shared-world behavior.
- Test save, rejoin, load failure, and shutdown/departure behavior.

## Current verified CI baseline
- GitHub Actions checkout: passed.
- OpenCode v2.2.7 installation and version check: passed.
- Rokit 1.2.0 installation: passed.
- Initial `rokit install` encountered Rokit's untrusted-tool guard for StyLua. The CI-appropriate `rokit install --no-trust-check` then installed the pinned tools successfully.
- Tool versions: Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2: all version checks passed.
- `wally install`: passed; TestEZ 0.4.1 was installed under `DevPackages`.
- `rojo build default.project.json`: passed after the project folders were restored/configured (0 errors, 0 warnings).
- `stylua --check .`: passed (0 errors, 0 warnings).
- `selene .`: passed (0 errors, 0 warnings).
- The StyLua and Selene checks ran before gameplay Luau scripts existed, so they validate the empty/placeholder source baseline, not game logic.
- The agent's final model request hit Gemini's free-tier 15-requests-per-minute limit after the validation and state-file update. The workflow job was marked failed, but the persistence step successfully committed the checkpoint to `ai/game-build`.
- No TestEZ test suite was run. No Roblox engine execution or manual Studio playtest was performed.

## Next verification
Repeat StyLua and Selene checks after Luau source files are added. Add TestEZ suites before treating unit testing as available, and retain separate Roblox engine and manual client testing.

## Running the CI development pipeline

The GitHub Actions workflow on `main` runs the real provider-backed implementation, independent review, conditional repair, deterministic validation, and QA stages on every manual dispatch.

To start a task: Actions → Autonomous Roblox Builder → Run workflow → select branch `main` → enter the task. The run installs OpenCode and may consume provider quota or paid/free-tier usage. Confirm that at least one supported provider secret is configured before starting.

After the pipeline runs, its persistence step commits working changes to `ai/game-build`. The workflow also uploads the Roblox build, pipeline report, validation log, and per-model usage log.

## CI multi-provider model pipeline

The GitHub Actions workflow on `main` orchestrates separate implementation, independent review, conditional repair, deterministic validation, and independent QA stages. The workflow checks out `ai/game-build`, where `opencode.json` defines the OpenCode providers and project agents.

### Configured model routes

| Provider | Model routes | Access |
|---|---|---|
| Google | Gemini 3.5 Flash-Lite, Gemini 3.1 Flash-Lite, Gemini 3.8 Flash, Gemma 4 31B IT, Gemma 4 26B A4B IT | Existing Gemini key |
| Cloudflare Workers AI | GLM-4.7 Flash (`@cf/zai-org/glm-4.7-flash`) | Workers AI Free allocation |
| Cohere direct | North Mini Code, Command A+, Command A Reasoning | Trial API key |
| Groq | Qwen 3.8 27B, GPT-OSS 120B, GPT-OSS 20B | Existing Groq key |
| OpenRouter | Nemotron 3 Ultra, Cohere North Mini Code, Recursive Flint, Inkling 2 Small, ERNIE 5.5 Flash Preview, Nemotron 3.5 Lightning, Nemotron 3.5 Super VL | Existing OpenRouter key; `:free` variants |
| GitHub Copilot | Copilot CLI Auto | Optional Copilot Free entitlement and fine-grained PAT |

The Copilot CLI adapter is not an OpenCode model ID. It is a separate fallback route named `github-copilot/auto`. Copilot Free uses automatic model selection; the workflow invokes the CLI only in implementation/repair stages. Reviewer and QA stages remain read-only OpenCode agents.

### Required Actions secrets

Existing secrets:
- `GEMINI_API_KEY`
- `GROQ_API_KEY`
- `OPENROUTER_API_KEY`

Optional new secrets:
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- `COHERE_API_KEY`
- `COPILOT_GITHUB_TOKEN`

Cloudflare requires both the account ID and an API token with Account > Workers AI > Read permission. GLM-4.7 Flash is available on Workers Free. Workers AI includes 10,000 Neurons per day shared across Workers AI models; usage limits reset at 00:00 UTC. On Workers Free, requests beyond the included allocation fail rather than becoming paid overage. Do not switch the account to a paid Workers plan for this project unless paid usage is intentionally approved.

Cohere trial keys provide up to 1,000 Chat API calls per month, shared by the trial key across models, with a 20 requests/minute per-model limit for North Mini Code, Command A+, and Command A Reasoning. Treat it as one small monthly pool, not 1,000 calls per model.

Groq's GPT-OSS 20B is a separate model ID, but it uses the same Groq account and its own model-specific rate-limit row. Check the actual account dashboard because model limits and eligibility can change.

OpenRouter free variants share the account's free-tier pool: 20 requests/minute and 50 requests/day on a free account. Failed attempts count toward the daily allowance. Adding more `:free` model IDs adds fallback choices, not additional OpenRouter daily quotas. If one free model reports the shared daily quota exhausted, the router skips the remaining OpenRouter free models for that run.

GitHub Copilot Free includes limited chat/agent usage and Copilot CLI, with Auto model selection. GitHub does not publish a fixed numeric Free AI Credit allowance in its plan table. Usage can therefore end when the account's free allowance is exhausted. The token must be a fine-grained personal access token owned by the user's personal account with the Account permission `Copilot Requests`; restrict repository access to this repository where possible.

### Quota-routing behavior

- Models are included only when the corresponding credential(s) exist.
- A model is attempted at most once per workflow run, including across stages.
- A daily/monthly shared-pool exhaustion disables that provider for the remainder of the run for Cloudflare, Cohere, OpenRouter free, and Copilot.
- RPM/TPM failures get at most one retry using a reasonable provider retry hint.
- Repeated OpenRouter free-tier RPM failure disables the shared OpenRouter pool for that run.
- Invalid credentials disable the affected provider for the run.
- Unavailable model IDs and unsupported context errors skip that model.
- Unclassified errors fail the stage visibly rather than being hidden by fallback.
- Each attempted model, retry, skip reason, and stage outcome is recorded in the pipeline usage TSV artifact.

Free-tier capacity and quotas can change. The workflow reacts to provider errors but does not query remaining quota balances. Check each provider dashboard for exact account-level usage.

### Data and privacy note

The pipeline sends repository instructions and relevant source/diff content to whichever provider is selected. Never put secrets, tokens, or private credentials in prompts or source files. Some OpenRouter free endpoints, including Inkling 2 Small and NVIDIA free endpoints, state that prompts/session data may be logged or used to improve their services. Do not route sensitive or confidential material to those endpoints. Treat all free endpoints as third-party processing, not as a private local model.

## Recent fallback regression test
- Workflow run 42911900811 reached Gemini 3.5 Flash-Lite but hit Google's 250,000 input-token-per-minute Free Tier limit. This was not a daily quota failure.
- The fallback script initially failed to catch the error because GitHub Actions enables Bash `errexit` by default. The failed pipeline exited before the classifier could run.
- The workflow now explicitly disables `errexit` in the model-routing step and wraps each OpenCode pipeline in an `if` condition to capture its actual status safely.
- Roblox toolchain installation is now a dedicated pre-agent workflow step: official Rokit installer, pinned tools, Wally dependencies, version checks, and a Rojo build smoke test. The agent no longer needs to spend model calls installing basic CI tools.
- A local Bash simulation verified that a nonzero OpenCode pipeline is captured and the Gemini input-token-per-minute message matches the RPM/TPM classifier. The updated workflow has not yet completed a live provider-switch test.


## Latest toolchain smoke-test failure (workflow run 10)
- Rokit 1.2.0, Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2 installed successfully; `wally install` completed and installed TestEZ under `DevPackages`.
- `rojo build default.project.json` then failed because the project mapped `ReplicatedStorage.Packages` to a directory that did not exist after Wally install. The manifest currently has only a dev dependency, so no shared/runtime `Packages` directory is expected.
- Commit `05221ee` removes the unused `Packages` mapping. The corrected project configuration has not yet been tested by a fresh workflow run. If a normal `[dependencies]` entry is added later, add its `Packages` Rojo mapping at the same time.
- OpenCode was skipped and no gameplay implementation or provider fallback test occurred in run 10.


## Workflow run 11 — first gameplay code checkpoint
- Pre-agent checks passed: pinned Roblox tools installed, Wally completed, and `rojo build default.project.json` succeeded with the corrected project mapping.
- Initial Milestone 1 modules were committed: server-side data, economy, resource gathering, planting, quests, and creature-discovery modules, plus shared constants/remotes/types and server startup.
- The code was persisted despite the agent job failing on model availability. This was an interrupted implementation checkpoint, not a validated playable build.
- The log shows Gemini 3.5 Flash-Lite repeatedly rate-limited for input tokens per minute; Gemini 3.1 Flash-Lite returned "This model is currently experiencing high demand" until OpenCode exited. The workflow previously failed to recognize that specific provider-capacity error.
- Main workflow commit `ae1d395` adds `high demand|spikes in demand|try again later` to provider-availability classification so a new run can proceed to later configured models.
- No post-agent Rojo build, StyLua, Selene, TestEZ, Roblox engine, or manual Studio test is recorded for the newly created gameplay modules. Run all static checks and add targeted tests before relying on these systems.


## Workflow run 12 — restricted Google fallback model
- Run 42917643374 passed the pre-agent toolchain and Rojo smoke test. Gemini 3.5 Flash-Lite ran out of RPM/TPM capacity; Gemini 3.1 Flash-Lite then encountered TPM limits and repeated high-demand errors.
- The fallback logic advanced to Gemini 2.5 Flash-Lite, but Google rejected it because the model is no longer available to new users. Google currently limits 2.5 model access to users who actively used them before and recommends Gemini 3.5 Flash-Lite or Gemini 3.8 Flash for new projects.
- Main workflow commit `3e956a7` removes the restricted Gemini 2.5 model and classifies "no longer available" / "not available to new users" as provider/model availability failures. Gemini 3.8 Flash is now next in the configured chain.
- Run 12 saved client/UI scaffolding and server-module changes in commit `04a4108`, but the agent stopped before post-agent validations completed. No post-agent Rojo build, StyLua, Selene, TestEZ, Roblox engine, or manual Studio test is recorded.
- Run 12 also reformatted tracked third-party TestEZ package sources. Commit `25750bf` restored the vendored `DevPackages` directory. `AGENTS.md` now explicitly restricts formatting/linting to project-owned code under `src/`.
