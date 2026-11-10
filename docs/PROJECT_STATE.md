# Pocket Habitat — Project State

## Current status
- **Current milestone:** Milestone 1 — Playable Core (in progress; initial server/shared scaffolding committed, but not yet verified as playable).
- **Status:** Documentation suite, CI toolchain, and initial Milestone 1 server/shared modules are present. The latest run verified the corrected Rojo smoke test and persisted 10 Luau files. The new gameplay code still needs review, client/world implementation, post-agent build/lint/format checks, and tests.
- **Last AI run:** Workflow run 42917643374 (run 12); the agent added a first client entry point and attempted more gameplay scaffolding before the restricted Gemini 2.5 fallback stopped execution.
- **Latest gameplay checkpoint:** `04a4108` — client entry point and initial UI/world/test scaffolding, plus server-module refinements. Latest cleanup commit: `25750bf` restores vendored TestEZ files.
- **Workflow conclusion:** Run 12 passed pre-agent toolchain and Rojo validation, fell through Gemini 3.5 and Gemini 3.1, then stopped on Gemini 2.5 Flash-Lite access restriction. The model was removed from the fallback chain; Gemini 3.8 Flash is now the next Google fallback.

## Implemented and documented
- Pocket Habitat game concept and core loops are documented in `GAME_DESIGN.md`.
- Development milestones are recorded in `ROADMAP.md`.
- Proposed server-authoritative architecture is described in `TECHNICAL_ARCHITECTURE.md`.
- Asset pipeline, testing strategy, and monetization proposal are documented in their respective files.
- Project configuration files are present: `default.project.json`, `rokit.toml`, `wally.toml`, `selene.toml`, `.stylua.toml`, and `opencode.json`.
- `.gitignore` and concise project-specific `AGENTS.md` are present.

## Actual checks from the latest foundation run
- Rokit installation using the official Linux installer: PASSED (Rokit 1.2.0).
- Initial `rokit install` was blocked by Rokit's trust guard for StyLua. `rokit install --no-trust-check` then installed the pinned CI tools successfully.
- Tool version checks: Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2: PASSED.
- `wally install`: PASSED; TestEZ 0.4.1 was installed under `DevPackages`.
- `rojo build default.project.json`: PASSED (0 errors, 0 warnings) after the expected project folders were restored/configured.
- `stylua --check .`: PASSED (0 errors, 0 warnings); there were no gameplay Luau scripts to format yet.
- `selene .`: PASSED (0 errors, 0 warnings); there were no gameplay Luau scripts to lint yet.
- TestEZ was installed but no test suite was run. Roblox engine and manual Studio tests have not been run.
- Agent final response exceeded Gemini's free-tier 15-requests-per-minute quota. GitHub Actions still committed the work as checkpoint `5bac5eb`.

## Known gaps
- Milestone 1 — Playable core: habitat, resources, planting/growth, creature discovery, and player feedback.
- Implement server-authoritative logic, asset loading, and client interactions in subsequent milestones.
- Repeat formatting and lint checks once source scripts exist; add actual TestEZ tests and Roblox engine/manual playtests.

## Exact next task
- Begin Milestone 1: implement the playable core in small, verifiable increments, preserving server authority, multiplayer isolation, and PC/mobile support.

## CI model fallback configuration
- The `main` workflow now uses an ordered fallback chain: Gemini 3.5 Flash-Lite → Gemini 3.1 Flash-Lite → Gemini 3.8 Flash → Gemma 4 31B IT → Gemma 4 26B A4B IT → Groq Qwen 3.8 27B → Groq GPT-OSS 120B → OpenRouter NVIDIA Nemotron 3 Ultra (free, optional) → OpenRouter Cohere North Mini Code (free, optional).
- Google model definitions are configured in `opencode.json` on `ai/game-build`. Groq and OpenRouter use OpenCode's built-in providers.
- `GEMINI_API_KEY` remains the required primary credential. `GROQ_API_KEY` is included as a secondary credential (already used by earlier workflow revisions). Add `OPENROUTER_API_KEY` as a repository Actions secret to enable the final independent-provider fallback; without it, that model is skipped.
- A daily request/token quota moves immediately to the next configured model. RPM/TPM limits wait for the provider's retry hint and continue the same OpenCode session, with up to four same-model retries before moving on. Recognized provider availability/auth/model errors also move to the next model. Unknown errors fail fast.
- Every model change uses OpenCode `--continue` with an explicit `--model`, preserving the same session and task context.
- Local shell syntax and simulated daily-quota/RPM fallback paths passed. Actual end-to-end provider switching remains to be verified in the next workflow run.
- OpenRouter free tier is a last-resort pool currently advertised at 50 requests/day and 20 RPM; the two configured OpenRouter models share that account-level free allowance. NVIDIA's free Nemotron endpoint states that request data may be logged and used to improve NVIDIA products. Do not send confidential information or credentials to that fallback.

