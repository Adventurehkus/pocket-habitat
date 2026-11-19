# Pocket Habitat — Development Roadmap

This is a living priority queue. The checked-out source and docs/PROJECT_STATE.md describe factual implementation status; this file defines priority and acceptance criteria. Do not infer runtime success from source presence or a successful Rojo build.

Status labels:
- **Complete:** integrated and verified to the stated level.
- **Implemented, runtime-unverified:** source exists and static checks pass; Roblox behavior is not yet verified.
- **In progress:** partial implementation or missing integration.
- **Blocked:** a known issue prevents the path from working.
- **Planned:** not implemented.

## Current snapshot — 2026-11-18

**Estimated overall readiness: approximately 27% (directional).**
**Recovery status: OPEN.** Run 146's implementation diff passed independent code review but lacks a valid independent QA decision. Run 151 made no gameplay changes because the available implementation routes were blocked by Gemma input-token limits and oversized Groq requests.

## Milestone 0 — Foundation
**Status: COMPLETE.**

## Milestone 1 — Playable prototype loop
**Status: SOURCE FLOW IMPLEMENTED; PLAYABILITY AND SAVE/RESTORE RUNTIME-UNVERIFIED.**

Acceptance:
- [ ] Server starts without runtime errors.
- [ ] New player joins and respawns correctly.
- [ ] Gathering, planting, watering, harvesting, rewards, and player feedback work in Studio.
- [ ] Actions are server-authoritative and fail safely, including full inventory and failed reward cases.
- [ ] Quest and upgrade paths work.
- [ ] Two-client testing passes.
- [ ] Save/rejoin restores data without overwriting existing records.

## Milestone 2 — Personal habitats and multiplayer/data reliability
**Status: SOURCE-LEVEL IMPLEMENTATION PRESENT; INDEPENDENT QA AND GAMEPLAY RUNTIME VERIFICATION PENDING.**

## Milestone 3 — Progression integrity and content
**Status: PARTIALLY IMPLEMENTED; TESTEZ AND ROBLOX RUNTIME TESTING PENDING.**

## Milestone 4 — Player experience and presentation
**Status: PARTIALLY IMPLEMENTED / PLANNED.**

## Milestone 5 — QA and hardening
**Status: ENGINE-LEVEL VERIFICATION OUTSTANDING.**

## Milestone 6 — Release
**Status: PLANNED.**

## Milestone 7 — Testing and reliability
**Status: PARTIALLY IMPLEMENTED; shared-rule and manager-level test specifications exist, but TestEZ execution is pending.**

## Current priority

1. **Resolve recovery debt first:** obtain a valid independent QA_BLOCKER: YES/NO decision for the run-146 implementation diff; fix confirmed blockers. Keep docs/AUTONOMOUS_RECOVERY.md OPEN until evidence supports closure.
2. **Exercise the input-context mitigation:** run a fresh workflow dispatch after run 151 stopped the automatic no-progress chain. Confirm Gemma/Groq input limits and compaction avoid repeated oversized requests and allow a complete reviewed/validated/QA cycle.
3. Execute TestEZ in a compatible Roblox runner if available; otherwise record NOT RUN.
4. In Studio, verify server startup, join/respawn, the complete seed-to-harvest loop, ten quest claims, purchases/upgrades, and player feedback.
5. Verify two-client habitat/resource/creature isolation, DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown.
6. Continue responsive UI, player feedback, environment/art, creature polish, sound, lighting, and mobile performance.

Do not count a successful workflow handoff or recovery checkpoint as development progress. A validated cycle requires implementation, independent review, deterministic validation, independent QA, and checkpoint persistence.