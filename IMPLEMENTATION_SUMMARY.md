# Pocket Habitat — Implementation Summary

## Latest gameplay checkpoint — Run #32

- Gameplay branch: `ai/game-build`
- Checkpoint: `1af27d2aade0922f57ec4333bf5d5331366d7b9b`
- Workflow run: #32, ID `43119650837`, completed successfully on 2026-11-11.
- Workflow: https://github.com/Adventurehkus/pocket-habitat/actions/runs/43119650837
- Artifact: `pocket-habitat-pipeline-32` (77,705 bytes); includes `build/pocket-habitat.rbxl`, agent report, stage logs, and model usage TSV.

## Work committed

- Added `src/server/HabitatManager.lua` with a Workspace.Habitats root, per-UserId folder allocation/lookup/removal helpers, and BaseOffset metadata.
- Changed WorldBuilder to build world geometry under a supplied habitat folder.
- Updated ServerMain to allocate a player's habitat after successful data loading and remove its folder on PlayerRemoving.
- Replaced global resource cooldown bookkeeping with an in-memory per-UserId/per-node cooldown table.
- Updated ProximityHandler to discover habitat folders and wire prompts.

These are a partial architectural foundation. They do not implement complete habitat lifecycle, correct non-overlapping placement, character spawn, saved-world restoration, or full ownership security.

## Verification actually completed

- Implementation: SUCCESS — Cohere North Mini Code.
- Independent review: SUCCESS — Google Gemini 3.5 Flash Lite.
- Repair: SUCCESS — Cohere Command A+.
- Validation repair: SUCCESS — GitHub Copilot Auto.
- QA: SUCCESS — Google Gemini 3.1 Flash Lite; output began `QA_BLOCKER: NO`.
- Rojo build: PASSED; .rbxl generated.
- StyLua `--check src`: PASSED, 0 errors, 0 warnings, 0 parse errors.
- Selene `src`: PASSED.
- `git diff --check`: repair-agent log reports PASS.
- Gameplay commit and artifact upload: SUCCESS.

Not executed: TestEZ, Roblox server startup, Roblox Studio gameplay, two-client multiplayer, DataStore integration/contention, save/rejoin/shutdown, mobile/touch, or manual playtests.

## Critical source defect discovered after QA

`ServerMain.server.lua` still calls `WorldBuilder.init()`, but Run #32's `WorldBuilder.lua` defines `buildHabitat(folder, owner)` and has no `init` function. The old version did define init(). The current startup script is expected to fail at that call before all subsequent system initialization and player lifecycle event connections. This was not detected by CI or the QA agent.

Other verified issues:
- BaseOffset uses only 0.1-stud diagonal increments with a 100×100 baseplate and repeats every 1,000 UserIds; habitat overlap is unavoidable.
- Several child geometry positions add BaseOffset twice; paths use world origin instead of the local habitat origin.
- No server-owned character spawn/respawn placement exists.
- Loaded data is not passed into habitat construction; world state is not restored.
- Plot interaction does not resolve/validate an actual plot Instance within the calling player's habitat or server-measured distance. Plant effect positions are not habitat-offset.
- Resource remote accepts a nodeId and derives a template position rather than validating an exact node instance in the user's registered habitat. Its cooldown is set before reward grant, penalizing full-inventory failures.
- ProximityHandler's habitat discovery can miss the local player's already-existing habitat and its ChildAdded path is not restricted to the local player's folder or robust to descendant-add timing.
- DataStoreManager still uses GetAsync/SetAsync and process-local sessions, without a cross-server lease. removeSession clears in-memory state even if its final save failed.
- Creature runtime is still not fully habitat-scoped.

Full source findings and ordered repair plan: `project-state/run-32-audit.md`.

## Model usage interpretation

The Run #32 artifact records 20 configured models, 3 daily/shared quota-exhaustion events, 4 classified temporary-limit events, and 0 seconds of automatic wait. Individual Google, Cloudflare, and OpenRouter routes were exhausted or limited; some Groq routes were skipped because the prompt was too large. Cohere, Google, Cohere, GitHub Copilot, and Google routes successfully completed the five required model stages.

The workflow did **not** stop because all models ran out. All required stages completed using fallback routes. Remaining provider balances were not queried.

## Next development objective

Fix the WorldBuilder/ServerMain startup API mismatch first. Then implement collision-free habitat placement and consistent transforms, safe local-player prompt discovery, server-side ownership/distance validation, spawn/respawn, and save restoration. Follow the ordered plan in `project-state/run-32-audit.md`; do not mark Milestone 2 complete based on static CI.

## Workflow improvement after Run #32 — multi-cycle quota-focused execution

Workflow branch `main` now has an autonomous multi-cycle loop (latest commit `658bb50bad7060dc0ae99760ac673c748684cac4`). The previous pipeline stopped once one model succeeded at each required stage. The new policy:
- Repeats implementation → independent review → conditional repair → deterministic validation → QA cycles instead of ending after the first successful pass.
- Rotates model candidates between cycles and allows a successful model to be reused in later cycles; same-cycle role separation remains enforced.
- Uses the original user task in cycle 1, then continues it if incomplete or advances to the next highest-priority task in the live roadmap.
- Targets explicit daily/monthly exhaustion across at least 75% of eligible quota pools. Google/Groq are counted per model; Cohere/OpenRouter/Cloudflare/Copilot are counted per provider/account pool.
- Pushes every reviewed and validated cycle checkpoint before continuing.
- Uses hard caps: 8 calls per model, 120 total calls, 30 cycles, 2 hours aggregate temporary waiting, 2 no-progress cycles, and the 350-minute GitHub Actions job timeout.

**Verification status:** committed, but not yet live-tested. Run #32 exercised the old one-pass orchestration only. No new model-consuming workflow run was started as part of this documentation/workflow change. The next workflow dispatch must verify router rotation, quota-pool accounting, checkpoint persistence, and stop conditions.

**Billing limitation:** quota-pool exhaustion is detected from provider errors; CI cannot read real account balances. Call caps limit request counts, not charges. Check provider free-tier and spending settings before a long run.
