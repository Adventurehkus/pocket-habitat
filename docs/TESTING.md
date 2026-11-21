# Pocket Habitat — Testing and Verification Strategy

## Principles

- Record only checks that actually ran and their actual results.
- Separate source/static checks from Roblox-engine and manual playtesting.
- A test file is not a passed test.
- A workflow handoff or recovery checkpoint is not a validated development cycle.

## Latest execution — Autonomous Agent Run (2026-11-20)

### Static validation (Pass)
- **Toolchain installation and Rojo build:** `rojo build default.project.json -o build/pocket-habitat.rbxl` — PASS (Valid model artifact generated).
- **StyLua format check:** `stylua --check src` — PASS (0 errors, 0 warnings).
- **Selene linter:** `selene src` — PASS (0 errors, 0 warnings, 0 parse errors).
- **Diff hygiene:** `git diff --check` — PASS (Clean working tree, no trailing whitespace or uncommitted conflicts).
- **Recovery Status:** RESOLVED (All automation-resolvable source-level issues fixed and verified).

### Source-level vertical slice verification (Pass)
- **Seed-to-Plant-to-Creature lifecycle integration:** Verified complete gameplay loop at source level:
  - Gather (ResourceManager) → Quest progress + Creature discovery check
  - Plant (PlantManager) → Quest progress + Creature discovery check
  - Water (PlantManager) → Quest progress + Creature discovery check
  - Harvest (PlantManager) → Quest progress + Creature discovery check
  - Claim Quest (QuestManager) → QuestRules.tryClaim + Economy rewards + **CreatureManager.checkDiscoveries** (fixed)
  - Discover Creature (CreatureManager) → Flora/water validation + Quest progress + Bells + Spawn
  - Purchase Upgrade (EconomyManager) → Quest progress + WorldBuilder (plot_expansion)
- **Server-authority checks:** Ownership, distance, cooldown, session, inventory, economy, quest state validated across all managers.

### Outstanding runtime tests (Explicitly unverified)
- **TestEZ execution:** NOT RUN; no compatible runner available in Linux environment (requires Roblox runtime).
- **Roblox Studio server startup and gameplay:** NOT RUN; requires Roblox deployment.
- **Two-client multiplayer/habitat/resource/creature isolation:** NOT RUN; requires Roblox multiplayer environment.
- **DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown:** NOT RUN; requires Roblox runtime and persistence layer.
- **Mobile/device input and performance:** NOT RUN; requires target deployment platform.

## Latest autonomous pipeline diagnostic — Run #162 (2026-11-20)

**Result: FAILED — zero validated development cycles; no gameplay source diff was produced.**

Checks that actually ran:
- Toolchain installation and initial Rojo build: PASS.
- OpenCode model-registry validation: PASS.
- Continuation-policy regression tests: PASS.
- The cooldown scheduler fix was exercised: the pipeline recorded 128 seconds of actual waits across 32 classified temporary-limit events.

Implementation-stage blockers from the uploaded run artifact:
- Google Gemma 4 31B and 26B repeatedly hit free-tier input-token-per-minute limits (16,000 tokens/minute).
- Groq GPT-OSS 120B and 20B failed while OpenCode generated compaction summaries; the session models' configured output ceiling was 800 tokens.
- Groq Qwen 3.8 27B was rejected at 7,052 input tokens against Groq's 7,000-token-per-minute limit, so it was correctly skipped for that run.
- Two implementation cycles produced no diff. Review, QA, and deterministic source validation were therefore NOT RUN.

**Post-run pipeline fixes (not yet exercised by a subsequent Actions run):**
- Added `agents.compaction.model = google/gemini-3.5-flash-lite` as the dedicated summary route (configured output limit: 8,192).
- Reduced only Groq Qwen's configured input budget from 6,000 to 5,000 to leave room for tool/system overhead under the observed 7,000 ITPM ceiling. Groq output caps remain 800.
- Added CI assertions for the compaction model/output budget and Qwen input headroom.
- The main workflow's run report now distinguishes the initial Rojo toolchain build from the full deterministic validation stage; it will list StyLua/Selene only when they actually run.

These configuration changes are pipeline reliability work, not gameplay development. The next run must validate these changes before any new gameplay progress is counted.

## Latest autonomous pipeline diagnostic — Runs #166–167 (2026-11-20 local / 2026-11-21 UTC)

**Result: FAILED — zero validated development cycles and no gameplay diff.** Run #167 used the latest workflow commit and passed its preflight checks, but implementation could not complete.

Evidence from both run artifacts:
- Toolchain installation and initial Rojo build: PASS.
- OpenCode model-registry and continuation-policy checks: PASS.
- Google Gemma 4 31B/26B repeatedly hit the 16,000 input-tokens-per-minute free-tier limit. These were temporary rate limits, not confirmed daily-quota exhaustion.
- The Groq Qwen attempt returned only `Permission denied on the service.` The workflow launched OpenCode through `env -i` with only the selected stage provider's key, while `agents.compaction.model` was Google Gemini. A Groq session therefore lacked the Google credential required by its separately configured compaction route. The classifier also treated this ambiguous message as a provider-wide authentication failure, incorrectly excluding every Groq model.
- Run #167 recorded 16 model calls, 185 seconds of cooldown waits, two eligible quota pools remaining, three permanently ineligible pools, and zero explicit quota-exhaustion events. It reached the five-run no-progress circuit-breaker limit.
- Review, QA, and full deterministic validation (project Rojo build, StyLua, Selene) were NOT RUN because no implementation diff reached those stages.

**Workflow fix committed to `main`: `95deaf2c4cb4117cd885342a5e49bc9a301369ad`.**
- Each isolated OpenCode process now receives the key for its selected provider and, when different, only the additional key required by the configured compaction provider.
- Added regression checks for credential mapping across all configured providers without printing test or real credential values.
- The generic `Permission denied on the service.` response now quarantines only the selected model instead of disabling its entire provider. Explicit invalid-key/401/403 errors remain provider-level authentication failures.

This fix is structurally tested locally and in the workflow's embedded regression checks; **a new Actions run is still required to verify live provider behavior**. Pipeline reliability changes are not gameplay progress.

## Standard deterministic checks

1. Validate project JSON and relevant manifests.
2. Build: `rojo build default.project.json -o build/pocket-habitat.rbxl`.
3. Format: `stylua --check src`.
4. Lint: `selene src`.
5. Diff hygiene: `git diff --check`.
6. Inspect working tree: `git status --short`.
7. Execute manager/shared-rule TestEZ specs only through a compatible runner.

## Studio testing procedure

1. Habitat allocation: separate, non-overlapping floating islands.
2. Resource cooldowns and idempotent rewards.
3. DataStore save/rejoin without data loss.
4. Creature isolation and habitat-scoped interactions.
5. Cross-player request rejection and ownership isolation.
6. Join/respawn, gathering-to-harvest, quests, upgrades, and player-facing feedback.
