# Pocket Habitat — Project State

## Current status
- **Current milestone:** Milestone 0 — Foundation (completed).
- **Status:** Documentation suite and CI toolchain foundation are in place. Rokit-managed tools installed, Wally dependencies installed, and Rojo build verified. StyLua and Selene checks passed against the current placeholder-only game source tree; repeat them after gameplay scripts are added.
- **Last AI run:** Workflow run 42906659145.
- **Latest checkpoint:** `5bac5eb` — toolchain setup, dependency installation, build validation, and state update were persisted to `ai/game-build`.
- **Workflow conclusion:** The agent step ended with Gemini's free-tier 15-requests-per-minute quota error during its final response. The separate persistence step succeeded, so the checkpoint was not lost.

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
- The `main` workflow now uses an ordered fallback chain: Gemini 3.5 Flash-Lite → Gemini 3.1 Flash-Lite → Gemini 2.5 Flash-Lite → Gemini 3.8 Flash → Gemma 4 31B IT → Gemma 4 26B A4B IT → Groq Qwen 3.8 27B → Groq GPT-OSS 120B → OpenRouter NVIDIA Nemotron 3 Ultra (free, optional) → OpenRouter Cohere North Mini Code (free, optional).
- Google model definitions are configured in `opencode.json` on `ai/game-build`. Groq and OpenRouter use OpenCode's built-in providers.
- `GEMINI_API_KEY` remains the required primary credential. `GROQ_API_KEY` is included as a secondary credential (already used by earlier workflow revisions). Add `OPENROUTER_API_KEY` as a repository Actions secret to enable the final independent-provider fallback; without it, that model is skipped.
- A daily request/token quota moves immediately to the next configured model. RPM/TPM limits wait for the provider's retry hint and continue the same OpenCode session, with up to four same-model retries before moving on. Recognized provider availability/auth/model errors also move to the next model. Unknown errors fail fast.
- Every model change uses OpenCode `--continue` with an explicit `--model`, preserving the same session and task context.
- Local shell syntax and simulated daily-quota/RPM fallback paths passed. Actual end-to-end provider switching remains to be verified in the next workflow run.
- OpenRouter free tier is a last-resort pool currently advertised at 50 requests/day and 20 RPM; the two configured OpenRouter models share that account-level free allowance. NVIDIA's free Nemotron endpoint states that request data may be logged and used to improve NVIDIA products. Do not send confidential information or credentials to that fallback.
