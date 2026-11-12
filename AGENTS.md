# Pocket Habitat — Agent Instructions

Develop Pocket Habitat: a polished, low-poly Roblox habitat builder about collecting resources, growing plants, discovering creatures, completing quests, and upgrading personal habitats.

## Permanent engineering rules

- Use Luau and the existing versions pinned in rokit.toml.
- Keep gameplay server-authoritative; validate client requests and protect ownership, rewards, inventory, purchases, progression, and player data.
- Use safe, versioned persistence and isolate multiplayer player data.
- Prefer original, efficient Roblox geometry and assets; make UI work on mouse, keyboard, touch, and gamepad where practical.
- Preserve correct existing code. Make integrated, testable changes and never claim unrun tests passed.
- Treat implementation, review, repair, QA, and deterministic validation failures as recovery work rather than automatic run-ending conditions. Use fallback routes, retry eligible models in later cycles, and preserve unresolved findings in `docs/AUTONOMOUS_RECOVERY.md`. Never weaken checks or call an unvalidated recovery checkpoint complete. Stop only for documented hard safety/budget/persistence limits or when no meaningful safe progress is possible.
- Do not publish to Roblox or use publishing credentials.
- Use only tools exposed in the current agent environment. Do not invent tools, credentials, APIs, or test results.
- Do not create or switch branches, commit, or push manually. GitHub Actions persists implementation changes to ai/game-build.

## Required operating guide and project documents

Read docs/AUTONOMOUS_AGENT_GUIDE.md at the beginning of every run. It defines the permanent autonomous workflow and engineering policy.

The changing project status belongs in:
- docs/PROJECT_STATE.md — factual current implementation, verification, known risks, and exact next task.
- docs/ROADMAP.md — milestone status, acceptance criteria, priorities, and current focus.
- docs/TECHNICAL_ARCHITECTURE.md — actual architecture, intended design, and known gaps.
- docs/TESTING.md — reproducible checks and exact historical/current test results.

Also inspect relevant product and design documentation before changing those areas. The current repository source and these living documents take precedence over old prompts, old run summaries, and embedded assumptions.

## Dynamic task selection

When the user supplies a specific task, implement that task and its necessary dependencies.

When the user asks to continue or provides a generic development handoff, choose the highest-priority incomplete task recorded in PROJECT_STATE.md and ROADMAP.md after verifying it against the current source. Do not hard-code a milestone, run number, commit hash, model list, or permanent next task into reusable prompts.

After meaningful progress, update project state and roadmap so the next run can continue without the user rewriting the handoff.

## Formatting and dependency boundaries

- Format and lint project-owned Luau files under src/ only (for example, stylua --check src and selene src).
- Never run StyLua over the repository root.
- Do not modify, reformat, or rewrite vendored dependency sources under DevPackages/_Index/.
- Do not change provider credentials, model routing, or GitHub Actions workflow configuration unless the user's current task explicitly requests it.

For the complete procedure, follow docs/AUTONOMOUS_AGENT_GUIDE.md.