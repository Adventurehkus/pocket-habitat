# Pocket Habitat — Development Roadmap

## How to use this roadmap

This is a living priority queue, not a fixed prompt. The current implementation and verification facts belong in docs/PROJECT_STATE.md. At the start of every run, inspect the actual source at the current ai/game-build HEAD, read docs/PROJECT_STATE.md and this roadmap, and use project-state/run-32-audit.md for the known Run #32 issues. Correct stale documentation when source contradicts it.

Status labels:
- **Complete:** integrated and verified to the level stated.
- **Implemented, runtime-unverified:** source exists and relevant static checks pass, but Roblox engine/gameplay behavior is not verified.
- **In progress:** partly implemented or missing important integration/validation.
- **Blocked:** a known defect currently prevents the feature or runtime path from working.
- **Planned:** not implemented.

## Current status snapshot — 2026-11-17

**Estimated overall completion: approximately 25%.** 

**Recovery status: OPEN — Run 139 made 0 validated cycles after all 4 eligible model pools hit TPM restrictions. Workflow routing fixes are committed but await a fresh Actions run; Run 137's independent-QA gate also remains unresolved.**

## Milestone 0 — Foundation

**Status: COMPLETE.**

## Milestone 1 — Playable prototype loop

**Status: SOURCE FLOW IMPLEMENTED; PLAYABILITY AND SAVE/RESTORE RUNTIME-UNVERIFIED.**

Acceptance criteria:
- [ ] Server starts without runtime errors.
- [ ] A new player joins and spawns correctly.
- [ ] A player can gather, plant, water, harvest, earn rewards, and receive feedback in Roblox Studio.
- [ ] All actions are server-authoritative and fail safely.
- [ ] Full-inventory and failed-reward cases do not produce failures.
- [ ] Quest and upgrade actions reflect real server-side gameplay.
- [ ] The experience works in a two-client server.
- [ ] Save/rejoin behavior is verified without overwriting data.

## Milestone 2 — Personal habitats and multiplayer/data reliability

**Status: SOURCE-LEVEL RESTORATION COMPLETE; CURRENT INDEPENDENT QA GATE OPEN; GAMEPLAY RUNTIME VERIFICATION PENDING.**

## Milestone 3 — Progression integrity and content completion

**Status: PARTIALLY IMPLEMENTED; quest progression and source-level recovery fixes implemented, TestEZ and runtime testing pending.**

## Milestone 4 — Player experience and presentation

**Status: PARTIALLY IMPLEMENTED / PLANNED.**

## Milestone 5 — QA/hardening

**Status: ENGINE-LEVEL VERIFICATION OUTSTANDING.**

## Milestone 6 — Release

**Status: PLANNED.**

## Current focus

**Immediate priority:** Exercise the committed workflow routing repairs with a fresh Actions run. The next run must obtain implementation progress from the compacted handoff, then clear the outstanding independent-QA gate.

1. Run the updated Actions workflow and inspect the model attempt log. Confirm explicit Groq TPM request-size errors are skipped without repeated cooldown retries and the Groq output caps/compacted prompt are applied.
2. Obtain a valid independent baseline QA decision with a `QA_BLOCKER: YES` or `QA_BLOCKER: NO` first line. Repair any confirmed blocker; keep `docs/AUTONOMOUS_RECOVERY.md` OPEN until evidence supports closure.
3. Execute TestEZ in a compatible Roblox runner if one is available; otherwise record NOT RUN. (Currently NOT RUN)
4. In Roblox Studio, verify server startup, join/respawn, seed gathering through harvest, all ten quest claims, purchases/upgrades, and player feedback. (Currently NOT RUN)
5. Verify two-client habitat/creature/resource isolation, then DataStore save/rejoin, lease contention/renewal, failure handling, and shutdown. (Currently NOT RUN)
6. Continue with responsive UI, player feedback, environment/art, creature polish, sound, lighting, and mobile performance.

Do not count a successful workflow handoff as progress. A development cycle counts only after implementation, independent review, deterministic validation, QA, and checkpoint persistence succeed.
