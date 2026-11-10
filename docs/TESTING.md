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

## Current verified baseline
- GitHub Actions checkout: passed.
- OpenCode installation and version check: passed.
- Google Gemini API requests: succeeded for some calls, then the free-tier 15-requests-per-minute limit was reached.
- `rokit --version`: not available in the runner at the time of the foundation attempt.
- `luau`, `luau-lsp`, and `lua`: not available in the runner at the time of the foundation attempt.
- A Rokit Cargo installation attempt failed to compile; a Wally Cargo install attempt could not find `wally-cli` in crates.io.
- Rojo build, StyLua, Selene, TestEZ, and Roblox engine tests: not yet verified.

Update this baseline after a CI setup actually runs the relevant tools.
