# Pocket Habitat — Agent Instructions

Build a polished, low-poly Roblox habitat game about collecting resources, growing plants, discovering creatures, completing quests, and upgrading personal habitats.

## Required startup
Start with the attached compact Pocket Habitat agent context when the workflow provides it. Use that brief to orient; then inspect only the relevant, current sections of PROJECT_STATE.md, ROADMAP.md, and TESTING.md and the narrow source/architecture ranges needed for the task. Do not reread entire guides, historical reports, or full logs on every stage.

## Permanent engineering rules
- Use Luau and the pinned Rojo/Rokit/Wally toolchain.
- Keep gameplay server-authoritative; validate client input, remote requests, ownership, distance, cooldowns, rewards, inventory, purchases, progression, and player data.
- Preserve player-data integrity, safe persistence, schema compatibility, and multiplayer isolation.
- Build integrated, testable vertical slices rather than disconnected scaffolding.
- Preserve correct existing code. Never claim unrun tests passed.
- Keep prompts lean: inspect only relevant source and documentation, avoid repeated/full-file reads, and summarize logs/diffs. Reduce context when a provider reports request-size or input-token limits.
- Keep docs/AUTONOMOUS_RECOVERY.md compact (under 12 KB). Store full logs and diffs in workflow artifacts or docs/recovery-archive, not the active recovery note.
- A handoff/recovery checkpoint is not validated progress. A validated cycle requires implementation, independent review, deterministic validation, independent QA, and successful persistence.
- Documentation-only, recovery-note-only, and test-only edits do not count as gameplay progress; prioritize an integrated runtime Luau improvement.
- Treat temporary model/provider limits as recoverable workflow conditions, not gameplay defects. Do not bypass review, QA, tests, or bounded safety guards.
- The workflow handles model routing, retries, cooldowns, review/QA orchestration, validation, and persistence. Do not call provider APIs directly, create nested agents, hard-code model lists, or change credentials, provider configuration, or workflow files unless the user explicitly asks for that work.
- Never modify or reformat DevPackages/_Index, vendored Wally dependencies, third-party code, or generated caches.
- Format/lint only project-owned Luau under src. Never run StyLua over the repository root.
- Do not create/switch branches, manually commit/push, publish to Roblox, create releases, or access publishing credentials.
- Use only tools available in the current environment. Do not invent APIs, credentials, test results, or capabilities.

## Living project documents
- docs/PROJECT_STATE.md — factual implementation and verification status, risks, and next task.
- docs/ROADMAP.md — milestones, acceptance criteria, priorities, and current focus.
- docs/TECHNICAL_ARCHITECTURE.md — architecture and known gaps.
- docs/TESTING.md — commands and actual test results.
- docs/AUTONOMOUS_RECOVERY.md — compact active recovery debt.
Keep them consistent with the checked-out source and actual Git history.

The full operating procedure, source-of-truth order, Roblox safety rules, test boundaries, and required handoff are in docs/AUTONOMOUS_AGENT_GUIDE.md.
