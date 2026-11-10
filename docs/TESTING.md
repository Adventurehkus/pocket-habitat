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

## CI model fallback
The autonomous GitHub Actions workflow tries configured models in this order:
1. Google Gemini 3.5 Flash-Lite.
2. Google Gemini 3.1 Flash-Lite.
3. Google Gemini 2.5 Flash-Lite.
4. Google Gemma 4 31B IT.
5. Google Gemma 4 26B A4B IT.
6. Groq Qwen 3.8 27B.
7. Groq GPT-OSS 120B.
8. OpenRouter NVIDIA Nemotron 3 Ultra (free), when `OPENROUTER_API_KEY` is configured.

Provider keys are read from GitHub Actions repository secrets. `GEMINI_API_KEY` and `GROQ_API_KEY` are already used by the workflow; OpenRouter is optional. To enable its last-resort free fallback, create an OpenRouter API key and add it to repository Settings → Secrets and variables → Actions as `OPENROUTER_API_KEY`. Never paste API keys into prompts, source files, or chat.

On a daily request/token quota error, the workflow moves to the next model. On explicit RPM/TPM errors, it waits for the provider's retry hint and resumes the same OpenCode session, up to four retries per model before moving on. Recognized temporary provider/auth/model availability errors also move to the next model. Unrecognized errors fail fast rather than hiding actual agent/tool failures. Every model switch continues the same OpenCode session and original task; GitHub Actions persists the working tree at job end.

OpenRouter's free tier currently advertises 50 requests/day and 20 requests/minute; failed free-model attempts count toward its daily cap. Treat it as a small last-resort reserve, not another 500-request pool. Free OpenRouter/NVIDIA endpoints may log prompts for service improvement, so do not put private data or credentials in project prompts.