## Latest extended-sprint workflow failure and correction
- Workflow run 42911900811 (run 9) did not begin gameplay implementation. It used only Gemini 3.5 Flash-Lite, then hit the Google Free Tier input-token-per-minute quota (250,000 TPM), not the daily request quota.
- The multi-model fallback did not run because GitHub Actions Bash had `errexit` enabled: the failed OpenCode pipeline terminated the shell before its status could be classified. This is now fixed in `main` by explicitly disabling `errexit` in the model-routing step and handling pipeline statuses inside `if` conditions.
- The failed agent tried to install the Roblox toolchain itself, although the checkout had no Rokit tools installed, and created an invalid 9-byte archive. That file was removed. The official Rokit installer, pinned tool installation, Wally dependency installation, version checks, and initial Rojo build are now deterministic steps before the agent starts.
- The failed run's persistence checkpoint contained no gameplay implementation. The new workflow fixes are committed to `main`; actual model-to-model fallback still needs a live workflow verification.


## Latest toolchain validation failure and correction
- Workflow run 42913879785 (run 10) successfully installed Rokit 1.2.0, Rojo 7.6.1, StyLua 2.6.0, Selene 0.28.0, and Wally 0.3.2; `wally install` also completed and installed TestEZ 0.4.1 under `DevPackages`.
- The subsequent Rojo build failed because `default.project.json` still mapped `ReplicatedStorage.Packages` to a `Packages` directory that Wally had removed. The current `wally.toml` contains only a `[dev-dependencies]` entry, so there are no shared/runtime packages to populate `Packages`.
- Corrective commit `05221ee` removes that unused `$path` mapping from `default.project.json`. When a runtime dependency is added under `[dependencies]`, restore the `Packages` mapping alongside that dependency.
- Run 10 never started OpenCode and made no gameplay changes. The next workflow dispatch must verify the corrected Rojo build before Milestone 1 begins.


## First Milestone 1 implementation checkpoint (workflow run 11)
- Workflow run 42915434078 passed checkout, Roblox toolchain installation, Wally install, and the pre-agent Rojo build smoke test. This confirms the missing `Packages` mapping correction worked.
- The agent began Milestone 1 and created the first server/shared Luau modules: `CreatureManager.lua`, `DataStoreManager.lua`, `EconomyManager.lua`, `PlantManager.lua`, `QuestManager.lua`, `ResourceManager.lua`, `ServerMain.server.lua`, `Constants.lua`, `RemoteEvents.lua`, and `Types.lua`.
- These are an initial code checkpoint only, not a completed playable milestone. No client UI/world-building modules, formal TestEZ tests, or post-agent Rojo/StyLua/Selene checks are evidenced in this run. Review and validate the generated gameplay code before calling it playable or secure.
- The job exhausted Gemini 3.5 Flash-Lite's input-token-per-minute capacity after four outer retries. Gemini 3.1 Flash-Lite then returned repeated temporary "model is currently experiencing high demand" errors; OpenCode internally retried those requests before the workflow stopped.
- The workflow classifier did not recognize that provider-capacity wording. The main workflow was corrected in commit `ae1d395` to classify "high demand", "spikes in demand", and "try again later" as provider-availability errors and continue to the next configured model.
- Run 11 checkpoint `55a4509` was persisted successfully to `ai/game-build` with 10 Luau files and 752 inserted lines.
- Next: dispatch a new run to verify the expanded classifier reaches Gemini 2.5 Flash-Lite or the next available provider, then continue the original Milestone 1 implementation and require post-agent build, lint, format, and tests.


## Workflow run 12 — Gemini 2.5 fallback blocked and checkpoint saved
- Workflow run 42917643374 passed the toolchain and pre-agent Rojo build, then started the agent.
- Gemini 3.5 Flash-Lite hit 15-RPM and 250,000-TPM limits. Gemini 3.1 Flash-Lite then hit TPM limits and repeated high-demand responses. The workflow correctly advanced past Gemini 3.1.
- Gemini 2.5 Flash-Lite was rejected with: "This model ... is no longer available to new users." Google documents that access to Gemini 2.5 models is limited to users who actively used them before; for new projects it recommends Gemini 3.5 Flash-Lite or Gemini 3.8 Flash.
- Main workflow commit `3e956a7` removes Gemini 2.5 Flash-Lite from the fallback order and adds retired/restricted model wording to the provider-availability classifier. Gemini 3.8 Flash is now next after Gemini 3.1.
- Run 12 checkpoint `04a4108` added `src/client/ClientMain.client.lua`, created `src/server/WorldBuilder.lua` and `src/shared/PocketHabitat.spec.lua` (both empty at this checkpoint), and modified server modules. No successful post-agent Rojo/lint/format/TestEZ run is recorded.
- The run reformatted many vendored TestEZ files under `DevPackages/_Index`. Corrective commit `25750bf` restores the vendored dependency tree to its pre-run contents while retaining game-source changes. `AGENTS.md` now directs formatting/linting to `src/` only.
- The next workflow run must verify that Gemini 3.8 Flash or later Google/Groq/OpenRouter models can take over, and it must validate the saved Luau source after agent execution.
