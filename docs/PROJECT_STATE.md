# Pocket Habitat — Project State

## Current status
- **Current milestone:** Milestone 0 — Foundation.
- **Status:** Partially complete. The required documentation pages now exist, but the toolchain and project directory mappings have not been validated successfully.
- **Last AI run:** GitHub Actions run `42905401642`; agent terminated after Google's Gemini 3.5 Flash-Lite free-tier limit of 15 generate-content requests per minute was reached.
- **Latest saved checkpoint at that run:** `7ef9e43` (documentation checkpoint). Additional documentation corrections were committed afterward.

## Implemented and documented
- Pocket Habitat game concept and core loops are documented in `GAME_DESIGN.md`.
- Development milestones are recorded in `ROADMAP.md`.
- Proposed server-authoritative architecture is described in `TECHNICAL_ARCHITECTURE.md`.
- Asset pipeline, testing strategy, and monetization proposal are documented in their respective files.
- Existing project configuration files are present: `default.project.json`, `rokit.toml`, `wally.toml`, `selene.toml`, `.stylua.toml`, and `opencode.json`.
- `.gitignore` and concise project-specific `AGENTS.md` are present.

## Actual checks from the latest foundation run
- GitHub checkout: PASSED.
- OpenCode installation and `opencode --version`: PASSED.
- Gemini API: several requests succeeded; the run then hit the configured free-tier 15 requests/minute limit and exited with quota error.
- `rokit --version`: NOT AVAILABLE in runner.
- `luau`, `luau-lsp`, and `lua`: NOT AVAILABLE in runner.
- Attempted Cargo installation of Rokit: FAILED to compile.
- Attempted Cargo installation of Wally CLI: FAILED because `wally-cli` was not found in crates.io.
- Rojo build, StyLua formatting, Selene lint, TestEZ, and Roblox engine tests: NOT RUN / NOT VERIFIED.
- Agent-written claims that all seven docs and all tooling checks passed were inaccurate; this file supersedes those claims.

## Known gaps
- Ensure all paths referenced by `default.project.json` are actual directories and are committed with placeholder files where empty.
- Install Rokit by its supported installation method in CI, then use it to install pinned tools.
- Verify whether the Wally pin/distribution is valid and adjust based on official installation instructions.
- Add a CI validation script for Rojo build, StyLua, and Selene.
- Add tests only when implementation exists; do not claim TestEZ or Roblox engine checks passed prematurely.
- OpenCode/Gemini can hit the free-tier per-minute request cap during highly tool-heavy runs. Keep each run tightly scoped and reduce tool-call count.

## Exact next task
Complete the CI toolchain setup in a single focused task: install Rokit using its supported release installer, install pinned tools from `rokit.toml`, validate `default.project.json` with Rojo, and run StyLua/Selene on any Luau files. Correct the empty source/asset/Packages paths referenced by Rojo. Record only actual outcomes here. Do not implement gameplay or publish to Roblox yet.
